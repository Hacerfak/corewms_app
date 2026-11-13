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
  final _codeFocusNode = FocusNode();
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
      // Só processa o gatilho laser se esta tela estiver no topo (ignora enquanto o modal de Qtd estiver aberto)
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;

      if (!_isEmptyLocation) {
        _proceedToQuantityStep(barcode.trim());
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  /// PASSO 1 -> PASSO 2: Valida o código bipado/digitado e abre o modal de quantidade
  Future<void> _proceedToQuantityStep(String rawCode) async {
    final cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      setState(() => _localError = 'Bipe ou digite o LPN da HU ou SKU/EAN.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _codeController.text = cleanCode;
      _localError = null;
    });
    HapticFeedback.lightImpact();

    final qty = await _showQuantityPromptDialog(scannedCode: cleanCode);

    if (!mounted) return;

    if (qty != null && qty > 0) {
      setState(() {
        _entries.insert(
          0,
          BlindScanEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            scannedCode: cleanCode,
            quantity: qty,
            scannedAt: DateTime.now(),
          ),
        );
        _codeController.clear();
        _localError = null;
      });
      HapticFeedback.mediumImpact();
    } else {
      // Se cancelou o modal, limpa o campo para nova leitura
      setState(() {
        _codeController.clear();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isEmptyLocation) {
        _codeFocusNode.requestFocus();
      }
    });
  }

  /// PASSO 2: Modal ergonômico exclusivo para informar a quantidade do código lido
  Future<double?> _showQuantityPromptDialog({
    required String scannedCode,
    double initialQuantity = 1,
    bool isEditing = false,
  }) {
    final initialText = initialQuantity % 1 == 0
        ? initialQuantity.toStringAsFixed(0)
        : initialQuantity.toString();

    final qtyController = TextEditingController(text: initialText)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    String? dialogError;

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void confirmQty() {
              final parsed = double.tryParse(
                qtyController.text.trim().replaceAll(',', '.'),
              );
              if (parsed == null || parsed <= 0) {
                setDialogState(() {
                  dialogError = 'Informe uma quantidade maior que zero.';
                });
                HapticFeedback.heavyImpact();
                return;
              }
              Navigator.of(dialogCtx).pop(parsed);
            }

            return Dialog(
              backgroundColor: context.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                            color: const Color(0xFFEC4899)
                                .withValues(alpha: context.isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.hash,
                            color: Color(0xFFEC4899),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Editar Quantidade'
                                    : 'Passo 2: Quantidade',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Endereço: ${widget.locationTask.locationPath}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Card destacando o Código LPN / SKU bipado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cardSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CÓDIGO IDENTIFICADO (LPN / SKU)',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.barcode,
                                color: Color(0xFFEC4899),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  scannedCode,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Campo Numérico Amplo
                    TextFormField(
                      controller: qtyController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => confirmQty(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantidade Contada *',
                        suffixText: 'UN',
                        suffixStyle: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botões de Ação
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(null),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: confirmQty,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC4899),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: Text(
                              isEditing ? 'ATUALIZAR' : 'ADICIONAR ITEM',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
          },
        );
      },
    );
  }

  Future<void> _handleEditEntry(int index) async {
    final entry = _entries[index];
    final updatedQty = await _showQuantityPromptDialog(
      scannedCode: entry.scannedCode,
      initialQuantity: entry.quantity,
      isEditing: true,
    );

    if (updatedQty != null && updatedQty > 0 && mounted) {
      setState(() {
        _entries[index] = BlindScanEntry(
          id: entry.id,
          scannedCode: entry.scannedCode,
          quantity: updatedQty,
          scannedAt: entry.scannedAt,
        );
      });
      HapticFeedback.lightImpact();
    }
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
                'Endereço Fisicamente Vazio (0 Un)',
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

          // PASSO 1: Leitura Exclusiva do Código (Tela Cheia / Largura Total)
          if (!_isEmptyLocation)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardSubtle,
                border: Border(bottom: BorderSide(color: context.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'PASSO 1',
                          style: TextStyle(
                            color: Color(0xFFEC4899),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bipe ou digite o LPN da HU ou SKU/EAN',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_localError != null || provider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
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
                  ],

                  TextFormField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: _proceedToQuantityStep,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Aguardando bipagem...',
                      prefixIcon: const Icon(
                        LucideIcons.scan_line,
                        color: Color(0xFFEC4899),
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_codeController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                color: context.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _codeController.clear();
                                  _localError = null;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.camera,
                              color: Color(0xFFEC4899),
                              size: 20,
                            ),
                            tooltip: 'Ler via Câmera',
                            onPressed: () async {
                              final code = await QrScannerDialog.scan(
                                context,
                                title: 'Bipar LPN ou SKU',
                              );
                              if (code != null && code.isNotEmpty && mounted) {
                                _proceedToQuantityStep(code);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _proceedToQuantityStep(_codeController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(LucideIcons.arrow_right, size: 18),
                      label: const Text(
                        'INFORMAR QUANTIDADE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Cabeçalho da Lista de Leituras
          if (!_isEmptyLocation && _entries.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(bottom: BorderSide(color: context.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Leituras Registradas (${_entries.length})',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total: ${totalUnits.toStringAsFixed(0)} un',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.eye_off,
                            size: 42,
                            color: context.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma leitura nesta posição ainda.',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bipe um LPN ou SKU acima para informar a quantidade.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final entry = _entries[idx];
                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _handleEditEntry(idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.barcode,
                                  color: Color(0xFFEC4899),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.scannedCode,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Toque para editar quantidade',
                                        style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${entry.quantity.toStringAsFixed(0)} un',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash,
                                    color: Color(0xFFEF4444),
                                    size: 17,
                                  ),
                                  onPressed: () =>
                                      setState(() => _entries.removeAt(idx)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
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
