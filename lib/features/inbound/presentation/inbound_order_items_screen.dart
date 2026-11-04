import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../hu/data/hu_models.dart';
import '../../hu/presentation/hu_provider.dart';
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

    // Validação contra concorrência: item travado por outro operador
    final isLockedByOther =
        item.isReceiving &&
        item.lockedByUserId != null &&
        item.lockedByUserId != auth.user?.id;

    if (isLockedByOther) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Text(
                'Item em Conferência',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Este item está sendo conferido por "${item.lockedByUserName ?? "outro operador"}".\n\nAguarde a finalização ou solicite a liberação da linha.',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
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

    // REGRA 3: Sempre abre a seleção de doca ao iniciar ou voltar a receber
    final chosenDockId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warehouse_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text(
              'Doca de Recebimento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: inboundProvider.docks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Nenhuma doca ativa encontrada na Topologia.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                              : const Color(0xFF0F172A),
                          border: Border.all(
                            color: isPrevious
                                ? const Color(0xFF059669)
                                : const Color(0xFF334155),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warehouse_rounded,
                              color: isPrevious
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF64748B),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dock.fullPath,
                                style: TextStyle(
                                  color: isPrevious
                                      ? const Color(0xFF34D399)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            if (isPrevious)
                              const Icon(
                                Icons.check_circle_rounded,
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
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (chosenDockId == null || !mounted) return;

    // Trava a linha do item na doca escolhida
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

    // Carrega embalagens cadastradas no produto
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

    // Recarrega os itens ao retornar da conferência
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.orderSummary.invoiceNumber != null
              ? 'NF ${widget.orderSummary.invoiceNumber} • Itens'
              : 'Itens da NF-e',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          // REGRA 1: Botão explícito de recarregar
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
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
          ? const Center(
              child: Text(
                'Ordem não encontrada.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: () =>
                  provider.loadOrderDetails(widget.orderSummary.id),
              child: Column(
                children: [
                  // Barra de Progresso da NF
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pendentes: ${pendingItems.length} de $totalItems itens',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
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

                  // Lista dos Itens
                  Expanded(
                    child: pendingItems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 64,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Recebimento 100% Concluído!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Todos os itens desta nota fiscal já foram descarregados e conferidos na Doca.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: () {
                                      // Recarrega as ordens ativas para remover a NF finalizada da lista
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
                                color: const Color(0xFF1E293B),
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
                                            : const Color(0xFF334155),
                                        width: isReceiving ? 1.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Topo do Card: Linha, SKU e Status
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
                                                    color: const Color(
                                                      0xFF0F172A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '#${item.lineNumber}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF60A5FA),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  item.sku,
                                                  style: const TextStyle(
                                                    color: Colors.white,
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
                                          style: const TextStyle(
                                            color: Color(0xFFCBD5E1),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // REGRA 2: Tarja exclusiva do Operador (sem o texto da Doca)
                                        if (isReceiving) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLockedByMe
                                                  ? const Color(0xFF064E3B)
                                                        .withValues(alpha: 0.35)
                                                  : const Color(0xFF451A03)
                                                        .withValues(alpha: 0.4),
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
                                                      ? Icons.person_rounded
                                                      : Icons
                                                            .lock_person_rounded,
                                                  size: 14,
                                                  color: isLockedByMe
                                                      ? const Color(0xFF34D399)
                                                      : const Color(0xFFFBBF24),
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
                                                              0xFF34D399,
                                                            )
                                                          : const Color(
                                                              0xFFFDE68A,
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

                                        // REGRA 2: Rodapé do Card
                                        // [Recebido / Esperado] | [Doca no Meio] | [Falta]
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // 1. Quantidade sem o texto "Progresso:"
                                            Text(
                                              '${item.receivedQuantity.toStringAsFixed(0)} / ${item.expectedQuantity.toStringAsFixed(0)} ${item.unit}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'monospace',
                                                fontSize: 12,
                                              ),
                                            ),

                                            // 2. Doca no centro destacada
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      item.dockLocationPath !=
                                                          null
                                                      ? const Color(0xFF0284C7)
                                                      : const Color(0xFF334155),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.warehouse_rounded,
                                                    size: 12,
                                                    color:
                                                        item.dockLocationPath !=
                                                            null
                                                        ? const Color(
                                                            0xFF38BDF8,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
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
                                                              0xFF38BDF8,
                                                            )
                                                          : const Color(
                                                              0xFF64748B,
                                                            ),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 3. Saldo Faltante
                                            Text(
                                              'Falta: ${(item.expectedQuantity - item.receivedQuantity).toStringAsFixed(0)} ${item.unit}',
                                              style: const TextStyle(
                                                color: Color(0xFFFBBF24),
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
            color: Color(0xFF60A5FA),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF64748B).withValues(alpha: 0.4),
        ),
      ),
      child: const Text(
        'Aguardando',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
