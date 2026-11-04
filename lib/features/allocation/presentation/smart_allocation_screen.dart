import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import 'allocation_provider.dart';

class SmartAllocationScreen extends StatefulWidget {
  final String orderId;

  const SmartAllocationScreen({super.key, required this.orderId});

  @override
  State<SmartAllocationScreen> createState() => _SmartAllocationScreenState();
}

class _SmartAllocationScreenState extends State<SmartAllocationScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AllocationProvider>().loadOrderSuggestions(widget.orderId);
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _handleScannedLocation(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Ao bipar uma posição de estoque no coletor, aplica nas HUs selecionadas
  Future<void> _handleScannedLocation(String code) async {
    final provider = context.read<AllocationProvider>();
    if (provider.selectedHuIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione ao menos uma HU para aplicar a posição.'),
        ),
      );
      return;
    }

    final loc = await provider.findLocationByCode(code);
    if (!mounted) return;

    if (loc != null) {
      provider.applyBulkLocation(loc.id, loc.fullPath);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Posição "${loc.fullPath}" aplicada para ${provider.selectedHuIds.length} HU(s).',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Endereço "$code" não encontrado.'),
        ),
      );
    }
  }

  /// Diálogo seletor de posições pesquisável (igual ao SearchableLocationCell da web)
  Future<void> _openLocationPicker({
    required BuildContext context,
    required bool isQualityRestricted,
    required Function(String locationId, String locationPath) onSelected,
  }) async {
    final provider = context.read<AllocationProvider>();
    final locations = isQualityRestricted
        ? provider.qualityLocations
        : provider.storageLocations;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalCtx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = locations
                .where(
                  (l) =>
                      filter.isEmpty ||
                      l.fullPath.toLowerCase().contains(filter.toLowerCase()),
                )
                .take(40)
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isQualityRestricted
                              ? 'Posições de Qualidade / Retenção'
                              : 'Posições Estoque',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 20,
                            color: context.textSecondary,
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Filtrar posição (ex: P1C1BB02)...',
                        prefixIcon: Icon(LucideIcons.search, size: 18),
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum endereço encontrado.',
                                style: TextStyle(color: context.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  Divider(color: context.border, height: 1),
                              itemBuilder: (ctx, idx) {
                                final loc = filtered[idx];
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  title: Text(
                                    loc.fullPath,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    loc.code,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    LucideIcons.chevron_right,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    onSelected(loc.id, loc.fullPath);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleConfirm() async {
    final provider = context.read<AllocationProvider>();
    final count = provider.selectedHuIds.length;

    final success = await provider.confirmPutaway();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('$count HU(s) alocadas no estoque com sucesso!'),
          duration: const Duration(seconds: 3),
        ),
      );
      // Retorna true indicando que houve alocação com sucesso
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AllocationProvider>();
    final order = provider.currentOrder;
    final selectedCount = provider.selectedHuIds.length;

    final documentNumber =
        order?.accessKey != null && order!.accessKey.length >= 34
        ? int.tryParse(order.accessKey.substring(25, 34))?.toString() ?? 'N/A'
        : 'N/A';

    final search = _searchController.text.trim().toLowerCase();
    final filtered = provider.suggestions.where((s) {
      if (search.isEmpty) return true;
      return s.lpn.toLowerCase().contains(search) ||
          s.productSku.toLowerCase().contains(search) ||
          (s.batch?.toLowerCase().contains(search) ?? false);
    }).toList();

    final isAllSelected =
        filtered.isNotEmpty && selectedCount == filtered.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.sparkles,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Alocação Inteligente',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NF $documentNumber',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (order != null)
              Text(
                '${order.issuerName} • ${order.customerName}',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            tooltip: 'Recalcular Sugestões',
            onPressed: () => provider.loadOrderSuggestions(widget.orderId),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Busca e Ação em Lote (idêntica à Web)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _searchController,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Filtrar por LPN, SKU ou Lote...',
                          prefixIcon: const Icon(LucideIcons.search, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: context.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: isAllSelected,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) =>
                                provider.toggleSelectAll(val ?? false),
                          ),
                          Text(
                            'Selecionadas: $selectedCount de ${provider.suggestions.length}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Botão de Alterar Posição em Lote
                      ElevatedButton.icon(
                        onPressed: () => _openLocationPicker(
                          context: context,
                          isQualityRestricted: false,
                          onSelected: (locId, locPath) =>
                              provider.applyBulkLocation(locId, locPath),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(LucideIcons.map_pin, size: 13),
                        label: const Text(
                          'Alterar Posição em Lote',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Lista de Volumes / HUs
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  )
                : filtered.isEmpty
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
                            'Nenhum volume pendente de alocação nesta Doca.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Todos os volumes desta nota fiscal já foram armazenados no estoque.',
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
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isSelected = provider.selectedHuIds.contains(
                        item.handlingUnitId,
                      );

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB).withValues(
                                  alpha: context.isDark ? 0.12 : 0.05,
                                )
                              : context.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : context.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF2563EB),
                                  onChanged: (_) => provider.toggleHuSelection(
                                    item.handlingUnitId,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.lpn,
                                            style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              fontSize: 14,
                                            ),
                                          ),
                                          // Badge de Qualidade
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.isQualityRestricted
                                                  ? const Color(0xFFF59E0B)
                                                        .withValues(alpha: 0.15)
                                                  : const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: item.isQualityRestricted
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF10B981),
                                              ),
                                            ),
                                            child: Text(
                                              item.isQualityRestricted
                                                  ? item.qualityStatus
                                                  : 'Liberado',
                                              style: TextStyle(
                                                color: item.isQualityRestricted
                                                    ? const Color(0xFFF59E0B)
                                                    : const Color(0xFF10B981),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.productSku} - ${item.productDescription}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Detalhes fiscais e de lote
                            Padding(
                              padding: const EdgeInsets.only(left: 44),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Qtd: ${item.quantity.toStringAsFixed(0)} ${item.unit}',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    'Lote: ${item.batch ?? "SEM LOTE"}',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Posição Sugerida pelo WMS (com botão de trocar/bipar)
                            Padding(
                              padding: const EdgeInsets.only(left: 44),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.cardSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.map_pin,
                                      size: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                item.suggestedLocationFullPath,
                                                style: const TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _openLocationPicker(
                                                  context: context,
                                                  isQualityRestricted:
                                                      item.isQualityRestricted,
                                                  onSelected:
                                                      (
                                                        locId,
                                                        locPath,
                                                      ) => provider
                                                          .updateHuLocation(
                                                            item.handlingUnitId,
                                                            locId,
                                                            locPath,
                                                          ),
                                                ),
                                                child: const Icon(
                                                  LucideIcons.square_pen,
                                                  size: 13,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            item.suggestionReason,
                                            style: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // Rodapé com o botão "Confirmar e Gravar Alocação"
      bottomNavigationBar: selectedCount > 0
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                border: Border(top: BorderSide(color: context.border)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: provider.isSubmitting ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: provider.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(LucideIcons.circle_check, size: 18),
                    label: Text(
                      'Confirmar e Gravar Alocação ($selectedCount)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
