import 'package:dio/dio.dart';

import '../storage/storage_service.dart';

class ApiClient {
  static const String baseUrl = 'https://wms.amplaarmazenagem.com.br';
  final StorageService _storage;
  late final Dio dio;

  ApiClient(this._storage) {
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

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
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
            await _storage.clearAll();
          }
          return handler.next(error);
        },
      ),
    );
  }
}
