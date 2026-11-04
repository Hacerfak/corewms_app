import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/quality_models.dart';
import '../data/quality_repository.dart';

class QualityProvider extends ChangeNotifier {
  final QualityRepository _repository;

  bool _isLoadingReasons = false;
  bool get isLoadingReasons => _isLoadingReasons;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<QualityReasonModel> _reasons = [];
  List<QualityReasonModel> get reasons => _reasons;

  QualityProvider(this._repository);

  /// Carrega os motivos cadastrados no armazém
  Future<void> loadReasons() async {
    if (_reasons.isNotEmpty) return;
    _isLoadingReasons = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reasons = await _repository.getReasons();
    } catch (e) {
      _errorMessage = 'Falha ao buscar catálogo de motivos de qualidade.';
    } finally {
      _isLoadingReasons = false;
      notifyListeners();
    }
  }

  /// Executa o bloqueio de HUs existentes
  Future<bool> executeHold({
    required List<String> handlingUnitIds,
    required int newStatus,
    required String reasonId,
    required String notes,
    String? qualityLocationId,
    List<QualityImageAttachment>? images,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.holdHandlingUnits(
        handlingUnitIds: handlingUnitIds,
        newStatus: newStatus,
        reasonId: reasonId,
        notes: notes,
        qualityLocationId: qualityLocationId,
        images: images,
      );
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
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
