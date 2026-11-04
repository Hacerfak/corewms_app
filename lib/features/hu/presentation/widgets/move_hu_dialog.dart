import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/scanner/qr_scanner_dialog.dart';
import '../../../../core/scanner/scanner_service.dart';
import '../../data/hu_models.dart';
import '../hu_provider.dart';

class MoveHuDialog extends StatefulWidget {
  final HandlingUnitModel hu;

  const MoveHuDialog({super.key, required this.hu});

  @override
  State<MoveHuDialog> createState() => _MoveHuDialogState();
}

class _MoveHuDialogState extends State<MoveHuDialog> {
  final _locationController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<String>? _scanSubscription;

  LocationModel? _resolvedDestination;
  bool _isResolvingLocation = false;
  String? _localError;

  @override
  void initState() {
    super.initState();

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _locationController.text = barcode.trim();
      _resolveLocation(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _locationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openCameraScanner() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar QR Code da Posição',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _locationController.text = code;
      _resolveLocation(code);
    }
  }

  Future<void> _resolveLocation(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    setState(() {
      _isResolvingLocation = true;
      _localError = null;
    });

    try {
      final huProvider = context.read<HuProvider>();
      final location = await huProvider.findLocation(cleanCode);

      if (!mounted) return;

      if (location == null) {
        setState(() {
          _resolvedDestination = null;
          _isResolvingLocation = false;
          _localError = 'Endereço "$cleanCode" não cadastrado na Topologia.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      if (location.id == widget.hu.currentLocationId ||
          location.fullPath.toUpperCase() ==
              widget.hu.currentLocationPath.toUpperCase()) {
        setState(() {
          _resolvedDestination = null;
          _isResolvingLocation = false;
          _localError = 'A HU já está nesta posição.';
        });
        HapticFeedback.vibrate();
        return;
      }

      setState(() {
        _resolvedDestination = location;
        _isResolvingLocation = false;
        _localError = null;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedDestination = null;
        _isResolvingLocation = false;
        _localError = e.toString().replaceAll('Exception: ', '');
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _confirmTransfer() async {
    if (_resolvedDestination == null) return;

    final success = await context.read<HuProvider>().executeMove(
      targetLocationId: _resolvedDestination!.id,
      targetLocationPath: _resolvedDestination!.fullPath,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final huProvider = context.watch<HuProvider>();

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.drive_file_move_outline,
                    color: Color(0xFF06B6D4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mover HU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Transferência física de endereço',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Posição Atual:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.hu.currentLocationPath,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Novo Endereço:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _resolvedDestination != null
                            ? _resolvedDestination!.fullPath
                            : 'Aguardando bip...',
                        style: TextStyle(
                          color: _resolvedDestination != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_localError != null || huProvider.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF991B1B)),
                ),
                child: Text(
                  _localError ?? huProvider.errorMessage ?? '',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              controller: _locationController,
              focusNode: _focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: _resolveLocation,
              decoration: InputDecoration(
                labelText: 'Bipe ou digite o Endereço (ex: P1C1BB02)',
                labelStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  LucideIcons.scan_barcode,
                  color: Color(0xFF06B6D4),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.photo_camera_rounded,
                        color: Color(0xFF60A5FA),
                        size: 20,
                      ),
                      tooltip: 'Escanear via Câmera',
                      onPressed: _openCameraScanner,
                    ),
                    if (_isResolvingLocation)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF06B6D4),
                        ),
                        onPressed: () =>
                            _resolveLocation(_locationController.text),
                      ),
                  ],
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: huProvider.isMoving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        (_resolvedDestination == null || huProvider.isMoving)
                        ? null
                        : _confirmTransfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: huProvider.isMoving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'CONFIRMAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
