import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../hu/data/hu_models.dart';
import '../../inbound/data/inbound_models.dart';
import '../data/allocation_models.dart';
import '../data/allocation_repository.dart';

class AllocationProvider extends ChangeNotifier {
  final AllocationRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Lista de ordens que POSSUEM HUs na doca
  List<AllocationOrderSummary> _ordersWithHus = [];
  List<AllocationOrderSummary> get ordersWithHus => _ordersWithHus;

  // Ordem ativa em alocação
  InboundOrderDetails? _currentOrder;
  InboundOrderDetails? get currentOrder => _currentOrder;

  // Sugestões inteligentes
  List<PutawaySuggestionModel> _suggestions = [];
  List<PutawaySuggestionModel> get suggestions => _suggestions;

  final Set<String> _selectedHuIds = {};
  Set<String> get selectedHuIds => _selectedHuIds;

  List<LocationModel> _storageLocations = [];
  List<LocationModel> get storageLocations => _storageLocations;

  List<LocationModel> _qualityLocations = [];
  List<LocationModel> get qualityLocations => _qualityLocations;

  AllocationProvider(this._repository);

  /// Carrega apenas ordens que têm ao menos 1 volume na doca
  Future<void> loadOrders({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _ordersWithHus = await _repository.getOrdersWithDockHus(search: search);
    } catch (e) {
      _errorMessage = 'Falha ao buscar ordens com volumes na Doca.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atalho de bipagem: resolve a ordem pelo LPN da HU
  Future<String?> resolveOrderIdFromLpn(String lpn) async {
    final hu = await _repository.getHuByLpn(lpn);
    return hu?.inboundOrderId;
  }

  /// Carrega as sugestões da NF escolhida
  Future<void> loadOrderSuggestions(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    _suggestions = [];
    _selectedHuIds.clear();
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getOrderById(orderId),
        _repository.getPutawaySuggestions(orderId),
        if (_storageLocations.isEmpty)
          _repository.getStorageLocations()
        else
          Future.value(_storageLocations),
        if (_qualityLocations.isEmpty)
          _repository.getQualityLocations()
        else
          Future.value(_qualityLocations),
      ]);

      _currentOrder = results[0] as InboundOrderDetails?;
      _suggestions = results[1] as List<PutawaySuggestionModel>;
      _storageLocations = results[2] as List<LocationModel>;
      _qualityLocations = results[3] as List<LocationModel>;

      // Todas as HUs iniciam selecionadas por padrão
      _selectedHuIds.addAll(_suggestions.map((s) => s.handlingUnitId));
    } catch (e) {
      _errorMessage = 'Falha ao carregar sugestões de alocação.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      _selectedHuIds.addAll(_suggestions.map((s) => s.handlingUnitId));
    } else {
      _selectedHuIds.clear();
    }
    notifyListeners();
  }

  void toggleHuSelection(String huId) {
    if (_selectedHuIds.contains(huId)) {
      _selectedHuIds.remove(huId);
    } else {
      _selectedHuIds.add(huId);
    }
    notifyListeners();
  }

  void updateHuLocation(
    String huId,
    String newLocationId,
    String newLocationPath,
  ) {
    final item = _suggestions.firstWhere((s) => s.handlingUnitId == huId);
    item.suggestedLocationId = newLocationId;
    item.suggestedLocationFullPath = newLocationPath;
    item.suggestionReason = 'Alterado manualmente pelo operador';
    notifyListeners();
  }

  void applyBulkLocation(String locationId, String locationPath) {
    for (final s in _suggestions) {
      if (_selectedHuIds.contains(s.handlingUnitId)) {
        s.suggestedLocationId = locationId;
        s.suggestedLocationFullPath = locationPath;
        s.suggestionReason = 'Alteração em lote pelo operador';
      }
    }
    notifyListeners();
  }

  Future<LocationModel?> findLocationByCode(String code) =>
      _repository.findLocationByCode(code);

  Future<bool> confirmPutaway() async {
    final itemsToAllocate = _suggestions
        .where((s) => _selectedHuIds.contains(s.handlingUnitId))
        .toList();
    if (itemsToAllocate.isEmpty) return false;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, List<String>> grouped = {};
      for (final item in itemsToAllocate) {
        grouped
            .putIfAbsent(item.suggestedLocationId, () => [])
            .add(item.handlingUnitId);
      }

      final success = await _repository.executePutaway(grouped);
      if (success && _currentOrder != null) {
        await loadOrderSuggestions(_currentOrder!.id);
      }
      return success;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Erro ao efetivar alocação.';
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
