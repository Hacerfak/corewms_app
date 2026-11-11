import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/picking_models.dart';
import 'location_products_screen.dart';
import 'picking_provider.dart';

class OrderPickingScreen extends StatefulWidget {
  final String orderId;

  const OrderPickingScreen({super.key, required this.orderId});

  @override
  State<OrderPickingScreen> createState() => _OrderPickingScreenState();
}

class _OrderPickingScreenState extends State<OrderPickingScreen> {
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PickingProvider>().loadSingleOrderTasks(widget.orderId);
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;

      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;

      _handleScannedBarcode(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _handleScannedBarcode(String barcode) {
    if (barcode.isEmpty) return;
    HapticFeedback.lightImpact();

    final provider = context.read<PickingProvider>();
    final groups = provider.currentOrderGroupsByLocation;

    final matchingGroup = groups.firstWhere(
      (g) => g.locationPath.toUpperCase() == barcode.toUpperCase(),
      orElse: () => LocationPickingGroup(locationPath: '', tasks: []),
    );

    if (matchingGroup.locationPath.isNotEmpty) {
      _openLocation(matchingGroup.locationPath);
      return;
    }

    for (final g in groups) {
      final hasHu = g.tasks.any(
        (t) => t.lpn.toUpperCase() == barcode.toUpperCase(),
      );
      if (hasHu) {
        _openLocation(g.locationPath);
        return;
      }
    }
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Endereço ou HU',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleScannedBarcode(code);
    }
  }

  Future<void> _openLocation(String locationPath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationProductsScreen(
          locationPath: locationPath,
          specificOrderId: widget.orderId,
        ),
      ),
    );

    if (mounted) {
      context.read<PickingProvider>().loadSingleOrderTasks(widget.orderId);
    }
  }

  Future<void> _handleResetOrder() async {
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
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Reiniciar Separação?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Deseja estornar todos os itens separados neste pedido? Ele voltará para o estado inicial (Alocado) e todas as HUs serão liberadas.',
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
              'REINICIAR TUDO',
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
      final success = await context.read<PickingProvider>().resetOrderPicking(
        widget.orderId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Separação do pedido reiniciada com sucesso!'),
          ),
        );
      }
    }
  }

  Future<void> _handleFinalizeOrder() async {
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
              'Finalizar Separação?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Confirma a finalização física de todos os itens deste pedido? A carga avançará para a próxima etapa.',
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
              'CONFIRMAR FINALIZAÇÃO',
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
      final success = await context.read<PickingProvider>().finalizePicking(
        widget.orderId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Separação concluída com sucesso!'),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickingProvider>();
    final summary = provider.currentOrderSummary;
    final groups = provider.currentOrderGroupsByLocation;

    final allOrderTasks = groups.expand((g) => g.tasks).toList();
    final totalExpected = allOrderTasks.fold(0.0, (s, t) => s + t.quantity);
    final totalPicked = allOrderTasks
        .where((t) => t.isPicked)
        .fold(0.0, (s, t) => s + t.quantity);
    final is100Percent = totalExpected > 0 && totalPicked >= totalExpected;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary != null
                  ? 'Pedido #${summary.orderNumber}'
                  : 'Separação do Pedido',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (summary != null)
              Text(
                '${summary.customerName} ${summary.destinationName != null ? "• ${summary.destinationName}" : ""}',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.camera, size: 20),
            tooltip: 'Escanear Endereço',
            onPressed: _openCamera,
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.rotate_ccw,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            tooltip: 'Reiniciar Separação da Ordem',
            onPressed: _handleResetOrder,
          ),
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () => context
                .read<PickingProvider>()
                .loadSingleOrderTasks(widget.orderId),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    border: Border(bottom: BorderSide(color: context.border)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            is100Percent
                                ? 'METAS ATINGIDAS (PRONTO PARA FINALIZAR)'
                                : 'Progresso do Pedido:',
                            style: TextStyle(
                              color: is100Percent
                                  ? const Color(0xFF10B981)
                                  : context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${totalPicked.toStringAsFixed(0)} / ${totalExpected.toStringAsFixed(0)} un',
                            style: TextStyle(
                              color: is100Percent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalExpected > 0
                              ? (totalPicked / totalExpected)
                              : 0,
                          backgroundColor: context.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            is100Percent
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final group = groups[idx];
                      final isGroupDone = group.pendingTasksCount == 0;
                      final distinctSkus = group.tasks
                          .map((t) => t.skuCode)
                          .toSet();

                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openLocation(group.locationPath),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isGroupDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                width: isGroupDone ? 1 : 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          LucideIcons.map_pin,
                                          size: 18,
                                          color: isGroupDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          group.locationPath,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isGroupDone
                                            ? const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15)
                                            : const Color(0xFFF59E0B)
                                                  .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isGroupDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                      child: Text(
                                        isGroupDone
                                            ? 'Concluído'
                                            : '${group.pendingTasksCount} pendente(s)',
                                        style: TextStyle(
                                          color: isGroupDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFD97706),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Produtos: ${distinctSkus.join(", ")}',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isGroupDone
                                      ? 'Itens recolhidos. Toque para revisar.'
                                      : 'Pendente: ${group.totalPendingQuantity.toStringAsFixed(0)} un',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                  ),
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

      // BOTÃO DE FINALIZAÇÃO EXPLÍCITA
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
              onPressed: is100Percent ? _handleFinalizeOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.circle_check, size: 18),
              label: Text(
                is100Percent
                    ? 'FINALIZAR SEPARAÇÃO DO PEDIDO'
                    : 'SEPARE TODOS OS ITENS ANTES DE FINALIZAR',
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
