import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/cycle_count_models.dart';
import 'cycle_count_provider.dart';

class BlindLocationCountScreen extends StatefulWidget {
  final BlindLocationTaskModel locationTask;

  const BlindLocationCountScreen({super.key, required this.locationTask});

  @override
  State<BlindLocationCountScreen> createState() =>
      _BlindLocationCountScreenState();
}

class _BlindLocationCountScreenState extends State<BlindLocationCountScreen> {
  final _codeController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final List<BlindScanEntry> _entries = [];
  bool _isEmptyLocation = false;
  String? _localError;
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      if (!_isEmptyLocation) {
        setState(() {
          _codeController.text = barcode.trim().toUpperCase();
          _localError = null;
        });
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _codeController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _addEntry() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _localError = 'Bipe ou digite o LPN da HU ou SKU/EAN.');
      HapticFeedback.heavyImpact();
      return;
    }

    final qty =
        double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      setState(() => _localError = 'A quantidade deve ser maior que zero.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _entries.insert(
        0,
        BlindScanEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          scannedCode: code,
          quantity: qty,
          scannedAt: DateTime.now(),
        ),
      );
      _codeController.clear();
      _qtyController.text = '1';
      _localError = null;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _handleCancelCounting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.rotate_ccw,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Cancelar Contagem?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Deseja abandonar a contagem de ${widget.locationTask.locationPath} e devolvê-la para a fila?',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('VOLTAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'LIBERAR POSIÇÃO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<CycleCountProvider>().cancelCounting(
        widget.locationTask.planId,
        widget.locationTask.locationId,
      );
      if (ok && mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _handleFinalize() async {
    if (!_isEmptyLocation && _entries.isEmpty) {
      setState(
        () => _localError =
            'Bipe ao menos um item/LPN ou marque a opção "Posição Vazia".',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.circle_check,
              color: Color(0xFF10B981),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Finalizar Posição?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          _isEmptyLocation
              ? 'Confirma que o endereço ${widget.locationTask.locationPath} está fisicamente VAZIO (0 unidades)?'
              : 'Confirma o envio de ${_entries.length} leitura(s) cega(s) para revisão da Gestão?',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('REVISAR MAIS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text(
              'CONFIRMAR CONTAGEM',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<CycleCountProvider>();
      final ok = await provider.submitBlindCount(
        planId: widget.locationTask.planId,
        locationId: widget.locationTask.locationId,
        isEmptyLocation: _isEmptyLocation,
        entries: _isEmptyLocation ? [] : _entries,
      );

      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text(
              'Contagem registrada! Enviada para análise da Gestão.',
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CycleCountProvider>();
    final totalUnits = _entries.fold(0.0, (s, e) => s + e.quantity);
    final canFinalize = _isEmptyLocation || _entries.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.map_pin,
                  color: Color(0xFFEC4899),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.locationTask.locationPath,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Text(
              'Contagem Cega • Rodada ${widget.locationTask.currentRound}',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.rotate_ccw,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            tooltip: 'Cancelar e Liberar Posição',
            onPressed: _handleCancelCounting,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Auditoria Cega
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFEC4899).withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.eye_off,
                  color: Color(0xFFEC4899),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo Cego Ativo: Bipe todas as HUs (LPN) ou SKUs encontrados fisicamente neste endereço.',
                    style: TextStyle(
                      color: context.isDark
                          ? const Color(0xFFF9A8D4)
                          : const Color(0xFF9D174D),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Opção de Posição Vazia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFFEC4899),
              title: Text(
                'Endereço Fisicamente Vazio (0 Unidades)',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Ative se não houver nenhum volume nesta posição',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
              value: _isEmptyLocation,
              onChanged: (val) {
                setState(() {
                  _isEmptyLocation = val;
                  if (val) _entries.clear();
                  _localError = null;
                });
              },
            ),
          ),

          // Formulário de Bipagem (quando não é posição vazia)
          if (!_isEmptyLocation)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardSubtle,
                border: Border(bottom: BorderSide(color: context.border)),
              ),
              child: Column(
                children: [
                  if (_localError != null || provider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _localError ?? provider.errorMessage ?? '',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _codeController,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: 'LPN da HU ou SKU/EAN',
                            prefixIcon: const Icon(
                              LucideIcons.scan,
                              color: Color(0xFFEC4899),
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                LucideIcons.camera,
                                color: Color(0xFFEC4899),
                                size: 18,
                              ),
                              onPressed: () async {
                                final code = await QrScannerDialog.scan(
                                  context,
                                  title: 'Bipar LPN ou SKU',
                                );
                                if (code != null && code.isNotEmpty) {
                                  setState(
                                    () => _codeController.text = code
                                        .toUpperCase(),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(labelText: 'Qtd'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _addEntry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(LucideIcons.plus, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Lista de Leituras Realizadas
          Expanded(
            child: _isEmptyLocation
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.circle_check,
                          size: 52,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Posição Marcada como Vazia',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toque no botão abaixo para confirmar 0 unidades.',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : _entries.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma leitura registrada nesta posição ainda.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final entry = _entries[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.barcode,
                                  color: Color(0xFFEC4899),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.scannedCode,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  '${entry.quantity.toStringAsFixed(0)} un',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash,
                                    color: Color(0xFFEF4444),
                                    size: 16,
                                  ),
                                  onPressed: () =>
                                      setState(() => _entries.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          border: Border(top: BorderSide(color: context.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (canFinalize && !provider.isSubmitting)
                  ? _handleFinalize
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: provider.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(LucideIcons.circle_check, size: 18),
              label: Text(
                _isEmptyLocation
                    ? 'CONFIRMAR POSIÇÃO VAZIA (0 UN)'
                    : 'FINALIZAR CONTAGEM (${totalUnits.toStringAsFixed(0)} UN)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
