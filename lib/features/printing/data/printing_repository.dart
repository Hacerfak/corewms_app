import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import 'printing_models.dart';

class PrintingRepository {
  final ApiClient _api;

  PrintingRepository(this._api);

  /// Lista todos os agentes de impressão ativos e seu status online
  Future<List<PrintAgentModel>> getAgents() async {
    try {
      final response = await _api.dio.get('/api/printing/agents');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => PrintAgentModel.fromJson(item))
            .where((a) => a.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao consultar agentes de impressão: $e');
    }
    return [];
  }

  /// Lista os templates ZPL configurados
  Future<List<LabelTemplateModel>> getTemplates() async {
    try {
      final response = await _api.dio.get('/api/printing/templates');
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => LabelTemplateModel.fromJson(item))
            .where((t) => t.isActive)
            .toList();
      }
    } catch (e) {
      debugPrint('[WARN] Falha ao consultar templates de etiqueta: $e');
    }
    return [];
  }

  /// Despacha a impressão de HUs (LPNs)
  Future<void> printHandlingUnits({
    required List<String> huIds,
    required String templateId,
    required String stationName,
    required String printerName,
  }) async {
    final payload = {
      'handlingUnitIds': huIds,
      'templateId': templateId,
      'stationName': stationName,
      'printerName': printerName,
    };

    await _api.dio.post('/api/print/handling-units', data: payload);
  }

  /// Envio genérico de ZPL (para etiquetas de expedição, volumes de saída ou testes)
  Future<void> sendCustomPrint({
    required String stationName,
    required String printerName,
    required String zplContent,
  }) async {
    final payload = {
      'stationName': stationName,
      'printerName': printerName,
      'customZpl': zplContent,
    };

    await _api.dio.post('/api/print/send-test', data: payload);
  }
}
