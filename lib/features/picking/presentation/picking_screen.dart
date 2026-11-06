import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/picking_models.dart';
import 'location_products_screen.dart';
import 'order_picking_screen.dart';
import 'picking_provider.dart';

class PickingScreen extends StatefulWidget {
  const PickingScreen({super.key});

  @override
  State<PickingScreen> createState() => _PickingScreenState();
}

class _PickingScreenState extends State<PickingScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PickingProvider>().loadAllData();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;

      // TRAVA DE CONTEXTO: Ignora o bip se esta tela não for a tela no topo!
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;

      _handleQuickScan(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleQuickScan(String barcode) {
    if (barcode.isEmpty) return;
    HapticFeedback.lightImpact();
    final provider = context.read<PickingProvider>();

    // 1. Verifica se bipou um endereço existente
    final matchLoc = provider.locationGroups.firstWhere(
      (g) => g.locationPath.toUpperCase() == barcode.toUpperCase(),
      orElse: () => LocationPickingGroup(locationPath: '', tasks: []),
    );
    if (matchLoc.locationPath.isNotEmpty) {
      _openLocationScreen(matchLoc.locationPath);
      return;
    }

    // 2. Verifica se bipou o LPN de uma HU pendente
    final task = provider.findPendingTaskByLpn(barcode);
    if (task != null) {
      _openLocationScreen(task.locationPath);
      return;
    }

    // 3. Caso contrário, joga no filtro
    _searchController.text = barcode;
    setState(() {});
  }

  Future<void> _openLocationScreen(String locationPath) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationProductsScreen(locationPath: locationPath),
      ),
    );

    if (mounted) {
      context.read<PickingProvider>().loadAllData(
        search: _searchController.text,
      );
    }
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Endereço ou LPN da HU',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleQuickScan(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PickingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final search = _searchController.text.trim().toLowerCase();

    final filteredLocations = provider.locationGroups.where((g) {
      if (search.isEmpty) return true;
      final matchLoc = g.locationPath.toLowerCase().contains(search);
      final matchTasks = g.tasks.any(
        (t) =>
            t.skuCode.toLowerCase().contains(search) ||
            t.lpn.toLowerCase().contains(search) ||
            t.orderNumber.toLowerCase().contains(search),
      );
      return matchLoc || matchTasks;
    }).toList();

    final filteredOrders = provider.activeOrders.where((o) {
      if (search.isEmpty) return true;
      final num = o['orderNumber']?.toString().toLowerCase() ?? '';
      final cust = o['customerName']?.toString().toLowerCase() ?? '';
      final dest = o['destinationName']?.toString().toLowerCase() ?? '';
      return num.contains(search) ||
          cust.contains(search) ||
          dest.contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Separação de Cargas (Picking)',
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
                provider.loadAllData(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de Modo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<PickingViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: PickingViewMode.byLocation,
                        icon: Icon(LucideIcons.map_pin, size: 16),
                        label: Text(
                          'Por Endereço',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: PickingViewMode.byOrder,
                        icon: Icon(LucideIcons.file_text, size: 16),
                        label: Text(
                          'Por Pedido',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    selected: {provider.viewMode},
                    onSelectionChanged: (set) =>
                        provider.setViewMode(set.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFFF59E0B)
                              .withValues(alpha: 0.15);
                        }
                        return context.cardSubtle;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFFD97706);
                        }
                        return context.textSecondary;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: provider.viewMode == PickingViewMode.byLocation
                          ? 'Bipar ou filtrar Endereço, LPN ou SKU...'
                          : 'Bipar ou filtrar Pedido, Destinatário...',
                      prefixIcon: const Icon(
                        LucideIcons.scan_line,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              LucideIcons.camera,
                              color: Color(0xFFF59E0B),
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
                                setState(() {});
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

          // Conteúdo
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                  )
                : provider.viewMode == PickingViewMode.byLocation
                ? _buildByLocationView(filteredLocations)
                : _buildByOrderView(filteredOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildByLocationView(List<LocationPickingGroup> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.inbox, size: 56, color: context.textMuted),
              const SizedBox(height: 12),
              Text(
                'Nenhum endereço com separação pendente',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Não existem alocações pendentes de coleta no momento.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final group = groups[idx];
        final pendingCount = group.pendingTasksCount;
        final isGroupDone = pendingCount == 0;
        final distinctSkus = group.tasks.map((t) => t.skuCode).toSet();

        return Material(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openLocationScreen(group.locationPath),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isGroupDone
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Text(
                          isGroupDone ? 'Concluído' : '$pendingCount volume(s)',
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
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.distinctOrderNumbers.length} pedido(s): ${group.distinctOrderNumbers.join(", ")}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Divider(color: context.border, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isGroupDone
                            ? 'Volumes recolhidos'
                            : 'Pendente: ${group.totalPendingQuantity.toStringAsFixed(0)} un',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            isGroupDone
                                ? 'Revisar / Estornar'
                                : 'Acessar Endereço',
                            style: TextStyle(
                              color: isGroupDone
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.chevron_right,
                            size: 16,
                            color: isGroupDone
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
    );
  }

  Widget _buildByOrderView(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.inbox, size: 56, color: context.textMuted),
              const SizedBox(height: 12),
              Text(
                'Nenhum pedido aguardando picking',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Todos os pedidos alocados já foram separados.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final order = orders[idx];
        final orderId = order['id']?.toString() ?? '';
        final orderNum = order['orderNumber']?.toString() ?? 'N/A';
        final customer = order['customerName']?.toString() ?? 'Depositante';
        final dest = order['destinationName']?.toString() ?? 'Destinatário';
        final status = order['status']?.toString() ?? 'Allocated';

        return Material(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final pickingProvider = context.read<PickingProvider>();
              final searchText = _searchController.text;

              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderPickingScreen(orderId: orderId),
                ),
              );

              if (!mounted) return;
              pickingProvider.loadAllData(search: searchText);
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.file_text,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pedido #$orderNum',
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
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          status == 'Picking'
                              ? 'Em Separação'
                              : 'Pronto para Coleta',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Destino: $dest',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Depositante: $customer',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Divider(color: context.border, height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Ver Rota de Endereços',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevron_right,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
