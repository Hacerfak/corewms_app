import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/packing_models.dart';
import '../presentation/packing_provider.dart';
import 'widgets/finalize_packing_dialog.dart';
import 'widgets/pack_item_dialog.dart';

class PackingOrderItemsScreen extends StatefulWidget {
  final PackingOrderSummary orderSummary;

  const PackingOrderItemsScreen({super.key, required this.orderSummary});

  @override
  State<PackingOrderItemsScreen> createState() =>
      _PackingOrderItemsScreenState();
}

class _PackingOrderItemsScreenState extends State<PackingOrderItemsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PackingProvider>().loadOrderDetails(widget.orderSummary.id);
    });
  }

  Future<void> _handlePackItem(PackingOrderItemModel item) async {
    if (item.pickedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este item ainda não foi separado no coletor (Picking pendente).',
          ),
        ),
      );
      return;
    }

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PackItemDialog(orderId: widget.orderSummary.id, item: item),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Embalagem do SKU ${item.skuCode} gravada!'),
        ),
      );
    }
  }

  Future<void> _handleFinalizeOrder() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FinalizePackingDialog(
        orderId: widget.orderSummary.id,
        orderNumber: widget.orderSummary.orderNumber,
      ),
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Pedido #${widget.orderSummary.orderNumber} enviado para a Doca de Embarque!',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PackingProvider>();
    final items = provider.currentItems;
    final totalItems = items.length;
    final packedItemsCount = items.where((i) => i.isFullyPacked).length;
    final canFinalize = totalItems > 0 && packedItemsCount == totalItems;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedido #${widget.orderSummary.orderNumber}',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.orderSummary.customerName} • ${widget.orderSummary.destinationName ?? ""}',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () => provider.loadOrderDetails(widget.orderSummary.id),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            )
          : Column(
              children: [
                // Barra de Progresso do Packing
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
                            'Progresso da Mesa:',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$packedItemsCount de $totalItems itens empacotados',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalItems > 0
                              ? (packedItemsCount / totalItems)
                              : 0,
                          backgroundColor: context.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de Itens do Pedido
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      final isPacked = item.isFullyPacked;
                      final isPicked = item.isFullyPicked;

                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _handlePackItem(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isPacked
                                    ? const Color(0xFF10B981)
                                    : (isPicked
                                          ? const Color(0xFF8B5CF6)
                                          : context.border),
                                width: isPacked ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.cardSubtle,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '#${item.lineNumber}',
                                            style: const TextStyle(
                                              color: Color(0xFF8B5CF6),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.skuCode,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            fontFamily: 'monospace',
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
                                        color: isPacked
                                            ? const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15)
                                            : (isPicked
                                                  ? const Color(0xFF8B5CF6)
                                                        .withValues(alpha: 0.15)
                                                  : context.cardSubtle),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isPacked
                                              ? const Color(0xFF10B981)
                                              : (isPicked
                                                    ? const Color(0xFF8B5CF6)
                                                    : context.border),
                                        ),
                                      ),
                                      child: Text(
                                        isPacked
                                            ? 'Empacotado'
                                            : (isPicked
                                                  ? 'Pronto p/ Mesa'
                                                  : 'Picking Pendente'),
                                        style: TextStyle(
                                          color: isPacked
                                              ? const Color(0xFF10B981)
                                              : (isPicked
                                                    ? const Color(0xFF8B5CF6)
                                                    : context.textSecondary),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                                Divider(color: context.border, height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Separado: ${item.pickedQuantity.toStringAsFixed(0)} / ${item.expectedQuantity.toStringAsFixed(0)} ${item.unit}',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      'Embalado: ${item.packedQuantity.toStringAsFixed(0)} ${item.unit}',
                                      style: TextStyle(
                                        color: isPacked
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
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

      // Botão inferior de Finalização da Carga (habilitado quando tudo foi embalado)
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
              onPressed: canFinalize ? _handleFinalizeOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.circle_check, size: 18),
              label: Text(
                canFinalize
                    ? 'FINALIZAR PACKING & ENVIAR P/ DOCA'
                    : 'CONCLUA A EMBALAGEM DE TODOS OS ITENS',
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
