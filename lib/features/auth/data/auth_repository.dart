import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'auth_models.dart';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<void> login(String email, String password) async {
    final response = await _api.dio.post(
      '/api/identity/login',
      data: {'email': email.trim(), 'password': password},
    );

    final data = response.data;
    final token = data['token'] ?? data['accessToken'];
    final refreshToken = data['refreshToken'];

    if (token == null) {
      throw Exception('Token não retornado pelo servidor.');
    }

    await _storage.saveTokens(accessToken: token, refreshToken: refreshToken);
  }

  Future<UserMeResponse> getUserPermissions() async {
    final response = await _api.dio.get('/api/users/me/permissions');
    return UserMeResponse.fromJson(response.data);
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
