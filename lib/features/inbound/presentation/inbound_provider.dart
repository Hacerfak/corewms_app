import 'package:corewms_app/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../hu/data/hu_models.dart';
import '../data/inbound_models.dart';
import '../data/inbound_repository.dart';

class InboundProvider extends ChangeNotifier {
  final InboundRepository _repository;
  ApiClient get repositoryApi => _repository.api;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<InboundOrderSummary> _orders = [];
  List<InboundOrderSummary> get orders => _orders;

  InboundOrderDetails? _currentOrder;
  InboundOrderDetails? get currentOrder => _currentOrder;

  List<LocationModel> _docks = [];
  List<LocationModel> get docks => _docks;

  List<BillingServiceOption> _billingServices = [];
  List<BillingServiceOption> get billingServices => _billingServices;

  InboundProvider(this._repository);

  /// Carrega apenas ordens revisadas e em aberto para descarga no coletor
  Future<void> loadOrders({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allOrders = await _repository.getOrders(search: search);

      // REFINAMENTO 1:
      // - Não pode ter itens com pré-cadastro pendente (hasPendingReview == false)
      // - Não pode estar cancelada e nem 100% concluída
      _orders = allOrders.where((o) {
        final statusUpper = o.status.toUpperCase();
        final isFinished =
            statusUpper == 'COMPLETED' || statusUpper == 'CANCELED';
        return !o.hasPendingReview && !isFinished;
      }).toList();
    } catch (e) {
      _errorMessage = 'Falha ao buscar ordens de recebimento.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrderDetails(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentOrder = await _repository.getOrderById(orderId);
    } catch (e) {
      _errorMessage = 'Falha ao obter detalhes da ordem de recebimento.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDocksAndServices() async {
    if (_docks.isEmpty) {
      _docks = await _repository.getDockLocations();
    }
    if (_billingServices.isEmpty) {
      _billingServices = await _repository.getBillingServices();
    }
    notifyListeners();
  }

  Future<bool> startReceivingItem({
    required String orderItemId,
    required String dockLocationId,
  }) async {
    try {
      await _repository.startReceiving(
        orderItemId: orderItemId,
        dockLocationId: dockLocationId,
      );
      return true;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Falha ao iniciar recebimento.';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> releaseItem(String orderItemId) async {
    try {
      await _repository.releaseItem(orderItemId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<GeneratedHuSummary>> checkoutLote({
    required String orderItemId,
    required List<dynamic> volumes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hus = await _repository.checkoutLote(
        orderItemId: orderItemId,
        volumes: volumes,
      );
      return hus;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Falha no checkout de volumes.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
