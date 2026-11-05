import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../data/picking_models.dart';
import '../presentation/picking_provider.dart';
import 'widgets/pick_quantity_dialog.dart';

class OrderPickingScreen extends StatefulWidget {
  final String orderId;

  const OrderPickingScreen({super.key, required this.orderId});

  @override
  State<OrderPickingScreen> createState() => _OrderPickingScreenState();
}

class _OrderPickingScreenState extends State<OrderPickingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PickingProvider>().loadSingleOrderTasks(widget.orderId);
    });
  }

  Future<void> _handlePick(ConsolidatedPickingTask task) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PickQuantityDialog(task: task),
    );

    if (result != null && mounted) {
      final msg = result['message']?.toString() ?? 'Item separado com sucesso!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickingProvider>();
    final summary = provider.currentOrderSummary;
    final groups = provider.currentOrderGroupsByLocation;

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
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : groups.isEmpty
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
                      'Separação 100% Concluída!',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Todos os itens deste pedido já foram recolhidos.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final group = groups[idx];

                return Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topo do Endereço
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardSubtle,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          border: Border(
                            bottom: BorderSide(color: context.border),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.map_pin,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  group.locationPath,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${group.pendingTasksCount} item(ns) pendente(s)',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Itens daquele endereço
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: group.tasks.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: context.border, height: 16),
                        itemBuilder: (context, taskIdx) {
                          final task = group.tasks[taskIdx];

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                task.isPicked
                                    ? LucideIcons.circle_check
                                    : LucideIcons.circle,
                                size: 20,
                                color: task.isPicked
                                    ? const Color(0xFF10B981)
                                    : context.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${task.skuCode} - ${task.description}',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'LPN: ${task.lpn} • ${task.packagingCode}',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (task.batch != null)
                                      Text(
                                        'Lote: ${task.batch}',
                                        style: TextStyle(
                                          color: context.textSecondary,
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${task.quantity.toStringAsFixed(0)} ${task.baseUnit}',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (!task.isPicked)
                                    SizedBox(
                                      height: 32,
                                      child: ElevatedButton(
                                        onPressed: () => _handlePick(task),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFF59E0B,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'SEPARAR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Recolhido',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
