import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/cycle_count_models.dart';
import '../data/cycle_count_repository.dart';

class CycleCountProvider extends ChangeNotifier {
  final CycleCountRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<BlindLocationTaskModel> _locations = [];
  List<BlindLocationTaskModel> get locations => _locations;

  CycleCountProvider(this._repository);

  Future<void> loadLocations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _locations = await _repository.getOperatorLocations();
    } catch (e) {
      _errorMessage = 'Falha ao carregar endereços para contagem.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startSpontaneousCount(List<String> locationCodes) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.createSpontaneousPlan(
        locationCodes: locationCodes,
      );
      if (res != null) {
        await loadLocations();
        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ??
            'Erro ao iniciar contagem espontânea.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> startCounting(String planId, String locationId) async {
    try {
      return await _repository.startLocationCounting(planId, locationId);
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Erro ao iniciar contagem.';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelCounting(String planId, String locationId) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final ok = await _repository.cancelLocationCounting(planId, locationId);
      if (ok) await loadLocations();
      return ok;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitBlindCount({
    required String planId,
    required String locationId,
    required bool isEmptyLocation,
    required List<BlindScanEntry> entries,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await _repository.recordLocationCount(
        planId: planId,
        locationId: locationId,
        isEmptyLocation: isEmptyLocation,
        entries: entries,
      );
      if (ok) {
        await loadLocations();
      }
      return ok;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Erro ao registrar contagem.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
