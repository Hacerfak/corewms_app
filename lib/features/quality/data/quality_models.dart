import 'dart:typed_data';

/// Status de qualidade alinhado ao backend (Inventory.Enums.QualityStatus)
enum QualityStatusTarget {
  damaged(3, 'Avaria', 'Dano físico / produto quebrado ou violado'),
  quarantine(
    2,
    'Quarentena',
    'Retenção técnica / inspeção ou bloqueio preventivo',
  );

  final int value;
  final String label;
  final String description;

  const QualityStatusTarget(this.value, this.label, this.description);
}

/// Motivo retornado pelo endpoint GET /api/quality/reasons
class QualityReasonModel {
  final String id;
  final String code;
  final String description;
  final bool isActive;

  QualityReasonModel({
    required this.id,
    required this.code,
    required this.description,
    required this.isActive,
  });

  factory QualityReasonModel.fromJson(Map<String, dynamic> json) {
    return QualityReasonModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description:
          json['description']?.toString() ?? json['code']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}

/// Evidência fotográfica para compressão no servidor via Skia
class QualityImageAttachment {
  final String fileName;
  final String base64Data;
  final Uint8List previewBytes;

  QualityImageAttachment({
    required this.fileName,
    required this.base64Data,
    required this.previewBytes,
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'base64Data': base64Data,
  };
}

/// Dados consolidados do apontamento (utilizado tanto em HUs quanto no Inbound)
class QualityIncidentData {
  final QualityStatusTarget status;
  final String reasonId;
  final String reasonCode;
  final String notes;
  final String? targetLocationId;
  final String? targetLocationPath;
  final List<QualityImageAttachment> images;

  QualityIncidentData({
    required this.status,
    required this.reasonId,
    required this.reasonCode,
    required this.notes,
    this.targetLocationId,
    this.targetLocationPath,
    required this.images,
  });
}
