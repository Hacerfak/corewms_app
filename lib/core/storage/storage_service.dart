import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _companyIdKey = 'selected_company_id';
  static const _companyNameKey = 'selected_company_name';
  static const _userDataKey = 'user_data_cache';
  static const _baseUrlKey = 'server_base_url';

  /// URL padrão inicial do sistema
  static const String defaultBaseUrl = 'https://wms.amplaarmazenagem.com.br';

  /// Salva a URL base configurada
  Future<void> saveBaseUrl(String url) async {
    final cleanUrl = sanitizeUrl(url);
    await _storage.write(key: _baseUrlKey, value: cleanUrl);
  }

  /// Recupera a URL configurada ou retorna o padrão
  Future<String> getBaseUrl() async {
    final url = await _storage.read(key: _baseUrlKey);
    if (url != null && url.trim().isNotEmpty) {
      return sanitizeUrl(url);
    }
    return defaultBaseUrl;
  }

  /// Sanitiza a URL para garantir protocolo e remover barras finais
  static String sanitizeUrl(String url) {
    var clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

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
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveSelectedCompany({
    required String id,
    required String name,
  }) async {
    await _storage.write(key: _companyIdKey, value: id);
    await _storage.write(key: _companyNameKey, value: name);
  }

  Future<String?> getCompanyId() => _storage.read(key: _companyIdKey);
  Future<String?> getCompanyName() => _storage.read(key: _companyNameKey);

  Future<void> saveUserData(String jsonStr) =>
      _storage.write(key: _userDataKey, value: jsonStr);
  Future<String?> getUserData() => _storage.read(key: _userDataKey);

  Future<void> clearAll() async {
    final baseUrl = await getBaseUrl();
    await _storage.deleteAll();
    // Preserva a URL base mesmo ao limpar tokens/sessão
    await saveBaseUrl(baseUrl);
  }
}
