import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/picking_models.dart';
import '../data/picking_repository.dart';

enum PickingViewMode { byLocation, byOrder }

class PickingProvider extends ChangeNotifier {
  final PickingRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPicking = false;
  bool get isPicking => _isPicking;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PickingViewMode _viewMode = PickingViewMode.byLocation;
  PickingViewMode get viewMode => _viewMode;

  // Lista dos pedidos aptos para picking
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> get activeOrders => _activeOrders;

  // Lista consolidada de todas as tarefas de picking de todos os pedidos
  List<ConsolidatedPickingTask> _allTasks = [];
  List<ConsolidatedPickingTask> get allTasks => _allTasks;

  // Tarefas agrupadas por endereço
  List<LocationPickingGroup> _locationGroups = [];
  List<LocationPickingGroup> get locationGroups => _locationGroups;

  // Detalhes do pedido atualmente aberto (Visão por Pedido)
  PickingOrderSummaryModel? _currentOrderSummary;
  PickingOrderSummaryModel? get currentOrderSummary => _currentOrderSummary;

  PickingProvider(this._repository);

  void setViewMode(PickingViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  /// Carrega todos os pedidos e consolida as tarefas de todos eles para a visão por endereço
  Future<void> loadAllData({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeOrders = (await _repository.getActivePickingOrders(search: search))
          .map((order) => Map<String, dynamic>.from(order as Map))
          .toList();

      // Busca as tarefas de picking de cada pedido ativo em paralelo
      final tasksFutures = _activeOrders.map((o) async {
        final orderId = o['id']?.toString() ?? '';
        if (orderId.isEmpty) return null;
        return await _repository.getOrderPickingTasks(orderId);
      });

      final ordersTasks = await Future.wait(tasksFutures);

      final List<ConsolidatedPickingTask> flatTasks = [];
      for (final summary in ordersTasks) {
        if (summary == null) continue;
        for (final item in summary.items) {
          for (final alloc in item.allocations) {
            flatTasks.add(
              ConsolidatedPickingTask(
                orderId: summary.orderId,
                orderNumber: summary.orderNumber,
                customerName: summary.customerName,
                destinationName: summary.destinationName,
                orderItemId: item.orderItemId,
                productId: item.productId,
                skuCode: item.skuCode,
                description: item.description,
                baseUnit: item.baseUnit,
                allocationId: alloc.allocationId,
                handlingUnitId: alloc.handlingUnitId,
                lpn: alloc.lpn,
                locationPath: alloc.locationPath,
                packagingCode: alloc.packagingCode,
                batch: alloc.batch,
                expirationDate: alloc.expirationDate,
                quantity: alloc.quantity,
                isPicked: alloc.isPicked,
              ),
            );
          }
        }
      }

      _allTasks = flatTasks;
      _buildLocationGroups();
    } catch (e) {
      _errorMessage = 'Falha ao sincronizar tarefas de separação.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return;
  }

  void _buildLocationGroups() {
    final Map<String, List<ConsolidatedPickingTask>> map = {};
    for (final task in _allTasks) {
      map.putIfAbsent(task.locationPath, () => []).add(task);
    }

    _locationGroups = map.entries.map((entry) {
      return LocationPickingGroup(locationPath: entry.key, tasks: entry.value);
    }).toList();

    // Ordena pelo endereço para formar o roteiro de picking
    _locationGroups.sort((a, b) => a.locationPath.compareTo(b.locationPath));
  }

  /// Carrega as tarefas de um único pedido selecionado
  Future<void> loadSingleOrderTasks(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentOrderSummary = await _repository.getOrderPickingTasks(orderId);
    } catch (e) {
      _errorMessage = 'Falha ao buscar tarefas do pedido.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agrupa as tarefas do pedido aberto por endereço completo
  List<LocationPickingGroup> get currentOrderGroupsByLocation {
    if (_currentOrderSummary == null) return [];

    final Map<String, List<ConsolidatedPickingTask>> map = {};
    for (final item in _currentOrderSummary!.items) {
      for (final alloc in item.allocations) {
        final task = ConsolidatedPickingTask(
          orderId: _currentOrderSummary!.orderId,
          orderNumber: _currentOrderSummary!.orderNumber,
          customerName: _currentOrderSummary!.customerName,
          destinationName: _currentOrderSummary!.destinationName,
          orderItemId: item.orderItemId,
          productId: item.productId,
          skuCode: item.skuCode,
          description: item.description,
          baseUnit: item.baseUnit,
          allocationId: alloc.allocationId,
          handlingUnitId: alloc.handlingUnitId,
          lpn: alloc.lpn,
          locationPath: alloc.locationPath,
          packagingCode: alloc.packagingCode,
          batch: alloc.batch,
          expirationDate: alloc.expirationDate,
          quantity: alloc.quantity,
          isPicked: alloc.isPicked,
        );
        map.putIfAbsent(alloc.locationPath, () => []).add(task);
      }
    }

    final groups = map.entries.map((entry) {
      return LocationPickingGroup(locationPath: entry.key, tasks: entry.value);
    }).toList();

    groups.sort((a, b) => a.locationPath.compareTo(b.locationPath));
    return groups;
  }

  /// Executa o scan e a confirmação de recolha
  Future<dynamic> executePick({
    required String orderId,
    required String? orderItemId,
    required String scannedLpn,
    required double pickedQuantity,
  }) async {
    _isPicking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _repository.scanAndPick(
        orderId: orderId,
        orderItemId: orderItemId,
        scannedLpn: scannedLpn,
        pickedQuantity: pickedQuantity,
      );

      // Recarrega os dados para atualizar as listas
      await loadAllData();
      if (_currentOrderSummary != null) {
        await loadSingleOrderTasks(_currentOrderSummary!.orderId);
      }
      return res;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Falha ao registrar picking.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return null;
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  /// Procura uma tarefa pendente correspondente ao LPN bipado
  ConsolidatedPickingTask? findPendingTaskByLpn(String lpn) {
    final clean = lpn.trim().toUpperCase();
    return _allTasks.cast<ConsolidatedPickingTask?>().firstWhere(
      (t) => t != null && !t.isPicked && t.lpn.toUpperCase() == clean,
      orElse: () => null,
    );
  }
}
