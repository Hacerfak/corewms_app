import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerDialog extends StatefulWidget {
  final String title;

  const QrScannerDialog({
    super.key,
    this.title = 'Aponte para o QR Code / Código',
  });

  static Future<String?> scan(BuildContext context, {String? title}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          QrScannerDialog(title: title ?? 'Aponte para o QR Code / Código'),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              // Cabeçalho
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Área da Câmera com Mira
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        if (_isScanned) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          final value = barcode.rawValue?.trim();
                          if (value != null && value.isNotEmpty) {
                            _isScanned = true;
                            Navigator.of(context).pop(value);
                            break;
                          }
                        }
                      },
                    ),

                    // Mira visual
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),

              // Rodapé com controle de Lanterna
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: const Color(0xFF0F172A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.amber,
                      ),
                      onPressed: () => _controller.toggleTorch(),
                      tooltip: 'Ligar/Desligar Lanterna',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
