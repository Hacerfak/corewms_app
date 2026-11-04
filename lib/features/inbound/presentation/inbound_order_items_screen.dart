import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../hu/data/hu_models.dart';
import '../../hu/presentation/hu_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/inbound_models.dart';
import 'conferencia_item_screen.dart';
import 'inbound_provider.dart';

class InboundOrderItemsScreen extends StatefulWidget {
  final InboundOrderSummary orderSummary;

  const InboundOrderItemsScreen({super.key, required this.orderSummary});

  @override
  State<InboundOrderItemsScreen> createState() =>
      _InboundOrderItemsScreenState();
}

class _InboundOrderItemsScreenState extends State<InboundOrderItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<InboundProvider>();
    await Future.wait([
      provider.loadOrderDetails(widget.orderSummary.id),
      provider.loadDocksAndServices(),
    ]);
  }

  Future<void> _handleSelectItem(InboundOrderItemModel item) async {
    final auth = context.read<AuthProvider>();
    final inboundProvider = context.read<InboundProvider>();

    final isLockedByOther =
        item.isReceiving &&
        item.lockedByUserId != null &&
        item.lockedByUserId != auth.user?.id;

    if (isLockedByOther) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.lock, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Text('Item em Conferência', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'Este item está sendo conferido por "${item.lockedByUserName ?? "outro operador"}".\n\nAguarde a finalização ou solicite a liberação da linha.',
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
              ),
              child: const Text(
                'ENTENDIDO',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;

    final chosenDockId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.warehouse,
              color: Color(0xFF10B981),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Doca de Recebimento',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: inboundProvider.docks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Nenhuma doca ativa encontrada na Topologia.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: inboundProvider.docks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final dock = inboundProvider.docks[idx];
                    final isPrevious = dock.id == item.dockLocationId;

                    return InkWell(
                      onTap: () => Navigator.of(context).pop(dock.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isPrevious
                              ? const Color(0xFF064E3B).withValues(alpha: 0.15)
                              : context.cardSubtle,
                          border: Border.all(
                            color: isPrevious
                                ? const Color(0xFF059669)
                                : context.border,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.warehouse,
                              color: isPrevious
                                  ? const Color(0xFF34D399)
                                  : context.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dock.fullPath,
                                style: TextStyle(
                                  color: isPrevious
                                      ? const Color(0xFF34D399)
                                      : context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (isPrevious)
                              const Icon(
                                LucideIcons.circle_check,
                                color: Color(0xFF34D399),
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              'CANCELAR',
              style: TextStyle(
                color: context.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (chosenDockId == null || !mounted) return;

    final success = await inboundProvider.startReceivingItem(
      orderItemId: item.id,
      dockLocationId: chosenDockId,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            inboundProvider.errorMessage ?? 'Não foi possível reservar o item.',
          ),
        ),
      );
      return;
    }

    final huProvider = context.read<HuProvider>();
    await huProvider.loadProductPackagings(item.productId!);

    if (!mounted) return;

    final dockPath = inboundProvider.docks
        .firstWhere(
          (d) => d.id == chosenDockId,
          orElse: () =>
              LocationModel(id: chosenDockId, fullPath: 'DOCA', code: 'DOCA'),
        )
        .fullPath;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConferenciaItemScreen(
          orderId: widget.orderSummary.id,
          orderItemId: item.id,
          itemData: {
            'productId': item.productId,
            'sku': item.sku,
            'description': item.description,
            'unit': item.unit,
            'expectedQuantity': item.expectedQuantity,
            'receivedQuantity': item.receivedQuantity,
            'dockLocationPath': dockPath,
            'dockLocationId': chosenDockId,
            'expectedBatch': item.expectedBatch,
            'expectedManufactureDate': item.expectedManufactureDate,
            'expectedExpirationDate': item.expectedExpirationDate,
          },
          packagings: huProvider.productPackagings,
        ),
      ),
    );

    if (mounted) {
      inboundProvider.loadOrderDetails(widget.orderSummary.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.user?.id;

    final provider = context.watch<InboundProvider>();
    final order = provider.currentOrder;

    final pendingItems =
        order?.items.where((i) => !i.isCompleted).toList() ?? [];
    final totalItems = order?.items.length ?? 0;
    final completedCount = totalItems - pendingItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orderSummary.invoiceNumber != null
              ? 'NF ${widget.orderSummary.invoiceNumber} • Itens'
              : 'Itens da NF-e',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            tooltip: 'Recarregar Itens',
            onPressed: () => provider.loadOrderDetails(widget.orderSummary.id),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : order == null
          ? Center(
              child: Text(
                'Ordem não encontrada.',
                style: TextStyle(color: context.textSecondary),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              backgroundColor: context.card,
              onRefresh: () =>
                  provider.loadOrderDetails(widget.orderSummary.id),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.card,
                      border: Border(bottom: BorderSide(color: context.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pendentes: ${pendingItems.length} de $totalItems itens',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$completedCount concluído(s)',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: pendingItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    LucideIcons.circle_check,
                                    size: 64,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Recebimento 100% Concluído!',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Todos os itens desta nota fiscal já foram descarregados e conferidos na Doca.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      context
                                          .read<InboundProvider>()
                                          .loadOrders();
                                      Navigator.of(context).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'VOLTAR ÀS ORDENS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: pendingItems.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = pendingItems[idx];
                              final isReceiving = item.isReceiving;
                              final isLockedByMe =
                                  isReceiving &&
                                  item.lockedByUserId == currentUserId;
                              final isLockedByOther =
                                  isReceiving &&
                                  !isLockedByMe &&
                                  item.lockedByUserId != null;

                              return Material(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _handleSelectItem(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isLockedByOther
                                            ? const Color(0xFFF59E0B)
                                            : isLockedByMe
                                            ? const Color(0xFF059669)
                                            : context.border,
                                        width: isReceiving ? 1.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: context.cardSubtle,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '#${item.lineNumber}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF2563EB),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  item.sku,
                                                  style: TextStyle(
                                                    color: context.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            _buildStatusBadge(
                                              item,
                                              isLockedByMe,
                                              isLockedByOther,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
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
                                        if (isReceiving) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLockedByMe
                                                  ? const Color(0xFF064E3B)
                                                        .withValues(alpha: 0.15)
                                                  : const Color(
                                                      0xFF451A03,
                                                    ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isLockedByMe
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFD97706),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isLockedByMe
                                                      ? LucideIcons.user_check
                                                      : LucideIcons.user_x,
                                                  size: 14,
                                                  color: isLockedByMe
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFD97706),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    isLockedByMe
                                                        ? 'Em conferência por você'
                                                        : 'Em conferência por: ${item.lockedByUserName ?? "Outro Operador"}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: isLockedByMe
                                                          ? const Color(
                                                              0xFF059669,
                                                            )
                                                          : const Color(
                                                              0xFFD97706,
                                                            ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${item.receivedQuantity.toStringAsFixed(0)} / ${item.expectedQuantity.toStringAsFixed(0)} ${item.unit}',
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: context.cardSubtle,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      item.dockLocationPath !=
                                                          null
                                                      ? const Color(0xFF0284C7)
                                                      : context.border,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.warehouse,
                                                    size: 12,
                                                    color:
                                                        item.dockLocationPath !=
                                                            null
                                                        ? const Color(
                                                            0xFF0284C7,
                                                          )
                                                        : context.textMuted,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.dockLocationPath !=
                                                            null
                                                        ? 'Doca ${item.dockLocationPath}'
                                                        : 'Sem Doca',
                                                    style: TextStyle(
                                                      color:
                                                          item.dockLocationPath !=
                                                              null
                                                          ? const Color(
                                                              0xFF0284C7,
                                                            )
                                                          : context.textMuted,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              'Falta: ${(item.expectedQuantity - item.receivedQuantity).toStringAsFixed(0)} ${item.unit}',
                                              style: const TextStyle(
                                                color: Color(0xFFF59E0B),
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
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
            ),
    );
  }

  Widget _buildStatusBadge(
    InboundOrderItemModel item,
    bool isLockedByMe,
    bool isLockedByOther,
  ) {
    if (item.isReceiving) {
      final color = isLockedByOther
          ? const Color(0xFFF59E0B)
          : const Color(0xFF10B981);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              'Em Conferência',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (item.receivedQuantity > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          ),
        ),
        child: const Text(
          'Parcial',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.cardSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.border),
      ),
      child: Text(
        'Aguardando',
        style: TextStyle(
          color: context.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
