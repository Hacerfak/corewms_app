import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'checking_models.dart';

class CheckingRepository {
  final ApiClient _api;

  CheckingRepository(this._api);

  /// 1. Busca os pedidos elegíveis para conferência (Checking, Packing ou ReadyToShip)
  Future<List<CheckingOrderSummary>> getOrdersForChecking({
    String? search,
  }) async {
    try {
      final response = await _api.dio.get(
        '/api/outbound/orders',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'Search': search.trim(),
          'Page': 1,
          'PageSize': 50,
        },
      );

      final data = response.data;
      List<dynamic> items = [];
      if (data is Map && data['items'] is List) {
        items = data['items'];
      } else if (data is List) {
        items = data;
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map((o) => CheckingOrderSummary.fromJson(o))
          .where((o) {
            final s = o.status.toUpperCase();
            return s == 'CHECKING' ||
                s == 'PACKING' ||
                s == 'READYTOSHIP' ||
                s == 'PICKING';
          })
          .toList();
    } catch (e) {
      debugPrint('[CHECKING] Erro ao listar ordens para conferência: $e');
      return [];
    }
  }

  /// 2. Detalhes e tarefas de conferência da ordem
  Future<OrderCheckingDetails?> getOrderCheckingTasks(String orderId) async {
    try {
      final response = await _api.dio.get(
        '/api/outbound/checking/$orderId/tasks',
      );
      if (response.data is Map<String, dynamic>) {
        return OrderCheckingDetails.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[CHECKING] Erro ao carregar tarefas da ordem $orderId: $e');
    }
    return null;
  }

  /// 3. Bipagem de conferência (LPN, Volume ou SKU)
  Future<Map<String, dynamic>?> checkItem({
    required String orderId,
    required String scannedCode,
    double? quantity,
  }) async {
    final payload = {
      'orderId': orderId,
      'scannedCode': scannedCode.trim().toUpperCase(),
      if (quantity != null && quantity > 0) 'quantity': quantity,
    };

    final response = await _api.dio.post(
      '/api/outbound/checking/scan',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// 4. Desfaz uma leitura individual
  Future<bool> undoCheck({
    required String orderId,
    required String checkLogId,
  }) async {
    final response = await _api.dio.post(
      '/api/outbound/checking/orders/$orderId/undo/$checkLogId',
    );
    return response.statusCode == 200;
  }

  /// 5. Reseta toda a conferência da ordem
  Future<bool> resetChecking(String orderId) async {
    final response = await _api.dio.post(
      '/api/outbound/checking/orders/$orderId/reset',
    );
    return response.statusCode == 200;
  }

  /// Finaliza a conferência de expedição da ordem de saída
  Future<bool> finalizeChecking(String orderId) async {
    final response = await _api.dio.post(
      '/api/outbound/checking/orders/$orderId/finalize',
      data: {'orderId': orderId},
    );
    return response.statusCode == 200;
  }
}
