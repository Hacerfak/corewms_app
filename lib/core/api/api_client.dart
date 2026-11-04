import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/storage_service.dart';
import 'jwt_helper.dart';

class ApiClient {
  static const String baseUrl = 'https://wms.amplaarmazenagem.com.br';
  final StorageService _storage;

  late final Dio dio;
  late final Dio _tokenDio;

  /// Callback disparado quando os tokens expirarem e a renovação falhar
  void Function(String reason)? onSessionExpired;

  // Trava de sincronização para evitar múltiplas chamadas simultâneas de refresh
  Completer<String?>? _refreshCompleter;

  ApiClient(this._storage) {
    // 1. Dio principal usado nas rotas da aplicação
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 2. Dio dedicado para refresh (sem interceptores para prevenir recursão)
    _tokenDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Ignora injeção de token para endpoints anônimos
          if (options.path.contains('/api/identity/login') ||
              options.path.contains('/api/identity/refresh')) {
            return handler.next(options);
          }

          var token = await _storage.getToken();

          // Renovação Proativa: se o token estiver expirado ou a 30s de expirar
          if (token != null && token.isNotEmpty) {
            if (JwtHelper.isExpired(token, thresholdSeconds: 30)) {
              debugPrint(
                '[API] Access Token expirando. Renovando proativamente...',
              );
              final newToken = await refreshTokenDirect();
              if (newToken != null && newToken.isNotEmpty) {
                token = newToken;
              }
            }
            options.headers['Authorization'] = 'Bearer $token';
          }

          final companyId = await _storage.getCompanyId();
          if (companyId != null && companyId.isNotEmpty) {
            options.headers['X-Company-Id'] = companyId;
          }

          return handler.next(options);
        },

        onError: (DioException error, handler) async {
          // Trata apenas erros 401 (Não Autorizado)
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;

            // Se o 401 foi no próprio login ou no refresh, não tenta refrescar
            if (path.contains('/api/identity/login') ||
                path.contains('/api/identity/refresh')) {
              if (path.contains('/api/identity/refresh')) {
                _triggerSessionExpired(
                  'Sua sessão expirou. Faça login novamente.',
                );
              }
              return handler.next(error);
            }

            debugPrint(
              '[API 401] Token expirado na rota $path. Tentando refresh...',
            );

            // Tenta renovar o token sincronizadamente
            final newToken = await refreshTokenDirect();

            if (newToken != null && newToken.isNotEmpty) {
              // Refaz a requisição original com o novo token
              final retryOptions = error.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newToken';

              try {
                final response = await dio.fetch(retryOptions);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            } else {
              // Não foi possível renovar: erro repassado e logout engatilhado
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Executa a chamada /api/identity/refresh garantindo apenas 1 execução concorrente
  Future<String?> refreshTokenDirect() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[AUTH] Nenhum refresh token armazenado.');
        _triggerSessionExpired('Sessão expirada. Faça login novamente.');
        _refreshCompleter!.complete(null);
        return null;
      }

      final oldToken = await _storage.getToken();
      final email = oldToken != null ? JwtHelper.getEmail(oldToken) : null;

      final response = await _tokenDio.post(
        '/api/identity/refresh',
        data: {
          if (email != null && email.isNotEmpty) 'email': email,
          'refreshToken': refreshToken,
        },
      );

      final data = response.data;
      final newAccessToken = data?['accessToken']?.toString();
      final newRefreshToken = data?['refreshToken']?.toString();

      if (newAccessToken != null && newAccessToken.isNotEmpty) {
        debugPrint('[AUTH] Token renovado com sucesso via Refresh Token!');
        await _storage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );
        _refreshCompleter!.complete(newAccessToken);
        return newAccessToken;
      } else {
        _triggerSessionExpired('Falha ao renovar credenciais.');
        _refreshCompleter!.complete(null);
        return null;
      }
    } catch (e) {
      debugPrint('[AUTH] Falha ao renovar refresh token: $e');
      _triggerSessionExpired('Sua sessão expirou. Faça login novamente.');
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  void _triggerSessionExpired(String reason) {
    _storage.clearAll();
    onSessionExpired?.call(reason);
  }
}
