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
import '../presentation/picking_provider.dart';
import 'order_picking_screen.dart';
import 'widgets/pick_quantity_dialog.dart';

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
      _handleQuickScan(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Ao bipar um LPN no leitor laser, acha a tarefa e abre a confirmação imediata
  void _handleQuickScan(String barcode) {
    HapticFeedback.lightImpact();
    final provider = context.read<PickingProvider>();

    final task = provider.findPendingTaskByLpn(barcode);
    if (task != null) {
      _openPickDialog(task);
    } else {
      _searchController.text = barcode;
      setState(() {});
    }
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar LPN da HU / Endereço',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleQuickScan(code);
    }
  }

  Future<void> _openPickDialog(ConsolidatedPickingTask task) async {
    final result = await showDialog<Map<String, dynamic>>(
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
    final themeProvider = context.watch<ThemeProvider>();
    final search = _searchController.text.trim().toLowerCase();

    // Filtros
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
          // Seletor de Modo (Por Endereço vs Por Pedido)
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

          // Barra de Pesquisa & Bipagem
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

          // Conteúdo da Lista
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

  /// Visão 1: Agrupado por Endereço (Consolidado de todos os pedidos)
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

        return Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.map_pin,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
            title: Text(
              group.locationPath,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              '${group.distinctOrderNumbers.length} pedido(s): ${group.distinctOrderNumbers.join(", ")}',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: pendingCount > 0
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                pendingCount > 0 ? '$pendingCount volume(s)' : 'Concluído',
                style: TextStyle(
                  color: pendingCount > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            children: [
              Divider(color: context.border, height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(10),
                itemCount: group.tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, taskIdx) {
                  final task = group.tasks[taskIdx];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.cardSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          task.isPicked
                              ? LucideIcons.circle_check
                              : LucideIcons.circle,
                          color: task.isPicked
                              ? const Color(0xFF10B981)
                              : context.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pedido #${task.orderNumber}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${task.quantity.toStringAsFixed(0)} ${task.baseUnit}',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${task.skuCode} - ${task.description}',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'LPN: ${task.lpn} • Lote: ${task.batch ?? "SEM LOTE"}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!task.isPicked)
                          ElevatedButton(
                            onPressed: () => _openPickDialog(task),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'COLETAR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Visão 2: Lista por Pedido
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderPickingScreen(orderId: orderId),
                ),
              );
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
