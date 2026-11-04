import '../../inbound/data/inbound_models.dart';

/// DTO oficial retornado por /api/inventory/putaway/suggestions/{orderId}
class PutawaySuggestionModel {
  final String handlingUnitId;
  final String lpn;
  final String productId;
  final String productSku;
  final String productDescription;
  final String unit;
  final String? batch;
  final double quantity;
  final String qualityStatus;
  String suggestedLocationId;
  String suggestedLocationFullPath;
  String suggestionReason;

  PutawaySuggestionModel({
    required this.handlingUnitId,
    required this.lpn,
    required this.productId,
    required this.productSku,
    required this.productDescription,
    required this.unit,
    this.batch,
    required this.quantity,
    required this.qualityStatus,
    required this.suggestedLocationId,
    required this.suggestedLocationFullPath,
    required this.suggestionReason,
  });

  bool get isQualityRestricted =>
      qualityStatus != 'Available' && qualityStatus != '1';

  factory PutawaySuggestionModel.fromJson(Map<String, dynamic> json) {
    return PutawaySuggestionModel(
      handlingUnitId: json['handlingUnitId']?.toString() ?? '',
      lpn: json['lpn']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productSku: json['productSku']?.toString() ?? '',
      productDescription: json['productDescription']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'UN',
      batch: json['batch']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      qualityStatus: json['qualityStatus']?.toString() ?? 'Available',
      suggestedLocationId: json['suggestedLocationId']?.toString() ?? '',
      suggestedLocationFullPath:
          json['suggestedLocationFullPath']?.toString() ?? '',
      suggestionReason:
          json['suggestionReason']?.toString() ?? 'Capacidade livre',
    );
  }
}

/// Ordem de Entrada filtrada com HUs ativas na Doca
class AllocationOrderSummary {
  final InboundOrderSummary order;
  final int pendingHusCount;
  final double totalQuantity;
  final List<PutawaySuggestionModel> suggestions;

  AllocationOrderSummary({
    required this.order,
    required this.pendingHusCount,
    required this.totalQuantity,
    required this.suggestions,
  });
}
