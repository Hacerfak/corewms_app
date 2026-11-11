import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'picking_models.dart';

class PickingRepository {
  final ApiClient _api;

  PickingRepository(this._api);

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

      // Filtra pedidos em estado de separação ativa ou em conferência simultânea
      return items.whereType<Map>().where((o) {
        final s = o['status']?.toString().toUpperCase() ?? '';
        return s == 'ALLOCATED' || s == 'PICKING' || s == 'CHECKING';
      }).toList();
    } catch (e) {
      debugPrint('[PICKING] Erro ao listar pedidos: $e');
      return [];
    }
  }

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

  /// Executa o scan aceitando qualquer HU compatível de mesmo produto/lote
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

  /// Estorna uma HU específica recolhida
  Future<bool> undoPickedHu({
    required String orderId,
    required String allocationId,
  }) async {
    final response = await _api.dio.post(
      '/api/outbound/picking/orders/$orderId/undo/$allocationId',
    );
    return response.statusCode == 200;
  }

  /// Reinicia 100% da separação do pedido
  Future<bool> resetOrderPicking(String orderId) async {
    final response = await _api.dio.post(
      '/api/outbound/picking/orders/$orderId/reset',
    );
    return response.statusCode == 200;
  }

  /// Dispara a finalização explícita da separação do pedido
  Future<Map<String, dynamic>?> finalizeOrderPicking(String orderId) async {
    final response = await _api.dio.post(
      '/api/outbound/picking/orders/$orderId/finalize',
      data: {'orderId': orderId},
    );

    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }
}
