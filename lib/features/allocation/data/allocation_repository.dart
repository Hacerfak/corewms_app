import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../hu/data/hu_models.dart';
import '../../inbound/data/inbound_models.dart';
import 'allocation_models.dart';

class AllocationRepository {
  final ApiClient _api;

  AllocationRepository(this._api);

  /// 1. Busca estritamente as ordens que possuem ao menos 1 HU na Doca aguardando guarda
  Future<List<AllocationOrderSummary>> getOrdersWithDockHus({
    String? search,
  }) async {
    try {
      final response = await _api.dio.get(
        '/api/inbound',
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

      // Filtra ordens canceladas ou sem conferência iniciada
      final candidateOrders = items
          .whereType<Map<String, dynamic>>()
          .map((o) => InboundOrderSummary.fromJson(o))
          .where(
            (o) => !o.hasPendingReview && o.status.toUpperCase() != 'CANCELED',
          )
          .toList();

      if (candidateOrders.isEmpty) return [];

      // Consulta as sugestões na Doca para cada ordem em paralelo
      final verifiedResults = await Future.wait(
        candidateOrders.map((order) async {
          final suggestions = await getPutawaySuggestions(order.id);
          // Se não houver HUs com HuStatus.Received na Doca, desconsidera a nota
          if (suggestions.isEmpty) return null;

          final totalQty = suggestions.fold<double>(
            0.0,
            (sum, item) => sum + item.quantity,
          );

          return AllocationOrderSummary(
            order: order,
            pendingHusCount: suggestions.length,
            totalQuantity: totalQty,
            suggestions: suggestions,
          );
        }),
      );

      // Retorna somente as ordens com pelo menos 1 volume na Doca
      return verifiedResults.whereType<AllocationOrderSummary>().toList();
    } catch (e) {
      debugPrint('[ALLOCATION] Erro ao buscar ordens com HUs na doca: $e');
      return [];
    }
  }

  /// 2. Detalhes completos da NF-e
  Future<InboundOrderDetails?> getOrderById(String orderId) async {
    try {
      final response = await _api.dio.get('/api/inbound/$orderId');
      if (response.data is Map<String, dynamic>) {
        return InboundOrderDetails.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[ALLOCATION] Erro ao consultar detalhes da ordem: $e');
    }
    return null;
  }

  /// 3. Sugestões de Alocação Inteligente calculadas pelo backend do CoreWMS
  Future<List<PutawaySuggestionModel>> getPutawaySuggestions(
    String orderId,
  ) async {
    try {
      final response = await _api.dio.get(
        '/api/inventory/putaway/suggestions/$orderId',
      );

      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((json) => PutawaySuggestionModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('[ALLOCATION] Erro ao consultar sugestões: $e');
    }
    return [];
  }

  /// 4. Posições de Armazenamento porta-palete ativas
  Future<List<LocationModel>> getStorageLocations() async {
    try {
      final response = await _api.dio.get('/api/topology/locations/storage');
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

  /// 5. Posições de Qualidade/Retenção
  Future<List<LocationModel>> getQualityLocations() async {
    try {
      final response = await _api.dio.get('/api/topology/locations/quality');
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

  /// 6. Busca de posição por código de barras bipado
  Future<LocationModel?> findLocationByCode(String codeOrPath) async {
    final clean = codeOrPath.trim().toUpperCase();
    try {
      final response = await _api.dio.get(
        '/api/topology/locations/by-code/$clean',
      );
      if (response.data is Map<String, dynamic>) {
        return LocationModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// 7. Busca HU por LPN para atalho rápido
  Future<HandlingUnitModel?> getHuByLpn(String lpn) async {
    final clean = lpn.trim().toUpperCase();
    try {
      final response = await _api.dio.get(
        '/api/inventory/handling-units',
        queryParameters: {'Lpn': clean, 'Page': 1, 'PageSize': 1},
      );
      final data = response.data;
      List<dynamic> items = (data is Map && data['items'] is List)
          ? data['items']
          : (data is List ? data : []);
      if (items.isNotEmpty) {
        return HandlingUnitModel.fromJson(
          Map<String, dynamic>.from(items.first),
        );
      }
    } catch (_) {}
    return null;
  }

  /// 8. Executa a gravação do movimento das HUs agrupadas por destino
  Future<bool> executePutaway(
    Map<String, List<String>> groupedByLocation,
  ) async {
    for (final entry in groupedByLocation.entries) {
      await _api.dio.post(
        '/api/inventory/handling-units/move',
        data: {
          'handlingUnitIds': entry.value,
          'destinationLocationId': entry.key,
        },
      );
    }
    return true;
  }
}
