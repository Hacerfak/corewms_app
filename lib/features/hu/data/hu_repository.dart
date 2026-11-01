import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'hu_models.dart';

class HuRepository {
  final ApiClient _api;

  HuRepository(this._api);

  Future<HandlingUnitModel?> getHuByLpn(String lpn) async {
    final cleanLpn = lpn.trim().toUpperCase();

    try {
      final response = await _api.dio.get(
        '/api/inventory/handling-units',
        queryParameters: {'Lpn': cleanLpn, 'Page': 1, 'PageSize': 1},
      );

      final data = response.data;
      List<dynamic> items = [];

      if (data is Map && data['items'] is List) {
        items = data['items'];
      } else if (data is List) {
        items = data;
      }

      if (items.isEmpty) return null;

      var hu = HandlingUnitModel.fromJson(
        Map<String, dynamic>.from(items.first),
      );

      // Se a HU tem nota de entrada vinculada, busca detalhes do emitente se necessário
      if (hu.inboundOrderId != null &&
          hu.inboundOrderId!.isNotEmpty &&
          hu.issuerName == null) {
        try {
          final inboundRes = await _api.dio.get(
            '/api/inbound/${hu.inboundOrderId}',
          );
          if (inboundRes.data is Map) {
            final inData = Map<String, dynamic>.from(inboundRes.data);
            hu = hu.copyWithInboundDetails(
              issuerName: inData['issuerName']?.toString(),
              issuerCnpj: inData['issuerCnpj']?.toString(),
              invoiceIssueDate: inData['issueDate'] != null
                  ? DateTime.tryParse(inData['issueDate'].toString())
                  : null,
              receiptDate: inData['createdAt'] != null
                  ? DateTime.tryParse(inData['createdAt'].toString())
                  : null,
            );
          }
        } catch (_) {}
      }

      return hu;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Consulta o endereço diretamente pelo endpoint dedicado da Topologia
  Future<LocationModel?> getLocationByCode(String codeOrPath) async {
    final clean = codeOrPath.trim().toUpperCase();

    try {
      final response = await _api.dio.get(
        '/api/topology/locations/by-code/$clean',
      );
      if (response.data is Map) {
        return LocationModel.fromJson(Map<String, dynamic>.from(response.data));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? e.response?.data['Message'];
        if (msg != null) throw Exception(msg.toString());
      }
      rethrow;
    }
    return null;
  }

  /// Move a HU enviando exatamente o contrato do MoveHandlingUnitCommand
  Future<void> moveHu({
    required String huId,
    required String targetLocationId,
  }) async {
    final payload = {
      'handlingUnitIds': [huId], // Array de GUIDs exigido pelo backend
      'destinationLocationId': targetLocationId,
    };

    await _api.dio.post('/api/inventory/handling-units/move', data: payload);
  }

  /// Busca as embalagens configuradas especificamente para o produto da HU
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
            .map((item) => ProductPackagingOption.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao carregar embalagens do produto: $e');
    }
    return [];
  }

  /// Executa o desmembramento (Split) gerando a nova HU com os dados herdados
  Future<SplitHuResult> splitHu({
    required String sourceHuId,
    required double quantity,
    String? packagingTypeId,
  }) async {
    final payload = {
      'sourceHandlingUnitId': sourceHuId,
      'newHandlingUnits': [
        {
          'quantity': quantity,
          if (packagingTypeId != null && packagingTypeId.isNotEmpty)
            'packagingTypeId': packagingTypeId,
        },
      ],
    };

    final response = await _api.dio.post(
      '/api/inventory/handling-units/split',
      data: payload,
    );

    return SplitHuResult.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// Executa o agrupamento (Merge) entre duas HUs
  Future<MergeHuResult> mergeHu({
    required String sourceHuId,
    required String destinationLpn,
    required double quantity,
  }) async {
    final payload = {
      'sourceHandlingUnitId': sourceHuId,
      'destinationLpn': destinationLpn.trim().toUpperCase(),
      'quantity': quantity,
    };

    final response = await _api.dio.post(
      '/api/inventory/handling-units/merge',
      data: payload,
    );

    return MergeHuResult.fromJson(Map<String, dynamic>.from(response.data));
  }
}
