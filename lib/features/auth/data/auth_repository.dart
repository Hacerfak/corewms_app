import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'auth_models.dart';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

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

    // Guarda os dados brutos da sessão em cache
    await _storage.saveUserData(jsonEncode(data));

    // Carrega as permissões do utilizador
    final permissions = await _fetchPermissions();

    return UserMeResponse.fromLoginData(data, permissions);
  }

  Future<UserMeResponse> getUserPermissions() async {
    final permissions = await _fetchPermissions();

    // Tenta restaurar os dados do utilizador através do cache
    final cachedJson = await _storage.getUserData();
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        return UserMeResponse.fromLoginData(data, permissions);
      } catch (e) {
        debugPrint('[WARN] Falha ao descodificar cache de utilizador: $e');
      }
    }

    return UserMeResponse(
      id: '',
      name: 'Operador',
      email: '',
      isMaster: false,
      companies: [],
      permissions: permissions,
    );
  }

  Future<List<String>> _fetchPermissions() async {
    try {
      final permResponse = await _api.dio.get('/api/users/me/permissions');
      debugPrint('[PERMISSIONS RAW RESPONSE]: ${permResponse.data}');

      if (permResponse.data is List) {
        return (permResponse.data as List).map((p) => p.toString()).toList();
      } else if (permResponse.data is Map &&
          permResponse.data['permissions'] is List) {
        return (permResponse.data['permissions'] as List)
            .map((p) => p.toString())
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao carregar permissões: $e');
    }
    return [];
  }

  Future<void> selectCompany(UserCompany company) async {
    await _storage.saveSelectedCompany(
      id: company.id,
      name: company.corporateName,
    );
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
