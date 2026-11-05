import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../presentation/checking_provider.dart';
import 'order_checking_screen.dart';

class CheckingOrdersListScreen extends StatefulWidget {
  const CheckingOrdersListScreen({super.key});

  @override
  State<CheckingOrdersListScreen> createState() =>
      _CheckingOrdersListScreenState();
}

class _CheckingOrdersListScreenState extends State<CheckingOrdersListScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckingProvider>().loadOrders();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _searchController.text = barcode.trim();
      context.read<CheckingProvider>().loadOrders(search: barcode.trim());
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
    final code = await QrScannerDialog.scan(context, title: 'Bipar Pedido');
    if (code != null && code.isNotEmpty && mounted) {
      _searchController.text = code;
      context.read<CheckingProvider>().loadOrders(search: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckingProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conferência de Expedição',
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
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () =>
                provider.loadOrders(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
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
                      hintText: 'Bipar ou filtrar Pedido, Destino...',
                      prefixIcon: const Icon(
                        LucideIcons.scan_line,
                        color: Color(0xFF06B6D4),
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              LucideIcons.camera,
                              color: Color(0xFF06B6D4),
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
              ],
            ),
          ),

          // Lista de Ordens Elegíveis
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  )
                : provider.orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.clipboard_check,
                            size: 56,
                            color: context.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma carga aguardando conferência',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apenas pedidos em separação, embalagem ou prontos para checking aparecem aqui.',
                            textAlign: TextAlign.center,
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
                    itemCount: provider.orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final order = provider.orders[idx];
                      final isChecking =
                          order.status.toUpperCase() == 'CHECKING';
                      final isReady =
                          order.status.toUpperCase() == 'READYTOSHIP';

                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderCheckingScreen(orderId: order.id),
                              ),
                            );
                            if (context.mounted) {
                              context.read<CheckingProvider>().loadOrders(
                                search: _searchController.text,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: context.border),
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
                                        const Icon(
                                          LucideIcons.clipboard_check,
                                          color: Color(0xFF06B6D4),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pedido #${order.orderNumber}',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isReady
                                            ? const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15)
                                            : const Color(0xFF06B6D4)
                                                  .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isReady
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF06B6D4),
                                        ),
                                      ),
                                      child: Text(
                                        isReady
                                            ? 'Conferido 100%'
                                            : (isChecking
                                                  ? 'Em Conferência'
                                                  : 'Pronto p/ Checking'),
                                        style: TextStyle(
                                          color: isReady
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF06B6D4),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Destino: ${order.destinationName ?? "Não Informado"}',
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
                                Divider(color: context.border, height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${order.itemsCount} item(ns)',
                                      style: TextStyle(
                                        color: context.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Row(
                                      children: [
                                        Text(
                                          'Conferir Carga',
                                          style: TextStyle(
                                            color: Color(0xFF06B6D4),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          LucideIcons.chevron_right,
                                          size: 16,
                                          color: Color(0xFF06B6D4),
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
    );
  }
}
