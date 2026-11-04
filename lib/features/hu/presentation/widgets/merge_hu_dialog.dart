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

class MergeHuDialog extends StatefulWidget {
  final HandlingUnitModel hu;

  const MergeHuDialog({super.key, required this.hu});

  @override
  State<MergeHuDialog> createState() => _MergeHuDialogState();
}

class _MergeHuDialogState extends State<MergeHuDialog> {
  final _destLpnController = TextEditingController();
  final _qtyController = TextEditingController();
  final _focusDest = FocusNode();
  final _formKey = GlobalKey<FormState>();

  StreamSubscription<String>? _scanSubscription;

  HandlingUnitModel? _resolvedDestinationHu;
  bool _isValidatingDest = false;
  String? _localError;
  double _transferQty = 0;

  @override
  void initState() {
    super.initState();

    _transferQty = widget.hu.currentQuantity;
    _qtyController.text = widget.hu.currentQuantity.toStringAsFixed(0);

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _destLpnController.text = barcode.trim();
      _validateDestinationHu(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _destLpnController.dispose();
    _qtyController.dispose();
    _focusDest.dispose();
    super.dispose();
  }

  Future<void> _openCameraScanner() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar HU de Destino',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _destLpnController.text = code;
      _validateDestinationHu(code);
    }
  }

  Future<void> _validateDestinationHu(String lpn) async {
    final cleanLpn = lpn.trim().toUpperCase();
    if (cleanLpn.isEmpty) return;

    if (cleanLpn == widget.hu.lpn.toUpperCase()) {
      setState(() {
        _resolvedDestinationHu = null;
        _localError = 'A HU de destino não pode ser a mesma de origem.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isValidatingDest = true;
      _localError = null;
    });

    try {
      final huProvider = context.read<HuProvider>();
      final destHu = await huProvider.findHuByLpn(cleanLpn);

      if (!mounted) return;

      if (destHu == null) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError = 'HU de destino "$cleanLpn" não encontrada no armazém.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      if (destHu.productId != widget.hu.productId) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError =
              'Incompatibilidade: O produto da HU destino (${destHu.productSku}) difere da origem (${widget.hu.productSku}).';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      if (destHu.inboundOrderId != widget.hu.inboundOrderId) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError = 'Bloqueio Fiscal: A HU de destino pertence a outra Nota Fiscal de Entrada.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      final sourceBatch = widget.hu.batch?.trim().toUpperCase() ?? '';
      final destBatch = destHu.batch?.trim().toUpperCase() ?? '';
      if (sourceBatch != destBatch) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError =
              'Divergência de Lote: Origem ($sourceBatch) vs Destino ($destBatch).';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      if (destHu.qualityStatus != widget.hu.qualityStatus) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError =
              'Qualidade Divergente: A HU de destino está como "${destHu.qualityStatus}".';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      if (!destHu.canPerformActions) {
        setState(() {
          _resolvedDestinationHu = null;
          _isValidatingDest = false;
          _localError =
              'A HU de destino está com estado "${destHu.status}" e não pode receber saldo.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() {
        _resolvedDestinationHu = destHu;
        _isValidatingDest = false;
        _localError = null;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedDestinationHu = null;
        _isValidatingDest = false;
        _localError = e.toString().replaceAll('Exception: ', '');
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _onQtyChanged(String val) {
    final parsed = double.tryParse(val.replaceAll(',', '.')) ?? 0;
    setState(() {
      _transferQty = parsed;
      _localError = null;
    });
  }

  void _setTransferAll() {
    setState(() {
      _transferQty = widget.hu.currentQuantity;
      _qtyController.text = widget.hu.currentQuantity.toStringAsFixed(0);
      _localError = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_resolvedDestinationHu == null) {
      setState(
        () => _localError =
            'Informe e valide a HU de destino antes de confirmar.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    if (_transferQty <= 0) {
      setState(() => _localError = 'A quantidade deve ser superior a zero.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_transferQty > widget.hu.currentQuantity) {
      setState(
        () => _localError =
            'Quantidade solicitada superior ao saldo disponível na origem.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<HuProvider>();
    final result = await provider.executeMerge(
      destinationLpn: _resolvedDestinationHu!.lpn,
      quantity: _transferQty,
    );

    if (!mounted) return;

    if (result != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(result);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HuProvider>();
    final maxAvailable = widget.hu.currentQuantity;
    final remainingSource = maxAvailable - _transferQty;
    final newDestTotal =
        (_resolvedDestinationHu?.currentQuantity ?? 0) + _transferQty;

    final isDark = context.isDark;

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                      color: const Color(0xFF6366F1)
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.merge,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merge de HUs (Agrupamento)',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Consolidar saldo de volumes compatíveis',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card da HU Origem
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HU Origem (Cedente):',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          widget.hu.lpn,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saldo Disponível:',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${widget.hu.currentQuantity.toStringAsFixed(0)} ${widget.hu.productBaseUnit}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lote / Posição:',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${widget.hu.batch ?? "SEM LOTE"} • ${widget.hu.currentLocationPath}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mensagens de Erro
              if (_localError != null || provider.errorMessage != null) ...[
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
                  child: Text(
                    _localError ?? provider.errorMessage ?? '',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFBE123C),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Campo para bipar a HU de Destino
              TextFormField(
                controller: _destLpnController,
                focusNode: _focusDest,
                style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: _validateDestinationHu,
                decoration: InputDecoration(
                  labelText: 'Bipar ou digitar a HU Destino',
                  labelStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.scan,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          LucideIcons.camera,
                          color: context.isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                          size: 18,
                        ),
                        tooltip: 'Escanear via Câmara',
                        onPressed: _openCameraScanner,
                      ),
                      if (_isValidatingDest)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            LucideIcons.arrow_right,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                          onPressed: () =>
                              _validateDestinationHu(_destLpnController.text),
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
              const SizedBox(height: 12),

              // Card da HU Destino Validada
              if (_resolvedDestinationHu != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B)
                        .withValues(alpha: isDark ? 0.3 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF059669)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.circle_check,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Destino: ${_resolvedDestinationHu!.lpn}',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Saldo Atual: ${_resolvedDestinationHu!.currentQuantity.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Endereço: ${_resolvedDestinationHu!.currentLocationPath}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Campo de Quantidade
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      onChanged: _onQtyChanged,
                      decoration: InputDecoration(
                        labelText: 'Qtd a Transferir',
                        labelStyle: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                        suffixText: widget.hu.productBaseUnit,
                        suffixStyle: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o valor';
                        }
                        final val = double.tryParse(v.replaceAll(',', '.'));
                        if (val == null || val <= 0) return 'Inválido';
                        if (val > maxAvailable) {
                          return 'Máx: ${maxAvailable.toStringAsFixed(0)}';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _setTransferAll,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.infinity,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                          Text(
                            'TUDO',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Balanço Visual de Movimentação
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sobra na Origem:',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${remainingSource.toStringAsFixed(0)} ${widget.hu.productBaseUnit}',
                          style: TextStyle(
                            color: remainingSource == 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (remainingSource == 0) ...[
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.info,
                            size: 12,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'A HU de origem será consumida/baixada.',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_resolvedDestinationHu != null) ...[
                      Divider(color: context.border, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Novo Saldo no Destino:',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${newDestTotal.toStringAsFixed(0)} ${widget.hu.productBaseUnit}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.isMerging
                          ? null
                          : () => Navigator.of(context).pop(),
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
                          (provider.isMerging || _resolvedDestinationHu == null)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: provider.isMerging
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CONFIRMAR MERGE',
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
      ),
    );
  }
}
