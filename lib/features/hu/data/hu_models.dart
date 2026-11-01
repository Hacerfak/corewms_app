class HandlingUnitModel {
  final String id;
  final String lpn;
  final String productId;
  final String productSku;
  final String productDescription;
  final String productBaseUnit;
  final String customerId;
  final String customerName;
  final double currentQuantity;
  final String? currentLocationId;
  final String currentLocationPath;
  final String? batch;
  final DateTime? expirationDate;
  final DateTime? manufactureDate;
  final String status;
  final String qualityStatus;
  final String? packagingTypeCode;
  final String? packagingTypeDescription;
  final double? unitNetWeight;
  final double? unitGrossWeight;

  // Dados da NF-e
  final String? inboundOrderId;
  final String? invoiceNumber;
  final String? invoiceSerie;
  final String? accessKey;
  final String? issuerName;
  final String? issuerCnpj;
  final DateTime? invoiceIssueDate;
  final DateTime? receiptDate;
  final double? unitValue;

  HandlingUnitModel({
    required this.id,
    required this.lpn,
    required this.productId,
    required this.productSku,
    required this.productDescription,
    required this.productBaseUnit,
    required this.customerId,
    required this.customerName,
    required this.currentQuantity,
    this.currentLocationId,
    required this.currentLocationPath,
    this.batch,
    this.expirationDate,
    this.manufactureDate,
    required this.status,
    required this.qualityStatus,
    this.packagingTypeCode,
    this.packagingTypeDescription,
    this.unitNetWeight,
    this.unitGrossWeight,
    this.inboundOrderId,
    this.invoiceNumber,
    this.invoiceSerie,
    this.accessKey,
    this.issuerName,
    this.issuerCnpj,
    this.invoiceIssueDate,
    this.receiptDate,
    this.unitValue,
  });

  /// REGRA: Apenas HUs disponíveis no Armazém ou Doca podem receber ações operacionais
  bool get canPerformActions {
    if (currentQuantity <= 0) return false;
    final s = status.toUpperCase().trim();
    return s == 'STORED' || s == 'RECEIVED' || s == 'INDOCK';
  }

  double get totalValue => currentQuantity * (unitValue ?? 0.0);
  double get totalNetWeight => currentQuantity * (unitNetWeight ?? 0.0);
  double get totalGrossWeight => currentQuantity * (unitGrossWeight ?? 0.0);

  factory HandlingUnitModel.fromJson(Map<String, dynamic> json) {
    final rawAccessKey = json['accessKey']?.toString();
    var rawInvoiceNumber =
        json['nfeNumber']?.toString() ?? json['invoiceNumber']?.toString();
    var rawInvoiceSerie =
        json['nfeSeries']?.toString() ?? json['invoiceSerie']?.toString();

    if (rawAccessKey != null && rawAccessKey.length == 44) {
      rawInvoiceSerie ??= int.tryParse(rawAccessKey.substring(22, 25))
          ?.toString();
      rawInvoiceNumber ??= int.tryParse(rawAccessKey.substring(25, 34))
          ?.toString();
    }

    final packCode =
        json['packagingTypeCode']?.toString() ??
        json['packagingType']?['code']?.toString() ??
        'PLT';
    final packDesc =
        json['packagingTypeDescription']?.toString() ??
        json['packagingType']?['description']?.toString();

    return HandlingUnitModel(
      id: json['id']?.toString() ?? '',
      lpn: json['lpn']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productSku:
          json['productSku']?.toString() ?? json['sku']?.toString() ?? '',
      productDescription:
          json['productDescription']?.toString() ??
          json['description']?.toString() ??
          '',
      productBaseUnit:
          json['unit']?.toString() ??
          json['productBaseUnit']?.toString() ??
          'UN',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Depositante',
      currentQuantity: (json['currentQuantity'] ?? json['quantity'] ?? 0)
          .toDouble(),
      currentLocationId: json['currentLocationId']?.toString(),
      currentLocationPath:
          json['locationPath']?.toString() ??
          json['currentLocationPath']?.toString() ??
          'Não Endereçado',
      batch: json['batch']?.toString(),
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'].toString())
          : null,
      manufactureDate: json['manufactureDate'] != null
          ? DateTime.tryParse(json['manufactureDate'].toString())
          : null,
      status: json['status']?.toString() ?? 'Stored',
      qualityStatus: json['qualityStatus']?.toString() ?? 'Available',
      packagingTypeCode: packCode,
      packagingTypeDescription: packDesc,
      unitNetWeight: json['unitNetWeight'] != null
          ? (json['unitNetWeight'] as num).toDouble()
          : null,
      unitGrossWeight: json['unitGrossWeight'] != null
          ? (json['unitGrossWeight'] as num).toDouble()
          : null,
      inboundOrderId:
          json['receiptDocumentId']?.toString() ??
          json['inboundOrderId']?.toString(),
      invoiceNumber: rawInvoiceNumber,
      invoiceSerie: rawInvoiceSerie,
      accessKey: rawAccessKey,
      issuerName: json['issuerName']?.toString(),
      issuerCnpj: json['issuerCnpj']?.toString(),
      invoiceIssueDate: json['invoiceIssueDate'] != null
          ? DateTime.tryParse(json['invoiceIssueDate'].toString())
          : null,
      receiptDate: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      unitValue: json['unitValue'] != null
          ? (json['unitValue'] as num).toDouble()
          : null,
    );
  }

  HandlingUnitModel copyWithInboundDetails({
    String? invoiceNumber,
    String? invoiceSerie,
    String? accessKey,
    String? issuerName,
    String? issuerCnpj,
    DateTime? invoiceIssueDate,
    DateTime? receiptDate,
  }) {
    return HandlingUnitModel(
      id: id,
      lpn: lpn,
      productId: productId,
      productSku: productSku,
      productDescription: productDescription,
      productBaseUnit: productBaseUnit,
      customerId: customerId,
      customerName: customerName,
      currentQuantity: currentQuantity,
      currentLocationId: currentLocationId,
      currentLocationPath: currentLocationPath,
      batch: batch,
      expirationDate: expirationDate,
      manufactureDate: manufactureDate,
      status: status,
      qualityStatus: qualityStatus,
      packagingTypeCode: packagingTypeCode,
      packagingTypeDescription: packagingTypeDescription,
      unitNetWeight: unitNetWeight,
      unitGrossWeight: unitGrossWeight,
      inboundOrderId: inboundOrderId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceSerie: invoiceSerie ?? this.invoiceSerie,
      accessKey: accessKey ?? this.accessKey,
      issuerName: issuerName ?? this.issuerName,
      issuerCnpj: issuerCnpj ?? this.issuerCnpj,
      invoiceIssueDate: invoiceIssueDate ?? this.invoiceIssueDate,
      receiptDate: receiptDate ?? this.receiptDate,
      unitValue: unitValue,
    );
  }
}

class LocationModel {
  final String id;
  final String fullPath;
  final String code;
  final String? role;

  LocationModel({
    required this.id,
    required this.fullPath,
    required this.code,
    this.role,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id']?.toString() ?? '',
      fullPath: json['fullPath']?.toString() ?? json['code']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      role: json['storageTypeName']?.toString() ?? json['role']?.toString(),
    );
  }
}
