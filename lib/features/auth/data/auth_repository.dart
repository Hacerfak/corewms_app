import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'auth_models.dart';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  /// 1. Realiza login e armazena os tokens (sem consultar permissões)
  Future<UserMeResponse> login(String email, String password) async {
    final response = await _api.dio.post(
      '/api/identity/login',
      data: {'email': email.trim(), 'password': password},
    );

    debugPrint('[LOGIN RAW RESPONSE]: ${response.data}');

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    final token = data['token'] ?? data['accessToken'];
    final refreshToken = data['refreshToken'];

    if (token == null) {
      throw Exception('Token não retornado pelo servidor.');
    }

    await _storage.saveTokens(
      accessToken: token.toString(),
      refreshToken: refreshToken?.toString(),
    );

    // Salva os dados brutos da sessão em cache
    await _storage.saveUserData(jsonEncode(data));

    // Retorna os dados do usuário com a lista de permissões inicialmente vazia
    return UserMeResponse.fromLoginData(data, const []);
  }

  /// 2. Consulta as permissões da empresa selecionada enviando o X-Company-Id
  Future<List<String>> fetchCompanyPermissions(String companyId) async {
    try {
      final response = await _api.dio.get(
        '/api/users/me/permissions',
        options: Options(headers: {'X-Company-Id': companyId}),
      );

      debugPrint('[PERMISSIONS (Company: $companyId)]: ${response.data}');

      if (response.data is List) {
        return (response.data as List).map((p) => p.toString()).toList();
      } else if (response.data is Map && response.data['permissions'] is List) {
        return (response.data['permissions'] as List)
            .map((p) => p.toString())
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao consultar permissões da empresa: $e');
    }
    return [];
  }

  /// 3. Salva a empresa escolhida e obtém as permissões do operador nela
  Future<List<String>> selectCompany(UserCompany company) async {
    await _storage.saveSelectedCompany(
      id: company.id,
      name: company.corporateName,
    );

    return await fetchCompanyPermissions(company.id);
  }

  /// 4. Restaura os dados do usuário a partir do cache local
  Future<UserMeResponse?> getCachedUser({
    List<String> permissions = const [],
  }) async {
    final cachedJson = await _storage.getUserData();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        return UserMeResponse.fromLoginData(data, permissions);
      } catch (e) {
        debugPrint('[WARN] Falha ao decodificar cache de usuário: $e');
      }
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
