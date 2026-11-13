import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../hu/data/hu_models.dart';
import 'yard_models.dart';

class YardRepository {
  final ApiClient _api;

  YardRepository(this._api);

  /// 1. Lista agendamentos e veículos do dia / filtro
  Future<List<YardAppointmentModel>> getAppointments({
    DateTime? date,
    int? status,
    int? type,
    String? search,
  }) async {
    try {
      String? dateStr;
      if (date != null) {
        final y = date.year.toString().padLeft(4, '0');
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        dateStr = '$y-$m-$d';
      }

      final response = await _api.dio.get(
        '/api/yard/appointments',
        queryParameters: {
          ...?(dateStr != null
              ? {'startDate': dateStr, 'endDate': dateStr}
              : null),
          ...?(status != null ? {'status': status} : null),
          ...?(type != null ? {'type': type} : null),
          ...?(search != null && search.trim().isNotEmpty
              ? {'search': search.trim()}
              : null),
        },
      );

      final data = response.data;
      List<dynamic> items = [];
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'];
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map((e) => YardAppointmentModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('[YARD] Erro ao listar agendamentos: $e');
      return [];
    }
  }

  /// 2. Realiza o Check-in (Entrada no Pátio) por código de reserva ou placa
  Future<Map<String, dynamic>?> checkIn({
    required String codeOrPlate,
    String? plate,
    String? driver,
    String? cpf,
    String? dockLocationId,
  }) async {
    final payload = {
      'codeOrPlate': codeOrPlate.trim().toUpperCase(),
      if (plate != null && plate.trim().isNotEmpty)
        'plate': plate.trim().toUpperCase(),
      if (driver != null && driver.trim().isNotEmpty) 'driver': driver.trim(),
      if (cpf != null && cpf.trim().isNotEmpty) 'cpf': cpf.trim(),
      if (dockLocationId != null && dockLocationId.isNotEmpty)
        'dockLocationId': dockLocationId,
    };

    final response = await _api.dio.post('/api/yard/checkin', data: payload);
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// 3. Encosta o veículo em uma Doca física
  Future<Map<String, dynamic>?> moveToDock({
    required String appointmentId,
    required String dockLocationId,
  }) async {
    final response = await _api.dio.post(
      '/api/yard/appointments/$appointmentId/move-to-dock',
      queryParameters: {'dockLocationId': dockLocationId},
    );
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// 4. Realiza o Check-out (Saída da Portaria e cálculo de permanência)
  Future<Map<String, dynamic>?> checkOut(String appointmentId) async {
    final response = await _api.dio.post(
      '/api/yard/appointments/$appointmentId/checkout',
    );
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// 5. Cria agendamento ou registra entrada imediata avulsa na guarita
  Future<Map<String, dynamic>?> createAppointment({
    required int type,
    required DateTime scheduledDate,
    String? vehiclePlate,
    String? vehiclePlateState,
    String? driverName,
    String? driverCpf,
    String? carrierName,
    String? invoiceNumber,
    String? dockLocationId,
    String? additionalNotes,
    bool directCheckIn = true,
  }) async {
    final payload = {
      'type': type,
      'scheduledDate': scheduledDate.toUtc().toIso8601String(),
      if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
        'vehiclePlate': vehiclePlate.trim().toUpperCase(),
      if (vehiclePlateState != null && vehiclePlateState.trim().isNotEmpty)
        'vehiclePlateState': vehiclePlateState.trim().toUpperCase(),
      if (driverName != null && driverName.trim().isNotEmpty)
        'driverName': driverName.trim(),
      if (driverCpf != null && driverCpf.trim().isNotEmpty)
        'driverCpf': driverCpf.trim(),
      if (carrierName != null && carrierName.trim().isNotEmpty)
        'carrierName': carrierName.trim(),
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      if (dockLocationId != null && dockLocationId.isNotEmpty)
        'dockLocationId': dockLocationId,
      if (additionalNotes != null && additionalNotes.trim().isNotEmpty)
        'additionalNotes': additionalNotes.trim(),
      'directCheckIn': directCheckIn,
    };

    final response = await _api.dio.post(
      '/api/yard/appointments',
      data: payload,
    );
    if (response.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// 6. Lista ordens abertas disponíveis para vincular ao veículo
  Future<List<AvailableOrderLinkItem>> getAvailableOrdersForLinking(
    int type,
  ) async {
    try {
      final response = await _api.dio.get(
        '/api/yard/orders/available-for-linking',
        queryParameters: {'type': type},
      );
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((e) => AvailableOrderLinkItem.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[YARD] Erro ao listar ordens disponíveis para vínculo: $e');
    }
    return [];
  }

  /// 7. Vincula uma Ordem de Entrada ou Saída ao agendamento
  Future<bool> linkOrder({
    required String appointmentId,
    required int type,
    required String orderId,
  }) async {
    final response = await _api.dio.post(
      '/api/yard/appointments/$appointmentId/link-order',
      queryParameters: {'type': type, 'orderId': orderId},
    );
    return response.statusCode == 200;
  }

  /// 8. Carrega Docas ativas da Topologia
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
      debugPrint('[YARD] Erro ao carregar docas: $e');
    }
    return [];
  }
}
