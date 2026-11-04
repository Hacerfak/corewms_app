import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/storage_service.dart';
import 'jwt_helper.dart';

class ApiClient {
  final StorageService _storage;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  late final Dio dio;
  late final Dio _tokenDio;

  void Function(String reason)? onSessionExpired;
  Completer<String?>? _refreshCompleter;

  ApiClient(this._storage, {String? initialBaseUrl})
    : _baseUrl = initialBaseUrl ?? StorageService.defaultBaseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _tokenDio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
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
          if (options.path.contains('/api/identity/login') ||
              options.path.contains('/api/identity/refresh')) {
            return handler.next(options);
          }

          var token = await _storage.getToken();

          if (token != null && token.isNotEmpty) {
            if (JwtHelper.isExpired(token, thresholdSeconds: 30)) {
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
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;

            if (path.contains('/api/identity/login') ||
                path.contains('/api/identity/refresh')) {
              if (path.contains('/api/identity/refresh')) {
                _triggerSessionExpired(
                  'Sua sessão expirou. Faça login novamente.',
                );
              }
              return handler.next(error);
            }

            final newToken = await refreshTokenDirect();

            if (newToken != null && newToken.isNotEmpty) {
              final retryOptions = error.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newToken';

              try {
                final response = await dio.fetch(retryOptions);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            } else {
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Atualiza a URL base nos clientes HTTP Dio em tempo de execução
  void updateBaseUrl(String newUrl) {
    final clean = StorageService.sanitizeUrl(newUrl);
    _baseUrl = clean;
    dio.options.baseUrl = clean;
    _tokenDio.options.baseUrl = clean;
    debugPrint('[API] URL base atualizada para: $clean');
  }

  /// Testa se o servidor informado está acessível
  Future<bool> testConnection(String url) async {
    final clean = StorageService.sanitizeUrl(url);
    try {
      final testDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      // Tenta carregar o logo ou a rota base do servidor
      final res = await testDio.get('$clean/logo.png');
      return res.statusCode == 200 || res.statusCode == 304;
    } catch (_) {
      try {
        final testDio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        final res = await testDio.get(clean);
        return res.statusCode != null && res.statusCode! < 500;
      } catch (_) {
        return false;
      }
    }
  }

  Future<String?> refreshTokenDirect() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
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
