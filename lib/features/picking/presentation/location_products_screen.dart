import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/picking_models.dart';
import 'picking_provider.dart';
import 'product_picking_screen.dart';

class LocationProductsScreen extends StatefulWidget {
  final String locationPath;
  final String? specificOrderId;

  const LocationProductsScreen({
    super.key,
    required this.locationPath,
    this.specificOrderId,
  });

  @override
  State<LocationProductsScreen> createState() => _LocationProductsScreenState();
}

class _LocationProductsScreenState extends State<LocationProductsScreen> {
  // Guarda os IDs de produtos identificados nesta posição
  final Set<String> _locationProductIds = {};

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    final provider = context.read<PickingProvider>();
    if (widget.specificOrderId != null) {
      provider.loadSingleOrderTasks(widget.specificOrderId!);
    } else {
      provider.loadAllData();
    }
  }

  List<_ProductGroupSummary> _getProductGroups(PickingProvider provider) {
    // 1. Identifica tarefas pendentes no endereço
    final List<ConsolidatedPickingTask> locationTasks;

    if (widget.specificOrderId != null &&
        provider.currentOrderSummary?.orderId == widget.specificOrderId) {
      final groups = provider.currentOrderGroupsByLocation;
      final match = groups.firstWhere(
        (g) =>
            g.locationPath.toUpperCase() == widget.locationPath.toUpperCase(),
        orElse: () =>
            LocationPickingGroup(locationPath: widget.locationPath, tasks: []),
      );
      locationTasks = match.tasks;
    } else {
      locationTasks = provider.allTasks
          .where(
            (t) =>
                t.locationPath.toUpperCase() ==
                    widget.locationPath.toUpperCase() &&
                (widget.specificOrderId == null ||
                    t.orderId == widget.specificOrderId),
          )
          .toList();
    }

    for (final t in locationTasks) {
      _locationProductIds.add(t.productId);
    }

    // 2. Localiza os itens das ordens vinculadas a estes produtos
    final List<_ProductGroupSummary> summaries = [];

    if (widget.specificOrderId != null &&
        provider.currentOrderSummary != null) {
      for (final item in provider.currentOrderSummary!.items) {
        if (!_locationProductIds.contains(item.productId)) continue;

        final picked = item.allocations
            .where((a) => a.isPicked)
            .fold(0.0, (s, a) => s + a.quantity);
        final firstAlloc = item.allocations.isNotEmpty
            ? item.allocations.first
            : null;

        summaries.add(
          _ProductGroupSummary(
            orderId: provider.currentOrderSummary!.orderId,
            orderItemId: item.orderItemId,
            productId: item.productId,
            skuCode: item.skuCode,
            description: item.description,
            baseUnit: item.baseUnit,
            totalExpected: item.expectedQuantity,
            totalPicked: picked,
            firstAllocationId: firstAlloc?.allocationId,
          ),
        );
      }
    } else {
      // Visão consolidada por onda de endereço
      final Map<String, List<ConsolidatedPickingTask>> grouped = {};
      for (final t in provider.allTasks) {
        if (_locationProductIds.contains(t.productId)) {
          grouped.putIfAbsent(t.productId, () => []).add(t);
        }
      }

      for (final entry in grouped.entries) {
        final tasks = entry.value;
        final first = tasks.first;
        final expected = tasks.fold(0.0, (s, t) => s + t.quantity);
        final picked = tasks
            .where((t) => t.isPicked)
            .fold(0.0, (s, t) => s + t.quantity);

        summaries.add(
          _ProductGroupSummary(
            orderId: first.orderId,
            orderItemId: first.orderItemId,
            productId: entry.key,
            skuCode: first.skuCode,
            description: first.description,
            baseUnit: first.baseUnit,
            totalExpected: expected,
            totalPicked: picked,
            firstAllocationId: first.allocationId,
          ),
        );
      }
    }

    return summaries;
  }

  Future<void> _openProductExecution(_ProductGroupSummary product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductPickingScreen(
          locationPath: widget.locationPath,
          orderId: product.orderId,
          orderItemId: product.orderItemId,
          productId: product.productId,
          skuCode: product.skuCode,
          description: product.description,
          baseUnit: product.baseUnit,
          specificOrderId: widget.specificOrderId,
        ),
      ),
    );

    if (!mounted) return;
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickingProvider>();
    final productGroups = _getProductGroups(provider);
    final pendingCount = productGroups.where((g) => !g.isDone).length;
    final isLocationDone = productGroups.isNotEmpty && pendingCount == 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.map_pin,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.locationPath,
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
              isLocationDone
                  ? 'Posição 100% separada'
                  : '$pendingCount produto(s) pendente(s)',
              style: TextStyle(
                color: isLocationDone
                    ? const Color(0xFF10B981)
                    : context.textSecondary,
                fontSize: 11,
                fontWeight: isLocationDone
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : productGroups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.circle_check,
                      size: 56,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Endereço Concluído!',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Todos os produtos desta posição já foram separados.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Aviso de endereço concluído com opção de revisão
                if (isLocationDone)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.circle_check,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Posição 100% recolhida. Toque em qualquer item para revisar ou estornar.',
                            style: TextStyle(
                              color: context.isDark
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFF065F46),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: productGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = productGroups[idx];
                      final isDone = item.isDone;

                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          // SEMPRE CLICÁVEL: Permite revisar ou estornar mesmo que concluído
                          onTap: () => _openProductExecution(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                width: isDone ? 1 : 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.skuCode,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 15,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15)
                                            : const Color(0xFFF59E0B)
                                                  .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                      child: Text(
                                        isDone
                                            ? 'Concluído'
                                            : 'Falta: ${(item.totalExpected - item.totalPicked).toStringAsFixed(0)} ${item.baseUnit}',
                                        style: TextStyle(
                                          color: isDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFD97706),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Separado: ${item.totalPicked.toStringAsFixed(0)} / ${item.totalExpected.toStringAsFixed(0)} ${item.baseUnit}',
                                      style: TextStyle(
                                        color: isDone
                                            ? const Color(0xFF10B981)
                                            : context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          isDone
                                              ? 'Revisar / Estornar'
                                              : 'Bipar HUs',
                                          style: TextStyle(
                                            color: isDone
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isDone
                                              ? LucideIcons.eye
                                              : LucideIcons.chevron_right,
                                          size: 16,
                                          color: isDone
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ],
                                    ),
                                  ],
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
      bottomNavigationBar: isLocationDone
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(top: BorderSide(color: context.border)),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.circle_check, size: 18),
                    label: const Text(
                      'CONCLUIR POSIÇÃO E AVANÇAR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProductGroupSummary {
  final String orderId;
  final String orderItemId;
  final String productId;
  final String skuCode;
  final String description;
  final String baseUnit;
  final double totalExpected;
  final double totalPicked;
  final String? firstAllocationId;

  _ProductGroupSummary({
    required this.orderId,
    required this.orderItemId,
    required this.productId,
    required this.skuCode,
    required this.description,
    required this.baseUnit,
    required this.totalExpected,
    required this.totalPicked,
    this.firstAllocationId,
  });

  bool get isDone => totalPicked >= totalExpected && totalExpected > 0;
}
