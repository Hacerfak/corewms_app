import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'cycle_count_models.dart';

class CycleCountRepository {
  final ApiClient _api;

  CycleCountRepository(this._api);

  Future<List<BlindLocationTaskModel>> getOperatorLocations() async {
    try {
      final response = await _api.dio.get('/api/cycle-count/tasks/operator');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => BlindLocationTaskModel.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[CYCLE_COUNT] Erro ao listar endereços de inventário: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createSpontaneousPlan({
    required List<String> locationCodes,
    int maxRounds = 2,
  }) async {
    final response = await _api.dio.post(
      '/api/cycle-count/plans/spontaneous',
      data: {'locationCodes': locationCodes, 'maxRounds': maxRounds},
    );
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  Future<bool> startLocationCounting(String planId, String locationId) async {
    final response = await _api.dio.post(
      '/api/cycle-count/locations/$planId/$locationId/start',
    );
    return response.statusCode == 200;
  }

  Future<bool> cancelLocationCounting(String planId, String locationId) async {
    final response = await _api.dio.post(
      '/api/cycle-count/locations/$planId/$locationId/cancel',
    );
    return response.statusCode == 200;
  }

  Future<bool> recordLocationCount({
    required String planId,
    required String locationId,
    required bool isEmptyLocation,
    required List<BlindScanEntry> entries,
  }) async {
    final response = await _api.dio.post(
      '/api/cycle-count/locations/$planId/$locationId/record',
      data: {
        'planId': planId,
        'locationId': locationId,
        'isEmptyLocation': isEmptyLocation,
        'entries': entries.map((e) => e.toJson()).toList(),
      },
    );
    return response.statusCode == 200;
  }
}
