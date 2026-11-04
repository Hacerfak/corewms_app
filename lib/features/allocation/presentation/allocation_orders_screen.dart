import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'allocation_provider.dart';
import 'smart_allocation_screen.dart';

class AllocationOrdersScreen extends StatefulWidget {
  const AllocationOrdersScreen({super.key});

  @override
  State<AllocationOrdersScreen> createState() => _AllocationOrdersScreenState();
}

class _AllocationOrdersScreenState extends State<AllocationOrdersScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AllocationProvider>().loadOrders();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _handleQuickScan(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickScan(String code) async {
    HapticFeedback.lightImpact();
    final provider = context.read<AllocationProvider>();

    // 1. Tenta identificar se foi bipada uma chave/número de NF existente na lista com HUs
    final matching = provider.ordersWithHus.where(
      (item) =>
          item.order.accessKey.toUpperCase().contains(code.toUpperCase()) ||
          (item.order.invoiceNumber != null &&
              item.order.invoiceNumber!.contains(code)),
    );

    if (matching.isNotEmpty) {
      _openSmartAllocation(matching.first.order.id);
      return;
    }

    // 2. Se não encontrou pela NF, verifica se o operador bipou o LPN de uma HU
    final orderIdFromHu = await provider.resolveOrderIdFromLpn(code);
    if (orderIdFromHu != null && mounted) {
      _openSmartAllocation(orderIdFromHu);
    } else {
      _searchController.text = code;
      provider.loadOrders(search: code);
    }
  }

  Future<void> _openSmartAllocation(String orderId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SmartAllocationScreen(orderId: orderId),
      ),
    );

    // Se alocou volumes ou voltou, recarrega a lista para retirar ordens esgotadas
    if (mounted) {
      context.read<AllocationProvider>().loadOrders(
        search: _searchController.text,
      );
    }
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar NF-e ou LPN da HU',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleQuickScan(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AllocationProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alocação de Carga (Putaway)',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
              color: context.textSecondary,
            ),
            tooltip: 'Alternar Tema',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            tooltip: 'Atualizar Lista',
            onPressed: () =>
                provider.loadOrders(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa e Bipagem
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
                    style: TextStyle(color: context.textPrimary, fontSize: 13),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (v) => provider.loadOrders(search: v),
                    decoration: InputDecoration(
                      hintText: 'Bipar NF-e, Chave ou LPN de volume...',
                      prefixIcon: const Icon(
                        LucideIcons.scan_line,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              LucideIcons.camera,
                              color: Color(0xFF2563EB),
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
                      backgroundColor: const Color(0xFF2563EB),
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

          // Lista de Ordens que possuem volumes na Doca
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF2563EB),
                    backgroundColor: context.card,
                    onRefresh: () =>
                        provider.loadOrders(search: _searchController.text),
                    child: provider.ordersWithHus.isEmpty
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
                                              LucideIcons.warehouse,
                                              size: 56,
                                              color: context.textMuted,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Nenhuma carga aguardando guarda na Doca',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Todas as notas fiscais recebidas já foram 100% alocadas no armazém.',
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
                            itemCount: provider.ordersWithHus.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = provider.ordersWithHus[idx];
                              final order = item.order;

                              return Material(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openSmartAllocation(order.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: context.border),
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
                                                  color: Color(0xFF2563EB),
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
                                            // Quantidade de HUs na Doca
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    LucideIcons.box,
                                                    size: 12,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${item.pendingHusCount} volume(s) na Doca',
                                                    style: const TextStyle(
                                                      color: Color(0xFF10B981),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
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
                                              'Total: ${item.totalQuantity.toStringAsFixed(0)} unidades',
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Row(
                                              children: [
                                                Text(
                                                  'Alocar Volumes',
                                                  style: TextStyle(
                                                    color: Color(0xFF2563EB),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Icon(
                                                  LucideIcons.chevron_right,
                                                  color: Color(0xFF2563EB),
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
