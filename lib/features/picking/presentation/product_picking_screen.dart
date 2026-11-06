import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/picking_models.dart';
import 'picking_provider.dart';

class ProductPickingScreen extends StatefulWidget {
  final String locationPath;
  final String orderId;
  final String orderItemId;
  final String productId;
  final String skuCode;
  final String description;
  final String baseUnit;
  final String? specificOrderId;

  const ProductPickingScreen({
    super.key,
    required this.locationPath,
    required this.orderId,
    required this.orderItemId,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.baseUnit,
    this.specificOrderId,
  });

  @override
  State<ProductPickingScreen> createState() => _ProductPickingScreenState();
}

class _ProductPickingScreenState extends State<ProductPickingScreen> {
  final _lpnController = TextEditingController();
  final _qtyController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<String>? _scanSubscription;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupInitialQty();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;

      // Trava de contexto da tela ativa
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;

      _handleScannedLpn(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _lpnController.dispose();
    _qtyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupInitialQty() {
    final pending = _getPendingSuggestions();
    if (pending.isNotEmpty) {
      _qtyController.text = pending.first.quantity.toStringAsFixed(0);
    } else {
      _qtyController.text = '1';
    }
  }

  /// Recupera as sugestões pendentes deste produto
  List<PickingAllocatedHuModel> _getPendingSuggestions() {
    final provider = context.read<PickingProvider>();

    if (provider.currentOrderSummary != null) {
      final item = provider.currentOrderSummary!.items.firstWhere(
        (i) =>
            i.orderItemId == widget.orderItemId ||
            i.productId == widget.productId,
        orElse: () => PickingItemTaskModel(
          orderItemId: widget.orderItemId,
          productId: widget.productId,
          skuCode: widget.skuCode,
          description: widget.description,
          baseUnit: widget.baseUnit,
          expectedQuantity: 0,
          allocatedQuantity: 0,
          pickedQuantity: 0,
          status: '',
          allocations: [],
        ),
      );
      return item.allocations.where((a) => !a.isPicked).toList();
    }

    return provider.allTasks
        .where((t) => t.productId == widget.productId && !t.isPicked)
        .map(
          (t) => PickingAllocatedHuModel(
            allocationId: t.allocationId,
            handlingUnitId: t.handlingUnitId,
            lpn: t.lpn,
            locationPath: t.locationPath,
            packagingCode: t.packagingCode,
            batch: t.batch,
            expirationDate: t.expirationDate,
            quantity: t.quantity,
            isPicked: false,
          ),
        )
        .toList();
  }

  /// Recupera TODAS as HUs BIPADAS / CONFIRMADAS deste produto
  /// Busca por produto e item, permitindo HUs de blocado flexível
  List<PickingAllocatedHuModel> _getPickedHus() {
    final provider = context.read<PickingProvider>();

    if (provider.currentOrderSummary != null) {
      final item = provider.currentOrderSummary!.items.firstWhere(
        (i) =>
            i.orderItemId == widget.orderItemId ||
            i.productId == widget.productId,
        orElse: () => PickingItemTaskModel(
          orderItemId: widget.orderItemId,
          productId: widget.productId,
          skuCode: widget.skuCode,
          description: widget.description,
          baseUnit: widget.baseUnit,
          expectedQuantity: 0,
          allocatedQuantity: 0,
          pickedQuantity: 0,
          status: '',
          allocations: [],
        ),
      );
      return item.allocations.where((a) => a.isPicked).toList();
    }

    return provider.allTasks
        .where((t) => t.productId == widget.productId && t.isPicked)
        .map(
          (t) => PickingAllocatedHuModel(
            allocationId: t.allocationId,
            handlingUnitId: t.handlingUnitId,
            lpn: t.lpn,
            locationPath: t.locationPath,
            packagingCode: t.packagingCode,
            batch: t.batch,
            expirationDate: t.expirationDate,
            quantity: t.quantity,
            isPicked: true,
          ),
        )
        .toList();
  }

  double _getTotalExpected() {
    final provider = context.read<PickingProvider>();
    if (provider.currentOrderSummary != null) {
      final item = provider.currentOrderSummary!.items.firstWhere(
        (i) =>
            i.orderItemId == widget.orderItemId ||
            i.productId == widget.productId,
        orElse: () => PickingItemTaskModel(
          orderItemId: widget.orderItemId,
          productId: widget.productId,
          skuCode: widget.skuCode,
          description: widget.description,
          baseUnit: widget.baseUnit,
          expectedQuantity: 0,
          allocatedQuantity: 0,
          pickedQuantity: 0,
          status: '',
          allocations: [],
        ),
      );
      return item.expectedQuantity;
    }
    return provider.allTasks
        .where((t) => t.productId == widget.productId)
        .fold(0.0, (s, t) => s + t.quantity);
  }

  /// Ao bipar com o leitor laser do Movfast, apenas preenche o campo
  void _handleScannedLpn(String lpn) {
    if (lpn.isEmpty) return;
    HapticFeedback.lightImpact();

    setState(() {
      _lpnController.text = lpn;
      _localError = null;
    });

    final pending = _getPendingSuggestions();
    final matchingSug = pending.firstWhere(
      (s) => s.lpn.toUpperCase() == lpn.toUpperCase(),
      orElse: () => pending.isNotEmpty ? pending.first : pending.first,
    );

    if (_qtyController.text.isEmpty || _qtyController.text == '0') {
      _qtyController.text = matchingSug.quantity.toStringAsFixed(0);
    }
  }

  Future<void> _submitPick() async {
    final lpn = _lpnController.text.trim();
    if (lpn.isEmpty) {
      setState(() => _localError = 'Bipe ou digite o LPN da HU.');
      HapticFeedback.heavyImpact();
      return;
    }

    final qty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) {
      setState(() => _localError = 'A quantidade deve ser maior que zero.');
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<PickingProvider>();

    final result = await provider.executePick(
      orderId: widget.orderId,
      orderItemId: widget.orderItemId,
      scannedLpn: lpn,
      pickedQuantity: qty,
    );

    if (!mounted) return;

    if (result != null) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'HU $lpn ($qty ${widget.baseUnit}) recolhida com sucesso!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _lpnController.clear();
        _localError = null;
      });

      _setupInitialQty();
    } else {
      HapticFeedback.heavyImpact();
      setState(
        () => _localError = provider.errorMessage ?? 'Erro na separação.',
      );
    }
  }

  Future<void> _handleUndo(PickingAllocatedHuModel task) async {
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
              'Estornar HU?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Deseja cancelar a separação da HU ${task.lpn} (${task.quantity.toStringAsFixed(0)} ${widget.baseUnit}) e devolver para as sugestões?',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'ESTORNAR',
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
      final success = await context.read<PickingProvider>().undoPick(
        orderId: widget.orderId,
        allocationId: task.allocationId,
      );

      if (success && mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('HU ${task.lpn} estornada com sucesso!'),
          ),
        );
        _setupInitialQty();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickingProvider>();
    final pendingSuggestions = _getPendingSuggestions();
    final pickedHus = _getPickedHus();

    final totalExpected = _getTotalExpected();
    final totalPicked = pickedHus.fold(0.0, (s, t) => s + t.quantity);
    final isDone = totalExpected > 0 && totalPicked >= totalExpected;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.skuCode} • ${widget.locationPath}',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              widget.description,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () {
              if (widget.specificOrderId != null) {
                provider.loadSingleOrderTasks(widget.specificOrderId!);
              } else {
                provider.loadAllData();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BARRA DE PROGRESSO DO PRODUTO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : context.cardSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDone ? const Color(0xFF10B981) : context.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDone ? 'PRODUTO 100% SEPARADO' : 'Progresso da Coleta:',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${totalPicked.toStringAsFixed(0)} / ${totalExpected.toStringAsFixed(0)} ${widget.baseUnit}',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // FORMULÁRIO DE LEITURA (NO TOPO)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isDone
                        ? 'Separação Concluída (Meta Atingida)'
                        : 'Bipar HU do Produto (Blocado Flexível):',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

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
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _lpnController,
                          focusNode: _focusNode,
                          enabled: !isDone,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            labelText: isDone
                                ? 'Meta 100% atingida'
                                : 'LPN da HU',
                            prefixIcon: const Icon(
                              LucideIcons.scan,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                LucideIcons.camera,
                                color: Color(0xFFF59E0B),
                                size: 18,
                              ),
                              onPressed: isDone
                                  ? null
                                  : () async {
                                      final code = await QrScannerDialog.scan(
                                        context,
                                        title: 'Bipar HU',
                                      );
                                      if (code != null && code.isNotEmpty) {
                                        _handleScannedLpn(code);
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _qtyController,
                          enabled: !isDone,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Qtd',
                            suffixText: widget.baseUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (provider.isPicking || isDone)
                          ? null
                          : _submitPick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: provider.isPicking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(LucideIcons.package_check, size: 18),
                      label: const Text(
                        'CONFIRMAR SEPARAÇÃO',
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
            const SizedBox(height: 18),

            // LISTA DINÂMICA: CONFIRMADAS (BIPADAS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HUs Bipadas / Confirmadas (${pickedHus.length}):',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${totalPicked.toStringAsFixed(0)} ${widget.baseUnit}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (pickedHus.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.border),
                ),
                child: Center(
                  child: Text(
                    'Nenhuma HU bipada ainda.',
                    style: TextStyle(color: context.textMuted, fontSize: 11),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pickedHus.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final picked = pickedHus[idx];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981)
                          .withValues(alpha: context.isDark ? 0.12 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.circle_check,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  picked.lpn,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Lote: ${picked.batch ?? "SEM LOTE"}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${picked.quantity.toStringAsFixed(0)} ${widget.baseUnit}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.rotate_ccw,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              tooltip: 'Estornar esta HU',
                              onPressed: () => _handleUndo(picked),
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

            const SizedBox(height: 18),

            // LISTA DINÂMICA: SUGERIDAS (PENDENTES)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HUs Sugeridas / Pendentes (${pendingSuggestions.length}):',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Falta: ${(totalExpected - totalPicked).clamp(0.0, totalExpected).toStringAsFixed(0)} ${widget.baseUnit}',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (pendingSuggestions.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      LucideIcons.circle_check,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Todas as sugestões foram atendidas!',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingSuggestions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final sug = pendingSuggestions[idx];
                  return Material(
                    color: context.cardSubtle,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _lpnController.text = sug.lpn;
                          _qtyController.text = sug.quantity.toStringAsFixed(0);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.sparkles,
                                      size: 14,
                                      color: Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sug.lpn,
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Lote: ${sug.batch ?? "SEM LOTE"} • Toque para preencher',
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${sug.quantity.toStringAsFixed(0)} ${widget.baseUnit}',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // Botão para retornar à lista de produtos da posição
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(LucideIcons.arrow_left, size: 16),
                label: const Text(
                  'VOLTAR AOS PRODUTOS DO ENDEREÇO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
