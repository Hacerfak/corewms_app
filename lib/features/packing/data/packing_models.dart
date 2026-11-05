/// Resumo da ordem no fluxo de Packing
class PackingOrderSummary {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? destinationName;
  final String? destinationCity;
  final String? destinationState;
  final DateTime expectedShipDate;
  final String status;
  final int itemsCount;

  PackingOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    this.destinationName,
    this.destinationCity,
    this.destinationState,
    required this.expectedShipDate,
    required this.status,
    required this.itemsCount,
  });

  factory PackingOrderSummary.fromJson(Map<String, dynamic> json) {
    return PackingOrderSummary(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Depositante',
      destinationName: json['destinationName']?.toString(),
      destinationCity: json['destinationCity']?.toString(),
      destinationState: json['destinationState']?.toString(),
      expectedShipDate: json['expectedShipDate'] != null
          ? DateTime.tryParse(json['expectedShipDate'].toString()) ??
                DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? 'Picking',
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Item a ser embalado na mesa
class PackingOrderItemModel {
  final String id;
  final String productId;
  final int lineNumber;
  final String skuCode;
  final String description;
  final String unit;
  final double expectedQuantity;
  final double allocatedQuantity;
  final double pickedQuantity;
  final double packedQuantity;
  final String status;

  PackingOrderItemModel({
    required this.id,
    required this.productId,
    required this.lineNumber,
    required this.skuCode,
    required this.description,
    required this.unit,
    required this.expectedQuantity,
    required this.allocatedQuantity,
    required this.pickedQuantity,
    required this.packedQuantity,
    required this.status,
  });

  bool get isFullyPicked =>
      pickedQuantity >= expectedQuantity && expectedQuantity > 0;
  bool get isFullyPacked =>
      packedQuantity >= expectedQuantity && expectedQuantity > 0;

  factory PackingOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PackingOrderItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      lineNumber: (json['lineNumber'] as num?)?.toInt() ?? 1,
      skuCode: json['skuCode']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'UN',
      expectedQuantity: (json['expectedQuantity'] as num?)?.toDouble() ?? 0.0,
      allocatedQuantity: (json['allocatedQuantity'] as num?)?.toDouble() ?? 0.0,
      pickedQuantity: (json['pickedQuantity'] as num?)?.toDouble() ?? 0.0,
      packedQuantity: (json['packedQuantity'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

/// Apontamento de Embalagem do Item (Momento 1)
class ItemPackEntry {
  String packagingTypeId;
  String packagingCode;
  int volumeCount;
  double quantityPerVolume;

  ItemPackEntry({
    required this.packagingTypeId,
    required this.packagingCode,
    required this.volumeCount,
    required this.quantityPerVolume,
  });

  double get totalPieces => volumeCount * quantityPerVolume;

  Map<String, dynamic> toJson() => {
    'packagingTypeId': packagingTypeId,
    'volumeCount': volumeCount,
    'quantityPerVolume': quantityPerVolume,
  };
}

/// Volume Final de Transporte (Momento 2)
class ShippingVolumeEntry {
  String packagingTypeId;
  String packagingCode;
  int volumeCount;
  double? grossWeight;

  ShippingVolumeEntry({
    required this.packagingTypeId,
    required this.packagingCode,
    required this.volumeCount,
    this.grossWeight,
  });

  Map<String, dynamic> toJson() => {
    'packagingTypeId': packagingTypeId,
    'volumeCount': volumeCount,
    if (grossWeight != null && grossWeight! > 0) 'grossWeight': grossWeight,
  };
}
