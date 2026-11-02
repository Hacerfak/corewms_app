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

  bool _isSplitting = false;
  bool get isSplitting => _isSplitting;

  List<ProductPackagingOption> _productPackagings = [];
  List<ProductPackagingOption> get productPackagings => _productPackagings;

  bool _isMerging = false;
  bool get isMerging => _isMerging;

  bool _isHoldingQuality = false;
  bool get isHoldingQuality => _isHoldingQuality;

  List<QualityReasonOption> _qualityReasons = [];
  List<QualityReasonOption> get qualityReasons => _qualityReasons;

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

  /// Consulta uma HU por LPN sem alterar o estado da HU ativa no ecrã principal
  Future<HandlingUnitModel?> findHuByLpn(String lpn) =>
      _repository.getHuByLpn(lpn);

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

  Future<void> loadProductPackagings(String productId) async {
    _productPackagings = [];
    notifyListeners();
    _productPackagings = await _repository.getProductPackagings(productId);
    notifyListeners();
  }

  Future<SplitHuResult?> executeSplit({
    required double quantity,
    String? packagingTypeId,
  }) async {
    if (_currentHu == null) return null;

    _isSplitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.splitHu(
        sourceHuId: _currentHu!.id,
        quantity: quantity,
        packagingTypeId: packagingTypeId,
      );

      // Atualiza o saldo restante da HU mãe após o split
      await searchHu(_currentHu!.lpn);

      return result;
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Falha ao desmembrar HU.')
            : 'Erro ao conectar à API para realizar o split.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return null;
    } finally {
      _isSplitting = false;
      notifyListeners();
    }
  }

  Future<MergeHuResult?> executeMerge({
    required String destinationLpn,
    required double quantity,
  }) async {
    if (_currentHu == null) return null;

    _isMerging = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.mergeHu(
        sourceHuId: _currentHu!.id,
        destinationLpn: destinationLpn,
        quantity: quantity,
      );

      // Atualiza os dados da HU atual para refletir o novo saldo ou status consumido
      await searchHu(_currentHu!.lpn);

      return result;
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Falha ao agrupar HUs.')
            : 'Erro ao conectar à API para realizar o merge.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return null;
    } finally {
      _isMerging = false;
      notifyListeners();
    }
  }

  Future<void> loadQualityReasons() async {
    if (_qualityReasons.isNotEmpty) return;
    _qualityReasons = await _repository.getQualityReasons();
    notifyListeners();
  }

  Future<bool> executeQualityHold({
    required int newStatus,
    required String reasonId,
    required String notes,
    String? qualityLocationId,
    List<QualityImageAttachment>? images,
  }) async {
    if (_currentHu == null) return false;

    _isHoldingQuality = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.holdHandlingUnit(
        huId: _currentHu!.id,
        newStatus: newStatus,
        reasonId: reasonId,
        notes: notes,
        qualityLocationId: qualityLocationId,
        images: images,
      );

      // Atualiza os dados da HU imediatamente para refletir o status de qualidade e endereço
      await searchHu(_currentHu!.lpn);
      return true;
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Falha ao registrar ocorrência de qualidade.')
            : 'Erro ao conectar à API de qualidade.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return false;
    } finally {
      _isHoldingQuality = false;
      notifyListeners();
    }
  }
}
