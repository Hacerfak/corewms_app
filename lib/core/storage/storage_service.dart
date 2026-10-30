import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _companyIdKey = 'selected_company_id';
  static const _companyNameKey = 'selected_company_name';

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveSelectedCompany({
    required String id,
    required String name,
  }) async {
    await _storage.write(key: _companyIdKey, value: id);
    await _storage.write(key: _companyNameKey, value: name);
  }

  Future<String?> getCompanyId() => _storage.read(key: _companyIdKey);
  Future<String?> getCompanyName() => _storage.read(key: _companyNameKey);

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
