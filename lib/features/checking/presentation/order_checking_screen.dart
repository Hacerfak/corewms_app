import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/checking_models.dart';
import '../presentation/checking_provider.dart';

class OrderCheckingScreen extends StatefulWidget {
  final String orderId;

  const OrderCheckingScreen({super.key, required this.orderId});

  @override
  State<OrderCheckingScreen> createState() => _OrderCheckingScreenState();
}

class _OrderCheckingScreenState extends State<OrderCheckingScreen>
    with SingleTickerProviderStateMixin {
  final _barcodeController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _focusNode = FocusNode();
  StreamSubscription<String>? _scanSubscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CheckingProvider>().loadOrderTasks(widget.orderId);
    });

    // Escuta o laser do Movfast Ranger 2 via Broadcast Intent
    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _handleScan(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _barcodeController.dispose();
    _qtyController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String code) async {
    if (code.isEmpty) return;
    _barcodeController.text = code;

    final provider = context.read<CheckingProvider>();
    final qty =
        double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 1.0;

    final result = await provider.scanCode(
      orderId: widget.orderId,
      scannedCode: code,
      quantity: qty,
    );

    if (!mounted) return;

    if (result != null) {
      HapticFeedback.lightImpact();
      final msg = result['message']?.toString() ?? 'Código conferido!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(msg),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      _barcodeController.clear();
      _qtyController.text = '1';
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _openCameraScanner() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Código (HU, Volume ou SKU)',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleScan(code);
    }
  }

  Future<void> _handleResetChecking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              LucideIcons.rotate_ccw,
              color: Color(0xFFEF4444),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Resetar Conferência?',
              style: TextStyle(color: context.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Todas as leituras deste pedido serão canceladas e o processo precisará ser refeito do início.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCELAR',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'RESETAR TUDO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<CheckingProvider>().resetChecking(
        widget.orderId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conferência do pedido resetada com sucesso!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckingProvider>();
    final details = provider.currentDetails;

    final totalExp = details?.totalExpected ?? 0.0;
    final totalChk = details?.totalChecked ?? 0.0;
    final progress = totalExp > 0 ? (totalChk / totalExp).clamp(0.0, 1.0) : 0.0;
    final is100Percent = details?.isOrderFullyChecked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details != null
                  ? 'Conferência #${details.orderNumber}'
                  : 'Conferência de Carga',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (details != null)
              Text(
                details.customerName,
                style: TextStyle(color: context.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.rotate_ccw,
              color: Color(0xFFEF4444),
              size: 20,
            ),
            tooltip: 'Resetar Conferência',
            onPressed: _handleResetChecking,
          ),
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () => provider.loadOrderTasks(widget.orderId),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            )
          : details == null
          ? Center(
              child: Text(
                'Dados da conferência não encontrados.',
                style: TextStyle(color: context.textSecondary),
              ),
            )
          : Column(
              children: [
                // Aviso de trava: itens fracionados pendentes no packing
                if (details.hasFractionalPendingPacking)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.circle_alert,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Atenção: Este pedido possui fracionados aguardando finalização no Packing.',
                            style: TextStyle(
                              color: context.isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF991B1B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Card de Progresso Geral da Carga
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
                            is100Percent
                                ? 'CARGA 100% CONFERIDA!'
                                : 'Progresso da Conferência:',
                            style: TextStyle(
                              color: is100Percent
                                  ? const Color(0xFF10B981)
                                  : context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${totalChk.toStringAsFixed(0)} / ${totalExp.toStringAsFixed(0)} un',
                            style: TextStyle(
                              color: is100Percent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF06B6D4),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: context.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            is100Percent
                                ? const Color(0xFF10B981)
                                : const Color(0xFF06B6D4),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Formulário de Leitura / Bipagem
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.cardSubtle,
                    border: Border(bottom: BorderSide(color: context.border)),
                  ),
                  child: Column(
                    children: [
                      if (provider.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.circle_alert,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _barcodeController,
                              focusNode: _focusNode,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: _handleScan,
                              decoration: InputDecoration(
                                hintText: 'Bipe LPN, VOL-... ou SKU',
                                prefixIcon: const Icon(
                                  LucideIcons.scan,
                                  color: Color(0xFF06B6D4),
                                  size: 18,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    LucideIcons.camera,
                                    color: Color(0xFF06B6D4),
                                    size: 18,
                                  ),
                                  onPressed: _openCameraScanner,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _qtyController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Qtd',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: provider.isScanning
                                  ? null
                                  : () => _handleScan(_barcodeController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: provider.isScanning
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      LucideIcons.corner_down_left,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Abas: "Volumes / HUs" vs "Itens / SKUs"
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF06B6D4),
                  labelColor: const Color(0xFF06B6D4),
                  unselectedLabelColor: context.textSecondary,
                  tabs: [
                    Tab(
                      text:
                          'Volumes (${details.volumes.where((v) => v.isChecked).length}/${details.volumes.length})',
                    ),
                    Tab(
                      text:
                          'Itens (${details.items.where((i) => i.isFullyChecked).length}/${details.items.length})',
                    ),
                  ],
                ),

                // Conteúdo das Abas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ABA 1: Volumes Físicos
                      _buildVolumesTab(details.volumes),

                      // ABA 2: Itens por SKU
                      _buildItemsTab(details.items),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVolumesTab(List<CheckingVolumeModel> volumes) {
    if (volumes.isEmpty) {
      return Center(
        child: Text(
          'Nenhum volume cadastrado.',
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: volumes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final vol = volumes[idx];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: vol.isChecked
                ? const Color(0xFF10B981)
                      .withValues(alpha: context.isDark ? 0.12 : 0.06)
                : context.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: vol.isChecked ? const Color(0xFF10B981) : context.border,
              width: vol.isChecked ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                vol.isChecked ? LucideIcons.circle_check : LucideIcons.circle,
                color: vol.isChecked
                    ? const Color(0xFF10B981)
                    : context.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vol.lpn,
                          style: TextStyle(
                            color: vol.isChecked
                                ? const Color(0xFF10B981)
                                : context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${vol.quantity.toStringAsFixed(0)} ${vol.unit}',
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
                      'SKU: ${vol.skuCode} • Origem: ${vol.locationPath}',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (vol.isChecked && vol.checkedByName != null)
                      Text(
                        'Conferido por: ${vol.checkedByName}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsTab(List<CheckingItemModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nenhum item encontrado.',
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = items[idx];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.isFullyChecked
                ? const Color(0xFF10B981)
                      .withValues(alpha: context.isDark ? 0.12 : 0.06)
                : context.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: item.isFullyChecked
                  ? const Color(0xFF10B981)
                  : context.border,
              width: item.isFullyChecked ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.skuCode,
                    style: TextStyle(
                      color: item.isFullyChecked
                          ? const Color(0xFF10B981)
                          : context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '${item.checkedQuantity.toStringAsFixed(0)} / ${item.expectedQuantity.toStringAsFixed(0)} ${item.unit}',
                    style: TextStyle(
                      color: item.isFullyChecked
                          ? const Color(0xFF10B981)
                          : const Color(0xFF06B6D4),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
