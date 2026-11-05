/// Resumo da ordem para listagem na conferência
class CheckingOrderSummary {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? destinationName;
  final String? destinationCity;
  final String? destinationState;
  final DateTime expectedShipDate;
  final String status;
  final int itemsCount;

  CheckingOrderSummary({
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

  factory CheckingOrderSummary.fromJson(Map<String, dynamic> json) {
    return CheckingOrderSummary(
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
      status: json['status']?.toString() ?? 'Checking',
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Item analítico da ordem em conferência (CheckingItemDto)
class CheckingItemModel {
  final String orderItemId;
  final String productId;
  final String skuCode;
  final String description;
  final String unit;
  final double expectedQuantity;
  final double pickedQuantity;
  final double packedQuantity;
  final double checkedQuantity;
  final bool isFullyChecked;

  CheckingItemModel({
    required this.orderItemId,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.unit,
    required this.expectedQuantity,
    required this.pickedQuantity,
    required this.packedQuantity,
    required this.checkedQuantity,
    required this.isFullyChecked,
  });

  factory CheckingItemModel.fromJson(Map<String, dynamic> json) {
    return CheckingItemModel(
      orderItemId: json['orderItemId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      skuCode: json['skuCode']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'UN',
      expectedQuantity: (json['expectedQuantity'] as num?)?.toDouble() ?? 0.0,
      pickedQuantity: (json['pickedQuantity'] as num?)?.toDouble() ?? 0.0,
      packedQuantity: (json['packedQuantity'] as num?)?.toDouble() ?? 0.0,
      checkedQuantity: (json['checkedQuantity'] as num?)?.toDouble() ?? 0.0,
      isFullyChecked: json['isFullyChecked'] == true,
    );
  }
}

/// Volume ou HU rastreável vinculado à ordem (CheckingVolumeHuDto)
class CheckingVolumeModel {
  final String id;
  final String lpn;
  final String skuCode;
  final double quantity;
  final String unit;
  final String locationPath;
  final bool isPicked;
  final String? pickedByName;
  final DateTime? pickedAt;
  final bool isChecked;
  final String? checkedByName;
  final DateTime? checkedAt;

  CheckingVolumeModel({
    required this.id,
    required this.lpn,
    required this.skuCode,
    required this.quantity,
    required this.unit,
    required this.locationPath,
    required this.isPicked,
    this.pickedByName,
    this.pickedAt,
    required this.isChecked,
    this.checkedByName,
    this.checkedAt,
  });

  factory CheckingVolumeModel.fromJson(Map<String, dynamic> json) {
    return CheckingVolumeModel(
      id: json['id']?.toString() ?? '',
      lpn: json['lpn']?.toString() ?? '',
      skuCode: json['skuCode']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? 'UN',
      locationPath: json['locationPath']?.toString() ?? 'DOCA',
      isPicked: json['isPicked'] == true,
      pickedByName: json['pickedByName']?.toString(),
      pickedAt: json['pickedAt'] != null
          ? DateTime.tryParse(json['pickedAt'].toString())
          : null,
      isChecked: json['isChecked'] == true,
      checkedByName: json['checkedByName']?.toString(),
      checkedAt: json['checkedAt'] != null
          ? DateTime.tryParse(json['checkedAt'].toString())
          : null,
    );
  }
}

/// Estado consolidado da conferência (OutboundCheckingSummaryDto)
class OrderCheckingDetails {
  final String orderId;
  final String orderNumber;
  final String customerName;
  final String status;
  final double totalExpected;
  final double totalPicked;
  final double totalChecked;
  final bool isOrderFullyChecked;
  final bool hasFractionalPendingPacking;
  final List<CheckingItemModel> items;
  final List<CheckingVolumeModel> volumes;

  OrderCheckingDetails({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.totalExpected,
    required this.totalPicked,
    required this.totalChecked,
    required this.isOrderFullyChecked,
    required this.hasFractionalPendingPacking,
    required this.items,
    required this.volumes,
  });

  factory OrderCheckingDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawVolumes = json['volumes'] as List<dynamic>? ?? [];

    return OrderCheckingDetails(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Depositante',
      status: json['status']?.toString() ?? 'Checking',
      totalExpected: (json['totalExpected'] as num?)?.toDouble() ?? 0.0,
      totalPicked: (json['totalPicked'] as num?)?.toDouble() ?? 0.0,
      totalChecked: (json['totalChecked'] as num?)?.toDouble() ?? 0.0,
      isOrderFullyChecked: json['isOrderFullyChecked'] == true,
      hasFractionalPendingPacking: json['hasFractionalPendingPacking'] == true,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => CheckingItemModel.fromJson(i))
          .toList(),
      volumes: rawVolumes
          .whereType<Map<String, dynamic>>()
          .map((v) => CheckingVolumeModel.fromJson(v))
          .toList(),
    );
  }
}
