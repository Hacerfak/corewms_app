import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/cycle_count_models.dart';
import 'blind_location_count_screen.dart';
import 'cycle_count_provider.dart';

class CycleCountListScreen extends StatefulWidget {
  const CycleCountListScreen({super.key});

  @override
  State<CycleCountListScreen> createState() => _CycleCountListScreenState();
}

class _CycleCountListScreenState extends State<CycleCountListScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CycleCountProvider>().loadLocations();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      _handleScannedBarcode(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScannedBarcode(String code) {
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();

    final provider = context.read<CycleCountProvider>();
    final match = provider.locations.where(
      (l) => l.locationPath.toUpperCase() == code.toUpperCase(),
    );

    if (match.isNotEmpty) {
      _openLocationCount(match.first);
    } else {
      _searchController.text = code;
      setState(() {});
    }
  }

  Future<void> _openLocationCount(BlindLocationTaskModel loc) async {
    final provider = context.read<CycleCountProvider>();
    final started = await provider.startCounting(loc.planId, loc.locationId);
    if (!mounted) return;

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            provider.errorMessage ?? 'Não foi possível iniciar contagem.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlindLocationCountScreen(locationTask: loc),
      ),
    );

    if (mounted) {
      provider.loadLocations();
    }
  }

  Future<void> _openSpontaneousDialog() async {
    final inputController = TextEditingController();
    final List<String> selectedLocations = [];
    String? localError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final provider = ctx.watch<CycleCountProvider>();

            void addLocationCode(String raw) {
              final clean = raw.trim().toUpperCase();
              if (clean.isEmpty) return;
              if (!selectedLocations.contains(clean)) {
                setModalState(() {
                  selectedLocations.add(clean);
                  inputController.clear();
                  localError = null;
                });
                HapticFeedback.lightImpact();
              } else {
                inputController.clear();
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LucideIcons.eye_off,
                              color: Color(0xFFEC4899),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inventário Espontâneo',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Bipe 1 ou mais endereços para bloquear e contar',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (localError != null || provider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        localError ?? provider.errorMessage ?? '',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: inputController,
                          autofocus: true,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: addLocationCode,
                          decoration: InputDecoration(
                            hintText: 'Bipar ou digitar Endereço...',
                            prefixIcon: const Icon(
                              LucideIcons.map_pin,
                              color: Color(0xFFEC4899),
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                LucideIcons.camera,
                                color: Color(0xFFEC4899),
                                size: 18,
                              ),
                              onPressed: () async {
                                final code = await QrScannerDialog.scan(
                                  ctx,
                                  title: 'Bipar Endereço',
                                );
                                if (code != null && code.isNotEmpty) {
                                  addLocationCode(code);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              addLocationCode(inputController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(LucideIcons.plus, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Endereços Selecionados (${selectedLocations.length}):',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selectedLocations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cardSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.border),
                      ),
                      child: Center(
                        child: Text(
                          'Nenhum endereço adicionado ainda.',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedLocations.map((loc) {
                        return Chip(
                          backgroundColor: const Color(0xFFEC4899)
                              .withValues(alpha: 0.15),
                          side: BorderSide(
                            color: const Color(0xFFEC4899)
                                .withValues(alpha: 0.4),
                          ),
                          label: Text(
                            loc,
                            style: const TextStyle(
                              color: Color(0xFFEC4899),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          deleteIcon: const Icon(
                            LucideIcons.x,
                            size: 14,
                            color: Color(0xFFEC4899),
                          ),
                          onDeleted: () {
                            setModalState(() => selectedLocations.remove(loc));
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed:
                          (provider.isSubmitting || selectedLocations.isEmpty)
                          ? null
                          : () async {
                              final ok = await provider.startSpontaneousCount(
                                selectedLocations,
                              );
                              if (ok) {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF10B981),
                                      content: Text(
                                        'Plano espontâneo criado e endereços bloqueados para contagem!',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEC4899),
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
                          : const Icon(LucideIcons.lock, size: 18),
                      label: const Text(
                        'BLOQUEAR ENDEREÇOS E INICIAR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CycleCountProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final search = _searchController.text.trim().toLowerCase();

    final filtered = provider.locations.where((l) {
      if (search.isEmpty) return true;
      return l.locationPath.toLowerCase().contains(search) ||
          l.planName.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventário Cego (Auditoria)',
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
            onPressed: () => provider.loadLocations(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Pesquisa & Botão de Contagem Espontânea
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.card,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _searchController,
                  style: TextStyle(color: context.textPrimary, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Bipar ou filtrar Endereço...',
                    prefixIcon: const Icon(
                      LucideIcons.scan_line,
                      color: Color(0xFFEC4899),
                      size: 18,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            LucideIcons.camera,
                            color: Color(0xFFEC4899),
                            size: 18,
                          ),
                          onPressed: () async {
                            final code = await QrScannerDialog.scan(
                              context,
                              title: 'Bipar Endereço',
                            );
                            if (code != null && code.isNotEmpty) {
                              _handleScannedBarcode(code);
                            }
                          },
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _openSpontaneousDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.circle_plus, size: 18),
                    label: const Text(
                      'INICIAR CONTAGEM ESPONTÂNEA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista Exclusiva de Endereços (Zero Exposição de Produtos)
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFEC4899)),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.eye_off,
                            size: 56,
                            color: context.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum endereço pendente de contagem',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toque em "Iniciar Contagem Espontânea" acima para auditar qualquer posição.',
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
                      final loc = filtered[idx];
                      final isCounting = loc.status == 'InCounting';

                      return Material(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openLocationCount(loc),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCounting
                                    ? const Color(0xFFF59E0B)
                                    : context.border,
                                width: isCounting ? 1.5 : 1,
                              ),
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
                                          LucideIcons.map_pin,
                                          color: Color(0xFFEC4899),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          loc.locationPath,
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 16,
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
                                        color: const Color(0xFFEC4899)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFEC4899)
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        'Rodada ${loc.currentRound}',
                                        style: const TextStyle(
                                          color: Color(0xFFEC4899),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  loc.planName,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Divider(color: context.border, height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isCounting
                                          ? 'Em andamento...'
                                          : 'Contagem Cega (Oculta)',
                                      style: TextStyle(
                                        color: isCounting
                                            ? const Color(0xFFF59E0B)
                                            : context.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Row(
                                      children: [
                                        Text(
                                          'Contar Posição',
                                          style: TextStyle(
                                            color: Color(0xFFEC4899),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          LucideIcons.chevron_right,
                                          size: 16,
                                          color: Color(0xFFEC4899),
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
