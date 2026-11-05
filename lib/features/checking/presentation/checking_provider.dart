import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/checking_models.dart';
import '../data/checking_repository.dart';

class CheckingProvider extends ChangeNotifier {
  final CheckingRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<CheckingOrderSummary> _orders = [];
  List<CheckingOrderSummary> get orders => _orders;

  OrderCheckingDetails? _currentDetails;
  OrderCheckingDetails? get currentDetails => _currentDetails;

  CheckingProvider(this._repository);

  Future<void> loadOrders({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrdersForChecking(search: search);
    } catch (e) {
      _errorMessage = 'Falha ao buscar ordens para conferência.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrderTasks(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentDetails = await _repository.getOrderCheckingTasks(orderId);
    } catch (e) {
      _errorMessage = 'Falha ao carregar itens da conferência.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Executa o scan do código lido
  Future<dynamic> scanCode({
    required String orderId,
    required String scannedCode,
    double? quantity,
  }) async {
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.checkItem(
        orderId: orderId,
        scannedCode: scannedCode,
        quantity: quantity,
      );

      // Recarrega o espelho de conferência após cada leitura confirmada
      await loadOrderTasks(orderId);
      return result;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Código inválido para este pedido.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return null;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> resetChecking(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.resetChecking(orderId);
      if (success) {
        await loadOrderTasks(orderId);
      }
      return success;
    } catch (e) {
      _errorMessage = 'Falha ao resetar conferência.';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
