class InboundOrderSummary {
  final String id;
  final String? customerId;
  final String? customerName;
  final String issuerCnpj;
  final String issuerName;
  final String accessKey;
  final DateTime issueDate;
  final String status;
  final bool hasPendingReview;
  final String? invoiceNumber;
  final String? invoiceSerie;

  InboundOrderSummary({
    required this.id,
    this.customerId,
    this.customerName,
    required this.issuerCnpj,
    required this.issuerName,
    required this.accessKey,
    required this.issueDate,
    required this.status,
    required this.hasPendingReview,
    this.invoiceNumber,
    this.invoiceSerie,
  });

  factory InboundOrderSummary.fromJson(Map<String, dynamic> json) {
    final key = json['accessKey']?.toString() ?? '';
    String? nfeNum = json['invoiceNumber']?.toString();
    String? nfeSerie = json['invoiceSerie']?.toString();

    if (key.length == 44) {
      nfeSerie ??= int.tryParse(key.substring(22, 25))?.toString();
      nfeNum ??= int.tryParse(key.substring(25, 34))?.toString();
    }

    return InboundOrderSummary(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Depositante',
      issuerCnpj: json['issuerCnpj']?.toString() ?? '',
      issuerName: json['issuerName']?.toString() ?? 'Fornecedor',
      accessKey: key,
      issueDate: json['issueDate'] != null
          ? DateTime.parse(json['issueDate'].toString())
          : DateTime.now(),
      status: json['status']?.toString() ?? 'Pending',
      hasPendingReview: json['hasPendingReview'] == true,
      invoiceNumber: nfeNum,
      invoiceSerie: nfeSerie,
    );
  }
}

class InboundOrderItemModel {
  final String id;
  final String? productId;
  final int lineNumber;
  final String sku;
  final String description;
  final String unit;
  final double expectedQuantity;
  final double receivedQuantity;
  final String status;
  final String? lockedByUserId;
  final String? lockedByUserName; // <-- Nome do Operador
  final String? dockLocationId;
  final String? dockLocationPath;
  final String? expectedBatch;
  final DateTime? expectedManufactureDate;
  final DateTime? expectedExpirationDate;

  InboundOrderItemModel({
    required this.id,
    this.productId,
    required this.lineNumber,
    required this.sku,
    required this.description,
    required this.unit,
    required this.expectedQuantity,
    required this.receivedQuantity,
    required this.status,
    this.lockedByUserId,
    this.lockedByUserName,
    this.dockLocationId,
    this.dockLocationPath,
    this.expectedBatch,
    this.expectedManufactureDate,
    this.expectedExpirationDate,
  });

  bool get isCompleted =>
      status == 'Completed' ||
      (expectedQuantity > 0 && receivedQuantity >= expectedQuantity);
  bool get isReceiving => status == 'Receiving';
  bool get isPendingReview => status == 'Pending_Review';

  factory InboundOrderItemModel.fromJson(Map<String, dynamic> json) {
    return InboundOrderItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString(),
      lineNumber: (json['lineNumber'] as num?)?.toInt() ?? 1,
      sku: json['sku']?.toString() ?? json['rawSkuCode']?.toString() ?? '',
      description:
          json['description']?.toString() ??
          json['rawDescription']?.toString() ??
          '',
      unit: json['unit']?.toString() ?? json['rawUnit']?.toString() ?? 'UN',
      expectedQuantity: (json['expectedQuantity'] ?? 0).toDouble(),
      receivedQuantity: (json['receivedQuantity'] ?? 0).toDouble(),
      status: json['status']?.toString() ?? 'Ready_To_Receive',
      lockedByUserId: json['lockedByUserId']?.toString(),
      lockedByUserName:
          json['lockedByUserName']?.toString() ??
          json['lockedByName']?.toString(),
      dockLocationId: json['dockLocationId']?.toString(),
      dockLocationPath: json['dockLocationPath']?.toString(),
      expectedBatch: json['expectedBatch']?.toString(),
      expectedManufactureDate: json['expectedManufactureDate'] != null
          ? DateTime.tryParse(json['expectedManufactureDate'].toString())
          : null,
      expectedExpirationDate: json['expectedExpirationDate'] != null
          ? DateTime.tryParse(json['expectedExpirationDate'].toString())
          : null,
    );
  }
}

class ProductTraceabilityRules {
  final bool tracksBatch;
  final bool strictBatch;
  final bool tracksManufacture;
  final bool strictManufacture;
  final bool tracksExpiration;
  final bool strictExpiration;
  final bool tracksSerial;
  final bool strictSerial;

  ProductTraceabilityRules({
    this.tracksBatch = false,
    this.strictBatch = false,
    this.tracksManufacture = false,
    this.strictManufacture = false,
    this.tracksExpiration = false,
    this.strictExpiration = false,
    this.tracksSerial = false,
    this.strictSerial = false,
  });

  bool get hasAnyTracking =>
      tracksBatch || tracksManufacture || tracksExpiration || tracksSerial;

  factory ProductTraceabilityRules.fromJson(Map<String, dynamic> json) {
    return ProductTraceabilityRules(
      tracksBatch: json['tracksBatch'] == true,
      strictBatch: json['strictBatch'] == true,
      tracksManufacture: json['tracksManufacture'] == true,
      strictManufacture: json['strictManufacture'] == true,
      tracksExpiration: json['tracksExpiration'] == true,
      strictExpiration: json['strictExpiration'] == true,
      tracksSerial: json['tracksSerial'] == true,
      strictSerial: json['strictSerial'] == true,
    );
  }
}

class InboundOrderDetails {
  final String id;
  final String? customerId;
  final String? customerName;
  final String issuerCnpj;
  final String issuerName;
  final String accessKey;
  final DateTime issueDate;
  final String status;
  final List<InboundOrderItemModel> items;

  InboundOrderDetails({
    required this.id,
    this.customerId,
    this.customerName,
    required this.issuerCnpj,
    required this.issuerName,
    required this.accessKey,
    required this.issueDate,
    required this.status,
    required this.items,
  });

  factory InboundOrderDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return InboundOrderDetails(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Depositante',
      issuerCnpj: json['issuerCnpj']?.toString() ?? '',
      issuerName: json['issuerName']?.toString() ?? '',
      accessKey: json['accessKey']?.toString() ?? '',
      issueDate: json['issueDate'] != null
          ? DateTime.parse(json['issueDate'].toString())
          : DateTime.now(),
      status: json['status']?.toString() ?? 'Pending',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => InboundOrderItemModel.fromJson(i))
          .toList(),
    );
  }
}

class BillingServiceOption {
  final String id;
  final String name;

  BillingServiceOption({required this.id, required this.name});

  factory BillingServiceOption.fromJson(Map<String, dynamic> json) {
    return BillingServiceOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class GeneratedHuSummary {
  final String id;
  final String lpn;

  GeneratedHuSummary({required this.id, required this.lpn});

  factory GeneratedHuSummary.fromJson(dynamic json) {
    if (json is Map) {
      return GeneratedHuSummary(
        id: json['id']?.toString() ?? '',
        lpn: json['lpn']?.toString() ?? '',
      );
    }
    return GeneratedHuSummary(id: json.toString(), lpn: json.toString());
  }
}
