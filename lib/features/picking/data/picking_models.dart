/// Unidade de manuseio alocada para separação (PickingAllocatedHuDto)
class PickingAllocatedHuModel {
  final String allocationId;
  final String handlingUnitId;
  final String lpn;
  final String locationPath;
  final String packagingCode;
  final String? batch;
  final DateTime? manufactureDate;
  final DateTime? expirationDate;
  final String? serialNumber;
  final double quantity;
  final bool isPicked;

  PickingAllocatedHuModel({
    required this.allocationId,
    required this.handlingUnitId,
    required this.lpn,
    required this.locationPath,
    required this.packagingCode,
    this.batch,
    this.manufactureDate,
    this.expirationDate,
    this.serialNumber,
    required this.quantity,
    required this.isPicked,
  });

  factory PickingAllocatedHuModel.fromJson(Map<String, dynamic> json) {
    return PickingAllocatedHuModel(
      allocationId: json['allocationId']?.toString() ?? '',
      handlingUnitId: json['handlingUnitId']?.toString() ?? '',
      lpn: json['lpn']?.toString() ?? '',
      locationPath: json['locationPath']?.toString() ?? 'SEM ENDEREÇO',
      packagingCode: json['packagingCode']?.toString() ?? 'PLT',
      batch: json['batch']?.toString(),
      manufactureDate: json['manufactureDate'] != null
          ? DateTime.tryParse(json['manufactureDate'].toString())
          : null,
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'].toString())
          : null,
      serialNumber: json['serialNumber']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      isPicked: json['isPicked'] == true,
    );
  }
}

/// Item do pedido contendo suas alocações (PickingItemTaskDto)
class PickingItemTaskModel {
  final String orderItemId;
  final String productId;
  final String skuCode;
  final String description;
  final String baseUnit;
  final double expectedQuantity;
  final double allocatedQuantity;
  final double pickedQuantity;
  final String status;
  final List<PickingAllocatedHuModel> allocations;

  PickingItemTaskModel({
    required this.orderItemId,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.baseUnit,
    required this.expectedQuantity,
    required this.allocatedQuantity,
    required this.pickedQuantity,
    required this.status,
    required this.allocations,
  });

  factory PickingItemTaskModel.fromJson(Map<String, dynamic> json) {
    final rawAllocations = json['allocations'] as List<dynamic>? ?? [];
    return PickingItemTaskModel(
      orderItemId: json['orderItemId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      skuCode: json['skuCode']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      baseUnit: json['baseUnit']?.toString() ?? 'UN',
      expectedQuantity: (json['expectedQuantity'] as num?)?.toDouble() ?? 0.0,
      allocatedQuantity: (json['allocatedQuantity'] as num?)?.toDouble() ?? 0.0,
      pickedQuantity: (json['pickedQuantity'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Allocated',
      allocations: rawAllocations
          .whereType<Map<String, dynamic>>()
          .map((a) => PickingAllocatedHuModel.fromJson(a))
          .toList(),
    );
  }
}

/// Resumo de tarefas de separação de um pedido (PickingOrderSummaryDto)
class PickingOrderSummaryModel {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? destinationName;
  final String status;
  final List<PickingItemTaskModel> items;

  PickingOrderSummaryModel({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.destinationName,
    required this.status,
    required this.items,
  });

  factory PickingOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PickingOrderSummaryModel(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      destinationName: json['destinationName']?.toString(),
      status: json['status']?.toString() ?? 'Allocated',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => PickingItemTaskModel.fromJson(i))
          .toList(),
    );
  }
}

/// Item atômico de picking (combina os dados do item com o pedido para agrupar por endereço)
class ConsolidatedPickingTask {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String? destinationName;
  final String orderItemId;
  final String productId;
  final String skuCode;
  final String description;
  final String baseUnit;
  final String allocationId;
  final String handlingUnitId;
  final String lpn;
  final String locationPath;
  final String packagingCode;
  final String? batch;
  final DateTime? expirationDate;
  final double quantity;
  final bool isPicked;

  ConsolidatedPickingTask({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    this.destinationName,
    required this.orderItemId,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.baseUnit,
    required this.allocationId,
    required this.handlingUnitId,
    required this.lpn,
    required this.locationPath,
    required this.packagingCode,
    this.batch,
    this.expirationDate,
    required this.quantity,
    required this.isPicked,
  });
}

/// Grupo de tarefas consolidadas pelo endereço completo
class LocationPickingGroup {
  final String locationPath;
  final List<ConsolidatedPickingTask> tasks;

  LocationPickingGroup({required this.locationPath, required this.tasks});

  int get pendingTasksCount => tasks.where((t) => !t.isPicked).length;
  double get totalPendingQuantity =>
      tasks.where((t) => !t.isPicked).fold(0.0, (sum, t) => sum + t.quantity);
  Set<String> get distinctOrderNumbers =>
      tasks.map((t) => t.orderNumber).toSet();
}
