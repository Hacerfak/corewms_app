import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'picking_models.dart';

class PickingRepository {
  final ApiClient _api;

  PickingRepository(this._api);

  /// 1. Busca os pedidos que estão prontos para separação (Allocated ou Picking)
  Future<List<dynamic>> getActivePickingOrders({String? search}) async {
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

      // Filtra pedidos em estado de separação (Allocated = 3, Picking = 4)
      return items.whereType<Map<String, dynamic>>().where((o) {
        final s = o['status']?.toString().toUpperCase() ?? '';
        return s == 'ALLOCATED' || s == 'PICKING';
      }).toList();
    } catch (e) {
      debugPrint('[PICKING] Erro ao listar pedidos de saída: $e');
      return [];
    }
  }

  /// 2. Detalhes das tarefas de picking de um pedido específico
  Future<PickingOrderSummaryModel?> getOrderPickingTasks(String orderId) async {
    try {
      final response = await _api.dio.get(
        '/api/outbound/picking/$orderId/tasks',
      );
      if (response.data is Map<String, dynamic>) {
        return PickingOrderSummaryModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[PICKING] Erro ao carregar tarefas do pedido $orderId: $e');
    }
    return null;
  }

  /// 3. Confirma a recolha física (Picking) de uma HU ou quantidade
  Future<Map<String, dynamic>?> scanAndPick({
    required String orderId,
    required String? orderItemId,
    required String scannedLpn,
    required double pickedQuantity,
  }) async {
    final payload = {
      'orderId': orderId,
      if (orderItemId != null && orderItemId.isNotEmpty)
        'orderItemId': orderItemId,
      'scannedLpn': scannedLpn.trim().toUpperCase(),
      'pickedQuantity': pickedQuantity,
    };

    final response = await _api.dio.post(
      '/api/outbound/picking/scan',
      data: payload,
    );

    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }
}
