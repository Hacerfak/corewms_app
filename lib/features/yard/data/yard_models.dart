class YardAppointmentModel {
  final String id;
  final String reservationCode;
  final int type; // 1 = Inbound, 2 = Outbound
  final String typeDescription;
  final int
  status; // 1 = Scheduled, 2 = InYard, 3 = InDock, 4 = Finished, 5 = Canceled
  final String statusDescription;
  final String? driverName;
  final String? driverCpf;
  final String? vehiclePlate;
  final String? vehiclePlateState;
  final String? carrierName;
  final String? carrierCnpj;
  final DateTime scheduledDate;
  final DateTime? arrivedAt;
  final DateTime? dockedAt;
  final DateTime? departedAt;
  final int? stayMinutes;
  final String? dockLocationId;
  final String? dockName;
  final String? accessKey;
  final String? invoiceNumber;
  final String? invoiceSerie;
  final String? additionalNotes;
  final String? inboundOrderId;
  final String? inboundOrderNumber;
  final String? outboundOrderId;
  final String? outboundOrderNumber;

  YardAppointmentModel({
    required this.id,
    required this.reservationCode,
    required this.type,
    required this.typeDescription,
    required this.status,
    required this.statusDescription,
    this.driverName,
    this.driverCpf,
    this.vehiclePlate,
    this.vehiclePlateState,
    this.carrierName,
    this.carrierCnpj,
    required this.scheduledDate,
    this.arrivedAt,
    this.dockedAt,
    this.departedAt,
    this.stayMinutes,
    this.dockLocationId,
    this.dockName,
    this.accessKey,
    this.invoiceNumber,
    this.invoiceSerie,
    this.additionalNotes,
    this.inboundOrderId,
    this.inboundOrderNumber,
    this.outboundOrderId,
    this.outboundOrderNumber,
  });

  bool get isInbound => type == 1;
  bool get isScheduled => status == 1;
  bool get isInYard => status == 2;
  bool get isInDock => status == 3;
  bool get isFinished => status == 4;
  bool get isCanceled => status == 5;
  bool get hasLinkedOrder =>
      (inboundOrderId != null && inboundOrderId!.isNotEmpty) ||
      (outboundOrderId != null && outboundOrderId!.isNotEmpty);

  static int _parseType(dynamic raw) {
    if (raw is int) return raw;
    final s = raw?.toString().toUpperCase() ?? '';
    return s == 'OUTBOUND' || s == '2' ? 2 : 1;
  }

  static int _parseStatus(dynamic raw) {
    if (raw is int) return raw;
    switch (raw?.toString().toUpperCase() ?? '') {
      case 'SCHEDULED':
      case '1':
        return 1;
      case 'INYARD':
      case '2':
        return 2;
      case 'INDOCK':
      case '3':
        return 3;
      case 'FINISHED':
      case '4':
        return 4;
      case 'CANCELED':
      case '5':
        return 5;
      default:
        return 1;
    }
  }

  factory YardAppointmentModel.fromJson(Map<String, dynamic> json) {
    return YardAppointmentModel(
      id: json['id']?.toString() ?? '',
      reservationCode: json['reservationCode']?.toString() ?? '',
      type: _parseType(json['type']),
      typeDescription:
          json['typeDescription']?.toString() ?? 'Recebimento / Descarga',
      status: _parseStatus(json['status']),
      statusDescription: json['statusDescription']?.toString() ?? 'Agendado',
      driverName: json['driverName']?.toString(),
      driverCpf: json['driverCpf']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString(),
      vehiclePlateState: json['vehiclePlateState']?.toString(),
      carrierName: json['carrierName']?.toString(),
      carrierCnpj: json['carrierCnpj']?.toString(),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      arrivedAt: json['arrivedAt'] != null
          ? DateTime.tryParse(json['arrivedAt'].toString())?.toLocal()
          : null,
      dockedAt: json['dockedAt'] != null
          ? DateTime.tryParse(json['dockedAt'].toString())?.toLocal()
          : null,
      departedAt: json['departedAt'] != null
          ? DateTime.tryParse(json['departedAt'].toString())?.toLocal()
          : null,
      stayMinutes: (json['stayMinutes'] as num?)?.toInt(),
      dockLocationId: json['dockLocationId']?.toString(),
      dockName: json['dockName']?.toString(),
      accessKey: json['accessKey']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceSerie: json['invoiceSerie']?.toString(),
      additionalNotes: json['additionalNotes']?.toString(),
      inboundOrderId: json['inboundOrderId']?.toString(),
      inboundOrderNumber: json['inboundOrderNumber']?.toString(),
      outboundOrderId: json['outboundOrderId']?.toString(),
      outboundOrderNumber: json['outboundOrderNumber']?.toString(),
    );
  }
}

class AvailableOrderLinkItem {
  final String id;
  final String orderNumber;
  final String? invoiceNumber;
  final String? customerOrDestinationName;
  final DateTime issueDate;
  final String status;
  final String? carrierName;
  final String? vehiclePlate;

  AvailableOrderLinkItem({
    required this.id,
    required this.orderNumber,
    this.invoiceNumber,
    this.customerOrDestinationName,
    required this.issueDate,
    required this.status,
    this.carrierName,
    this.vehiclePlate,
  });

  factory AvailableOrderLinkItem.fromJson(Map<String, dynamic> json) {
    return AvailableOrderLinkItem(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString(),
      customerOrDestinationName: json['customerOrDestinationName']?.toString(),
      issueDate: json['issueDate'] != null
          ? DateTime.tryParse(json['issueDate'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      status: json['status']?.toString() ?? '',
      carrierName: json['carrierName']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString(),
    );
  }
}
