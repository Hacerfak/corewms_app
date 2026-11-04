import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import 'inbound_order_items_screen.dart';
import 'inbound_provider.dart';

class InboundOrdersListScreen extends StatefulWidget {
  const InboundOrdersListScreen({super.key});

  @override
  State<InboundOrdersListScreen> createState() =>
      _InboundOrdersListScreenState();
}

class _InboundOrdersListScreenState extends State<InboundOrdersListScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InboundProvider>().loadOrders();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _searchController.text = barcode.trim();
      context.read<InboundProvider>().loadOrders(search: barcode.trim());
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Código de Barras da NF-e',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _searchController.text = code;
      context.read<InboundProvider>().loadOrders(search: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InboundProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Recebimento de Cargas',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            tooltip: 'Atualizar Ordens',
            onPressed: () =>
                provider.loadOrders(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa Adaptável
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _searchController,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (v) => provider.loadOrders(search: v),
                    decoration: InputDecoration(
                      hintText: 'Bipar ou digitar NF-e / Chave...',
                      prefixIcon: const Icon(
                        LucideIcons.scan_line,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              LucideIcons.camera,
                              color: Color(0xFF34D399),
                              size: 18,
                            ),
                            onPressed: _openCamera,
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                LucideIcons.x,
                                color: context.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                provider.loadOrders();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () =>
                        provider.loadOrders(search: _searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'BUSCAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Ordens
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF10B981),
                    backgroundColor: context.card,
                    onRefresh: () =>
                        provider.loadOrders(search: _searchController.text),
                    child: provider.orders.isEmpty
                        ? LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              LucideIcons.inbox,
                                              size: 56,
                                              color: context.textMuted,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Nenhuma ordem aguardando recebimento',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Apenas notas fiscais com cadastro de itens 100% revisado na web são exibidas aqui.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: provider.orders.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final order = provider.orders[idx];
                              final isReceiving =
                                  order.status.toUpperCase() == 'RECEIVING';

                              return Material(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => InboundOrderItemsScreen(
                                          orderSummary: order,
                                        ),
                                      ),
                                    );
                                    if (context.mounted) {
                                      context
                                          .read<InboundProvider>()
                                          .loadOrders(
                                            search: _searchController.text,
                                          );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isReceiving
                                            ? const Color(0xFF059669)
                                            : context.border,
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
                                                const Icon(
                                                  LucideIcons.file_text,
                                                  color: Color(0xFF34D399),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  order.invoiceNumber != null
                                                      ? 'NF: ${order.invoiceNumber}/${order.invoiceSerie ?? "1"}'
                                                      : 'Chave: ${order.accessKey.substring(0, 10)}...',
                                                  style: TextStyle(
                                                    color: context.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isReceiving
                                                    ? const Color(
                                                        0xFF059669,
                                                      ).withValues(alpha: 0.2)
                                                    : const Color(
                                                        0xFF2563EB,
                                                      ).withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isReceiving
                                                      ? const Color(
                                                          0xFF059669,
                                                        ).withValues(alpha: 0.5)
                                                      : const Color(0xFF2563EB)
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                ),
                                              ),
                                              child: Text(
                                                isReceiving
                                                    ? 'Em Andamento'
                                                    : 'Pronta para Descarga',
                                                style: TextStyle(
                                                  color: isReceiving
                                                      ? const Color(0xFF34D399)
                                                      : const Color(0xFF2563EB),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          order.issuerName,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Depositante: ${order.customerName}',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Divider(
                                          color: context.border,
                                          height: 16,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Chave: ...${order.accessKey.length >= 8 ? order.accessKey.substring(order.accessKey.length - 8) : ""}',
                                              style: TextStyle(
                                                color: context.textMuted,
                                                fontFamily: 'monospace',
                                                fontSize: 10,
                                              ),
                                            ),
                                            const Row(
                                              children: [
                                                Text(
                                                  'Conferir Itens',
                                                  style: TextStyle(
                                                    color: Color(0xFF34D399),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Icon(
                                                  LucideIcons.chevron_right,
                                                  color: Color(0xFF34D399),
                                                  size: 16,
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
          ),
        ],
      ),
    );
  }
}
