import 'dart:async';

import 'package:flutter/services.dart';

class ScannerService {
  static const EventChannel _eventChannel = EventChannel('corewms/scanner');
  StreamSubscription? _subscription;

  final _barcodeController = StreamController<String>.broadcast();
  Stream<String> get onScan => _barcodeController.stream;

  void initialize() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event != null && event is String) {
          _barcodeController.add(event.trim());
        }
      },
      onError: (dynamic error) {
        // Ignora ou trata eventuais quedas de stream do driver
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _barcodeController.close();
  }
}
