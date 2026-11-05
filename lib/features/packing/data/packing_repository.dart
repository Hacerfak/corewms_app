import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../hu/data/hu_models.dart';
import '../../inbound/data/inbound_models.dart';
import 'packing_models.dart';

class PackingRepository {
  final ApiClient _api;

  PackingRepository(this._api);

  /// 1. Busca pedidos aptos para packing (Picking ou Packing)
  Future<List<PackingOrderSummary>> getOrdersForPacking({
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
          .map((o) => PackingOrderSummary.fromJson(o))
          .where((o) {
            final s = o.status.toUpperCase();
            return s == 'PICKING' || s == 'PACKING' || s == 'ALLOCATED';
          })
          .toList();
    } catch (e) {
      debugPrint('[PACKING] Erro ao listar ordens para packing: $e');
      return [];
    }
  }

  /// 2. Detalhes completos dos itens do pedido
  Future<List<PackingOrderItemModel>> getOrderItems(String orderId) async {
    try {
      final response = await _api.dio.get('/api/outbound/orders/$orderId');
      if (response.data is Map && response.data['items'] is List) {
        final items = response.data['items'] as List<dynamic>;
        return items
            .whereType<Map<String, dynamic>>()
            .map((i) => PackingOrderItemModel.fromJson(i))
            .toList();
      }
    } catch (e) {
      debugPrint('[PACKING] Erro ao carregar itens da ordem: $e');
    }
    return [];
  }

  /// 3. Consulta apontamentos existentes do item (Momento 1)
  Future<List<ItemPackEntry>> getItemPacks(
    String orderId,
    String orderItemId,
  ) async {
    try {
      final response = await _api.dio.get(
        '/api/outbound/packing/orders/$orderId/items/$orderItemId',
      );
      if (response.data is Map && response.data['packs'] is List) {
        final packs = response.data['packs'] as List<dynamic>;
        return packs.map((p) {
          return ItemPackEntry(
            packagingTypeId: p['packagingTypeId']?.toString() ?? '',
            packagingCode: p['packagingTypeCode']?.toString() ?? 'VOL',
            volumeCount: (p['volumeCount'] as num?)?.toInt() ?? 1,
            quantityPerVolume:
                (p['quantityPerVolume'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 4. Grava o apontamento de embalagens do item (Momento 1)
  Future<bool> saveItemPacking({
    required String orderId,
    required String orderItemId,
    required List<ItemPackEntry> packs,
  }) async {
    final payload = {
      'orderId': orderId,
      'orderItemId': orderItemId,
      'packs': packs.map((p) => p.toJson()).toList(),
    };

    final response = await _api.dio.post(
      '/api/outbound/packing/orders/$orderId/items/$orderItemId',
      data: payload,
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }

  /// 5. Busca embalagens atreladas ao produto
  Future<List<ProductPackagingOption>> getProductPackagings(
    String productId,
  ) async {
    try {
      final response = await _api.dio.get(
        '/api/products/$productId/packagings',
      );
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((i) => ProductPackagingOption.fromJson(i))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 6. Busca Docas ativas de expedição
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
    } catch (_) {}
    return [];
  }

  /// 7. Busca serviços de faturamento (Handling Out)
  Future<List<BillingServiceOption>> getBillingServices() async {
    try {
      final response = await _api.dio.get('/api/billing/services');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((s) => BillingServiceOption.fromJson(s))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 8. Finaliza o Packing do Pedido & Envia para a Doca (Momento 2)
  Future<bool> finalizeOrderPacking({
    required String orderId,
    required String dockLocationId,
    required bool usedStretchFilm,
    required List<ShippingVolumeEntry> shippingVolumes,
    String? handlingServiceId,
  }) async {
    final payload = {
      'orderId': orderId,
      'dockLocationId': dockLocationId,
      'usedStretchFilm': usedStretchFilm,
      'shippingVolumes': shippingVolumes.map((v) => v.toJson()).toList(),
      if (handlingServiceId != null && handlingServiceId.isNotEmpty)
        'handlingServiceId': handlingServiceId,
    };

    final response = await _api.dio.post(
      '/api/outbound/packing/orders/$orderId/finalize',
      data: payload,
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}
