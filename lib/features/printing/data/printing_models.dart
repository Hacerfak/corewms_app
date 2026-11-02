/// Impressora térmica cadastrada na estação
class PrinterModel {
  final String id;
  final String name;
  final String target;
  final bool isActive;

  PrinterModel({
    required this.id,
    required this.name,
    required this.target,
    required this.isActive,
  });

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    return PrinterModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      isActive: json['isActive'] != false,
    );
  }
}

/// Agente de Impressão (Serviço local / WebSocket)
class PrintAgentModel {
  final String id;
  final String name;
  final String apiKey;
  final bool isActive;
  final bool isOnline;
  final List<PrinterModel> printers;

  PrintAgentModel({
    required this.id,
    required this.name,
    required this.apiKey,
    required this.isActive,
    required this.isOnline,
    required this.printers,
  });

  factory PrintAgentModel.fromJson(Map<String, dynamic> json) {
    final rawPrinters = json['printers'] as List<dynamic>? ?? [];
    return PrintAgentModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      isActive: json['isActive'] != false,
      isOnline: json['isOnline'] == true,
      printers: rawPrinters
          .whereType<Map<String, dynamic>>()
          .map((p) => PrinterModel.fromJson(p))
          .where((p) => p.isActive)
          .toList(),
    );
  }
}

/// Modelo de Etiqueta ZPL cadastrado no sistema
class LabelTemplateModel {
  final String id;
  final String name;
  final String? zplContent;
  final int widthMm;
  final int heightMm;
  final bool isActive;

  LabelTemplateModel({
    required this.id,
    required this.name,
    this.zplContent,
    required this.widthMm,
    required this.heightMm,
    required this.isActive,
  });

  factory LabelTemplateModel.fromJson(Map<String, dynamic> json) {
    return LabelTemplateModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      zplContent: json['zplContent']?.toString(),
      widthMm: (json['widthMm'] as num?)?.toInt() ?? 100,
      heightMm: (json['heightMm'] as num?)?.toInt() ?? 50,
      isActive: json['isActive'] != false,
    );
  }
}
