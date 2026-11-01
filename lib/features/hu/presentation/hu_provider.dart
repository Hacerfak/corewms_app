import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/hu_models.dart';
import '../data/hu_repository.dart';

class HuProvider extends ChangeNotifier {
  final HuRepository _repository;

  HandlingUnitModel? _currentHu;
  HandlingUnitModel? get currentHu => _currentHu;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  HuProvider(this._repository);

  Future<void> searchHu(String lpn) async {
    final cleanLpn = lpn.trim();
    if (cleanLpn.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hu = await _repository.getHuByLpn(cleanLpn);
      if (hu == null) {
        _errorMessage = 'HU "$cleanLpn" não encontrada no sistema.';
        _currentHu = null;
      } else {
        _currentHu = hu;
      }
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Erro na consulta.')
            : 'Falha de comunicação com o servidor.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      _currentHu = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LocationModel?> findLocation(String code) =>
      _repository.getLocationByCode(code);

  Future<bool> executeMove({
    required String targetLocationId,
    required String targetLocationPath,
  }) async {
    if (_currentHu == null) return false;

    _isMoving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.moveHu(
        huId: _currentHu!.id,
        targetLocationId: targetLocationId,
      );

      // Atualiza os dados da HU imediatamente após a movimentação
      await searchHu(_currentHu!.lpn);
      return true;
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Falha ao mover HU.')
            : 'Erro ao conectar à API para mover.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return false;
    } finally {
      _isMoving = false;
      notifyListeners();
    }
  }

  void clear() {
    _currentHu = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
