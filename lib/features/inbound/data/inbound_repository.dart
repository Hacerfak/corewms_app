import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../hu/data/hu_models.dart';
import 'inbound_models.dart';

class InboundRepository {
  final ApiClient _api;
  ApiClient get api => _api;

  InboundRepository(this._api);

  /// 1. Consulta ordens de recebimento com paginação e busca
  Future<List<InboundOrderSummary>> getOrders({
    String? search,
    int? status,
    int page = 1,
  }) async {
    try {
      final response = await _api.dio.get(
        '/api/inbound',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'Search': search.trim(),
          'Status': ?status,
          'Page': page,
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
          .map((o) => InboundOrderSummary.fromJson(o))
          .toList();
    } catch (e) {
      debugPrint('[WARN] Falha ao listar ordens de entrada: $e');
      return [];
    }
  }

  Future<ProductTraceabilityRules?> getProductRules(String productId) async {
    try {
      final response = await _api.dio.get('/api/products/$productId');
      if (response.data is Map) {
        return ProductTraceabilityRules.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao carregar regras do produto: $e');
    }
    return null;
  }

  /// 2. Detalhes completos da ordem de entrada
  Future<InboundOrderDetails?> getOrderById(String orderId) async {
    try {
      final response = await _api.dio.get('/api/inbound/$orderId');
      if (response.data is Map) {
        return InboundOrderDetails.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao obter detalhes da ordem: $e');
    }
    return null;
  }

  /// 3. Lista de Docas ativas para descarregamento
  Future<List<LocationModel>> getDockLocations() async {
    try {
      final response = await _api.dio.get('/api/topology/locations/docks');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((d) => LocationModel.fromJson(d))
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao carregar docas: $e');
    }
    return [];
  }

  /// 4. Inicia o recebimento travando o item na Doca
  Future<void> startReceiving({
    required String orderItemId,
    required String dockLocationId,
  }) async {
    await _api.dio.post(
      '/api/inbound/receive/start',
      data: {'orderItemId': orderItemId, 'dockLocationId': dockLocationId},
    );
  }

  /// 5. Pausa e libera o lock do item
  Future<void> releaseItem(String orderItemId) async {
    await _api.dio.post(
      '/api/inbound/receive/$orderItemId/release',
      data: {'orderItemId': orderItemId},
    );
  }

  /// 6. Checkout de lote com geração de HUs
  Future<List<GeneratedHuSummary>> checkoutLote({
    required String orderItemId,
    required List<dynamic> volumes,
  }) async {
    final response = await _api.dio.post(
      '/api/inbound/receive/checkout',
      data: {'orderItemId': orderItemId, 'volumes': volumes},
    );

    final data = response.data;
    if (data is Map && data['husGenerated'] is List) {
      return (data['husGenerated'] as List)
          .map((h) => GeneratedHuSummary.fromJson(h))
          .toList();
    }
    return [];
  }

  /// 7. Lista os serviços de faturamento operacional de entrada
  Future<List<BillingServiceOption>> getBillingServices() async {
    try {
      final response = await _api.dio.get('/api/billing/services');
      final data = response.data;
      List<dynamic> items = [];
      if (data is Map && data['items'] is List) {
        items = data['items'];
      } else if (data is List) {
        items = data;
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map((s) => BillingServiceOption.fromJson(s))
          .toList();
    } catch (e) {
      debugPrint('[WARN] Falha ao buscar serviços de cobrança: $e');
      return [];
    }
  }
}
