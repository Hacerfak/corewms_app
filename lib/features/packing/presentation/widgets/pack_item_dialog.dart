import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../hu/data/hu_models.dart';
import '../../data/packing_models.dart';
import '../packing_provider.dart';

class PackItemDialog extends StatefulWidget {
  final String orderId;
  final PackingOrderItemModel item;

  const PackItemDialog({super.key, required this.orderId, required this.item});

  @override
  State<PackItemDialog> createState() => _PackItemDialogState();
}

class _PackItemDialogState extends State<PackItemDialog> {
  final List<ItemPackEntry> _entries = [];
  List<ProductPackagingOption> _availablePacks = [];
  bool _isLoadingPacks = true;
  String? _localError;

  // Controladores da nova linha
  String? _selectedPackagingTypeId;
  final _volumeCountController = TextEditingController(text: '1');
  final _qtyPerVolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _volumeCountController.dispose();
    _qtyPerVolController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<PackingProvider>();
    final results = await Future.wait([
      provider.loadProductPackagings(widget.item.productId),
      provider.loadItemPacks(widget.orderId, widget.item.id),
    ]);

    if (!mounted) return;

    setState(() {
      _availablePacks = results[0] as List<ProductPackagingOption>;
      final existing = results[1] as List<ItemPackEntry>;
      if (existing.isNotEmpty) {
        _entries.addAll(existing);
      } else if (_availablePacks.isNotEmpty) {
        _selectedPackagingTypeId = _availablePacks.first.packagingTypeId;
        _qtyPerVolController.text = _availablePacks.first.conversionFactor
            .toStringAsFixed(0);
      }
      _isLoadingPacks = false;
    });
  }

  void _onPackagingChanged(String? val) {
    setState(() {
      _selectedPackagingTypeId = val;
      if (val != null) {
        final pack = _availablePacks.firstWhere(
          (p) => p.packagingTypeId == val,
        );
        _qtyPerVolController.text = pack.conversionFactor.toStringAsFixed(0);
      }
    });
  }

  void _addPackLine() {
    if (_selectedPackagingTypeId == null) {
      setState(() => _localError = 'Selecione o tipo de embalagem.');
      HapticFeedback.heavyImpact();
      return;
    }

    final volCount = int.tryParse(_volumeCountController.text.trim()) ?? 0;
    final qtyPerVol =
        double.tryParse(
          _qtyPerVolController.text.trim().replaceAll(',', '.'),
        ) ??
        0;

    if (volCount <= 0 || qtyPerVol <= 0) {
      setState(
        () => _localError =
            'Volumes e peças por volume devem ser maiores que zero.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final pack = _availablePacks.firstWhere(
      (p) => p.packagingTypeId == _selectedPackagingTypeId,
    );

    setState(() {
      _entries.add(
        ItemPackEntry(
          packagingTypeId: pack.packagingTypeId,
          packagingCode: pack.code,
          volumeCount: volCount,
          quantityPerVolume: qtyPerVol,
        ),
      );
      _localError = null;
    });
    HapticFeedback.lightImpact();
  }

  void _removeLine(int index) {
    setState(() {
      _entries.removeAt(index);
      _localError = null;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _submit() async {
    final totalPointed = _entries.fold(0.0, (s, e) => s + e.totalPieces);
    final target = widget.item.pickedQuantity;

    if (totalPointed != target) {
      setState(
        () => _localError =
            'Total apontado (${totalPointed.toStringAsFixed(0)}) difere da quantidade separada (${target.toStringAsFixed(0)} ${widget.item.unit}).',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<PackingProvider>();
    final success = await provider.packItem(
      orderId: widget.orderId,
      orderItemId: widget.item.id,
      packs: _entries,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PackingProvider>();
    final target = widget.item.pickedQuantity;
    final totalPointed = _entries.fold(0.0, (s, e) => s + e.totalPieces);
    final isMatch = totalPointed == target;

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6)
                        .withValues(alpha: context.isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.package_search,
                    color: Color(0xFF8B5CF6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Embalagem do Item',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.item.skuCode} - ${widget.item.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Balanço da Meta
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMatch
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMatch
                      ? const Color(0xFF10B981)
                      : const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Qtd Separada (Meta)',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${target.toStringAsFixed(0)} ${widget.item.unit}',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Container(height: 28, width: 1, color: context.border),
                  Column(
                    children: [
                      Text(
                        'Total Embalado',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalPointed.toStringAsFixed(0)} ${widget.item.unit}',
                        style: TextStyle(
                          color: isMatch
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_localError != null || provider.errorMessage != null) ...[
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
                  _localError ?? provider.errorMessage ?? '',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Seletor de Embalagem e Inclusão de Linha
            if (_isLoadingPacks)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPackagingTypeId,
                isExpanded: true,
                dropdownColor: context.card,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Embalagem',
                ),
                items: _availablePacks.map((p) {
                  return DropdownMenuItem(
                    value: p.packagingTypeId,
                    child: Text(
                      '${p.code} - ${p.description} (Fator: ${p.conversionFactor.toStringAsFixed(0)})',
                    ),
                  );
                }).toList(),
                onChanged: _onPackagingChanged,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _volumeCountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Qtd Volumes',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'x',
                      style: TextStyle(
                        color: context.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyPerVolController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(labelText: 'Peças/Vol'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addPackLine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(LucideIcons.plus, size: 18),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Lista de Linhas Apontadas
            Text(
              'Composição dos Volumes (${_entries.length})',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (_entries.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Nenhuma embalagem adicionada.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, idx) {
                  final entry = _entries[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${entry.volumeCount}x ${entry.packagingCode} (${entry.quantityPerVolume.toStringAsFixed(0)} un)',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '= ${entry.totalPieces.toStringAsFixed(0)} ${widget.item.unit}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.trash,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              onPressed: () => _removeLine(idx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (!isMatch || provider.isSubmitting)
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: provider.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'SALVAR EMBALAGEM',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
