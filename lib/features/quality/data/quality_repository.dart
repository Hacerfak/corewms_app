import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'quality_models.dart';

class QualityRepository {
  final ApiClient _api;

  QualityRepository(this._api);

  /// Consulta os motivos de qualidade cadastrados na empresa ativa
  Future<List<QualityReasonModel>> getReasons() async {
    try {
      final response = await _api.dio.get('/api/quality/reasons');
      final data = response.data;
      if (data is List) {
        return data
          .whereType<Map<String, dynamic>>()
          .map((item) => QualityReasonModel.fromJson(item))
          .where((r) => r.isActive)
          .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao carregar motivos de qualidade: $e');
    }
    return [];
  }

  /// Registra o bloqueio na API (/api/quality/hold) com transferência opcional de posição
  Future<void> holdHandlingUnits({
    required List<String> handlingUnitIds,
    required int newStatus, // 2 = Quarentena, 3 = Avaria
    required String reasonId,
    required String notes,
    String? qualityLocationId,
    List<QualityImageAttachment>? images,
  }) async {
    final payload = {
      'handlingUnitIds': handlingUnitIds,
      'newStatus': newStatus,
      'reasonId': reasonId,
      'notes': notes.trim(),
      if (qualityLocationId != null && qualityLocationId.isNotEmpty)
        'qualityLocationId': qualityLocationId,
      if (images != null && images.isNotEmpty)
        'images': images.map((img) => img.toJson()).toList(),
    };

    await _api.dio.post('/api/quality/hold', data: payload);
  }
}
