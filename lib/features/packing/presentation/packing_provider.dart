import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../hu/data/hu_models.dart';
import '../../inbound/data/inbound_models.dart';
import '../data/packing_models.dart';
import '../data/packing_repository.dart';

class PackingProvider extends ChangeNotifier {
  final PackingRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<PackingOrderSummary> _orders = [];
  List<PackingOrderSummary> get orders => _orders;

  List<PackingOrderItemModel> _currentItems = [];
  List<PackingOrderItemModel> get currentItems => _currentItems;

  List<LocationModel> _docks = [];
  List<LocationModel> get docks => _docks;

  List<BillingServiceOption> _billingServices = [];
  List<BillingServiceOption> get billingServices => _billingServices;

  PackingProvider(this._repository);

  Future<void> loadOrders({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _repository.getOrdersForPacking(search: search);
    } catch (e) {
      _errorMessage = 'Falha ao buscar pedidos em packing.';
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
      final results = await Future.wait([
        _repository.getOrderItems(orderId),
        if (_docks.isEmpty)
          _repository.getDockLocations()
        else
          Future.value(_docks),
        if (_billingServices.isEmpty)
          _repository.getBillingServices()
        else
          Future.value(_billingServices),
      ]);

      _currentItems = results[0] as List<PackingOrderItemModel>;
      _docks = results[1] as List<LocationModel>;
      _billingServices = results[2] as List<BillingServiceOption>;
    } catch (e) {
      _errorMessage = 'Falha ao obter itens da ordem.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ItemPackEntry>> loadItemPacks(
    String orderId,
    String orderItemId,
  ) => _repository.getItemPacks(orderId, orderItemId);

  Future<List<ProductPackagingOption>> loadProductPackagings(
    String productId,
  ) => _repository.getProductPackagings(productId);

  Future<bool> packItem({
    required String orderId,
    required String orderItemId,
    required List<ItemPackEntry> packs,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.saveItemPacking(
        orderId: orderId,
        orderItemId: orderItemId,
        packs: packs,
      );
      if (success) {
        await loadOrderDetails(orderId);
      }
      return success;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Erro ao salvar embalagem do item.';
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

  Future<bool> finalizePacking({
    required String orderId,
    required String dockLocationId,
    required bool usedStretchFilm,
    required List<ShippingVolumeEntry> shippingVolumes,
    String? handlingServiceId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.finalizeOrderPacking(
        orderId: orderId,
        dockLocationId: dockLocationId,
        usedStretchFilm: usedStretchFilm,
        shippingVolumes: shippingVolumes,
        handlingServiceId: handlingServiceId,
      );
      if (success) {
        await loadOrders();
      }
      return success;
    } catch (e) {
      if (e is DioException) {
        _errorMessage =
            e.response?.data?['message'] ?? 'Erro ao finalizar packing.';
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
