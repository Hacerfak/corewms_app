class BlindLocationTaskModel {
  final String planId;
  final String planName;
  final String locationId;
  final String locationPath;
  final int currentRound;
  final bool isDynamicStorage;
  final String status;
  final int pendingTasksCount;

  BlindLocationTaskModel({
    required this.planId,
    required this.planName,
    required this.locationId,
    required this.locationPath,
    required this.currentRound,
    required this.isDynamicStorage,
    required this.status,
    required this.pendingTasksCount,
  });

  factory BlindLocationTaskModel.fromJson(Map<String, dynamic> json) {
    return BlindLocationTaskModel(
      planId: json['planId']?.toString() ?? '',
      planName: json['planName']?.toString() ?? 'Inventário',
      locationId: json['locationId']?.toString() ?? '',
      locationPath: json['locationPath']?.toString() ?? '',
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 1,
      isDynamicStorage: json['isDynamicStorage'] == true,
      status: json['status']?.toString() ?? 'Pending',
      pendingTasksCount: (json['pendingTasksCount'] as num?)?.toInt() ?? 1,
    );
  }
}

class BlindScanEntry {
  final String id;
  final String scannedCode;
  final double quantity;
  final DateTime scannedAt;

  BlindScanEntry({
    required this.id,
    required this.scannedCode,
    required this.quantity,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
    'scannedCode': scannedCode,
    'countedQuantity': quantity,
  };
}
