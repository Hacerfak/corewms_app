import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../hu/data/hu_models.dart';
import '../data/yard_models.dart';
import '../data/yard_repository.dart';

class YardProvider extends ChangeNotifier {
  final YardRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  /// null = Todos ativos (exceto cancelados), 1 = Agendados, 2 = No Pátio, 3 = Na Doca, 4 = Finalizados
  int? _statusFilter;
  int? get statusFilter => _statusFilter;

  List<YardAppointmentModel> _appointments = [];
  List<YardAppointmentModel> get appointments => _appointments;

  List<LocationModel> _docks = [];
  List<LocationModel> get docks => _docks;

  YardProvider(this._repository);

  // Contadores operacionais do dia (KPIs)
  int get scheduledCount => _appointments.where((a) => a.isScheduled).length;
  int get inYardCount => _appointments.where((a) => a.isInYard).length;
  int get inDockCount => _appointments.where((a) => a.isInDock).length;
  int get finishedCount => _appointments.where((a) => a.isFinished).length;

  List<YardAppointmentModel> get filteredAppointments {
    if (_statusFilter == null) {
      return _appointments.where((a) => !a.isCanceled).toList();
    }
    return _appointments.where((a) => a.status == _statusFilter).toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setStatusFilter(int? status) {
    _statusFilter = status;
    notifyListeners();
  }

  Future<void> setSelectedDate(DateTime date, {String? search}) async {
    _selectedDate = date;
    await loadData(search: search);
  }

  /// Carrega agendamentos da data selecionada e docas da topologia
  Future<void> loadData({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getAppointments(date: _selectedDate, search: search),
        if (_docks.isEmpty)
          _repository.getDockLocations()
        else
          Future.value(_docks),
      ]);

      _appointments = results[0] as List<YardAppointmentModel>;
      _docks = results[1] as List<LocationModel>;
    } catch (e) {
      _errorMessage = 'Falha ao sincronizar dados da portaria.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _extractErrorMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? data['Message'] ?? fallback).toString();
      }
      return fallback;
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  /// Registra entrada no pátio (Check-in) via reserva, placa ou confirmação detalhada
  Future<dynamic> executeCheckIn({
    required String codeOrPlate,
    String? plate,
    String? driver,
    String? cpf,
    String? dockLocationId,
    String? currentSearch,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.checkIn(
        codeOrPlate: codeOrPlate,
        plate: plate,
        driver: driver,
        cpf: cpf,
        dockLocationId: dockLocationId,
      );
      await loadData(search: currentSearch);
      return res;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e, 'Falha ao registrar entrada.');
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Posiciona o veículo em uma doca física
  Future<bool> executeMoveToDock({
    required String appointmentId,
    required String dockLocationId,
    String? currentSearch,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.moveToDock(
        appointmentId: appointmentId,
        dockLocationId: dockLocationId,
      );
      if (res != null) {
        await loadData(search: currentSearch);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e, 'Falha ao encostar na doca.');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Finaliza a operação e registra a saída do veículo (Check-out)
  Future<dynamic> executeCheckOut(
    String appointmentId, {
    String? currentSearch,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.checkOut(appointmentId);
      await loadData(search: currentSearch);
      return res;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e, 'Falha ao registrar saída.');
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Registra caminhão avulso na guarita (já entrando no pátio ou agendado)
  Future<dynamic> createWalkInAppointment({
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
    String? currentSearch,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.createAppointment(
        type: type,
        scheduledDate: scheduledDate,
        vehiclePlate: vehiclePlate,
        vehiclePlateState: vehiclePlateState,
        driverName: driverName,
        driverCpf: driverCpf,
        carrierName: carrierName,
        invoiceNumber: invoiceNumber,
        dockLocationId: dockLocationId,
        additionalNotes: additionalNotes,
        directCheckIn: directCheckIn,
      );
      await loadData(search: currentSearch);
      return res;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e, 'Falha ao registrar veículo.');
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<List<AvailableOrderLinkItem>> loadAvailableOrders(int type) =>
      _repository.getAvailableOrdersForLinking(type);

  Future<bool> executeLinkOrder({
    required String appointmentId,
    required int type,
    required String orderId,
    String? currentSearch,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await _repository.linkOrder(
        appointmentId: appointmentId,
        type: type,
        orderId: orderId,
      );
      if (ok) {
        await loadData(search: currentSearch);
      }
      return ok;
    } catch (e) {
      _errorMessage = _extractErrorMessage(e, 'Falha ao vincular ordem.');
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
