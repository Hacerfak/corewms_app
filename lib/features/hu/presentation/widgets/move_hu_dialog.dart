import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/scanner/qr_scanner_dialog.dart';
import '../../../../core/scanner/scanner_service.dart';
import '../../../../core/theme/app_theme.dart';
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
          _localError = 'A HU já se encontra nesta posição.';
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
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.corner_up_right,
                    color: Color(0xFF06B6D4),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mover HU',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Transferência física de endereço',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Informativo de Posição Atual e Destino
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.map_pin,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Posição Atual:',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.hu.currentLocationPath,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: context.border, height: 20),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.navigation,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Novo Endereço:',
                        style: TextStyle(
                          color: context.textSecondary,
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
                              : context.textMuted,
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

            // Alerta de Erro
            if (_localError != null || huProvider.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF450A0A)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF991B1B)
                        : const Color(0xFFFECDD3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.circle_alert,
                      size: 16,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _localError ?? huProvider.errorMessage ?? '',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFBE123C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Input do Endereço de Destino
            TextFormField(
              controller: _locationController,
              focusNode: _focusNode,
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: _resolveLocation,
              decoration: InputDecoration(
                labelText: 'Bipe ou digite o Endereço (ex: P1C1BB02)',
                labelStyle: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  LucideIcons.scan,
                  color: Color(0xFF06B6D4),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        LucideIcons.camera,
                        color: isDark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                        size: 18,
                      ),
                      tooltip: 'Escanear via Câmara',
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
                          LucideIcons.arrow_right,
                          color: Color(0xFF06B6D4),
                          size: 18,
                        ),
                        onPressed: () =>
                            _resolveLocation(_locationController.text),
                      ),
                  ],
                ),
                filled: true,
                fillColor: context.cardSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.border),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ações do Modal
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: huProvider.isMoving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: TextStyle(
                        color: context.textSecondary,
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
                      foregroundColor: Colors.white,
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
