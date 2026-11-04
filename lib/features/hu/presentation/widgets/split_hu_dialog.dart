import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/hu_models.dart';
import '../hu_provider.dart';

class SplitHuDialog extends StatefulWidget {
  final HandlingUnitModel hu;

  const SplitHuDialog({super.key, required this.hu});

  @override
  State<SplitHuDialog> createState() => _SplitHuDialogState();
}

class _SplitHuDialogState extends State<SplitHuDialog> {
  final _qtyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedPackagingTypeId;
  double _splitQty = 0;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _selectedPackagingTypeId = widget.hu.packagingTypeId;

    // Carrega apenas as embalagens vinculadas ao produto da HU
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HuProvider>().loadProductPackagings(widget.hu.productId);
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _onQtyChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    setState(() {
      _splitQty = parsed;
      _localError = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_splitQty <= 0) {
      setState(() => _localError = 'A quantidade deve ser superior a zero.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_splitQty >= widget.hu.currentQuantity) {
      setState(
        () => _localError =
            'Não é permitido transferir o saldo total (${widget.hu.currentQuantity.toStringAsFixed(0)}). Utilize Mover ou Merge.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<HuProvider>();
    final result = await provider.executeSplit(
      quantity: _splitQty,
      packagingTypeId: _selectedPackagingTypeId,
    );

    if (!mounted) return;

    if (result != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(result);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HuProvider>();
    final isDark = context.isDark;

    final maxAvailable = widget.hu.currentQuantity;
    final remainingAfterSplit = maxAvailable - _splitQty;

    final productPacks = provider.productPackagings;
    if (_selectedPackagingTypeId == null && productPacks.isNotEmpty) {
      final match = productPacks.firstWhere(
        (p) => p.packagingTypeId == widget.hu.packagingTypeId,
        orElse: () => productPacks.first,
      );
      _selectedPackagingTypeId = match.packagingTypeId;
    }

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.split,
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
                          'Split de HU (Transbordo)',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Desmembrar saldo numa nova HU filha',
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

              // Dados da HU Mãe
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HU Origem (Mãe):',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          widget.hu.lpn,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saldo Atual:',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${widget.hu.currentQuantity.toStringAsFixed(0)} ${widget.hu.productBaseUnit}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Posição:',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          widget.hu.currentLocationPath,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (widget.hu.batch != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lote a herdar:',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            widget.hu.batch!,
                            style: TextStyle(
                              color: context.textSecondary,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mensagem de Erro
              if (_localError != null || provider.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF450A0A)
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF991B1B)
                          : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Text(
                    _localError ?? provider.errorMessage ?? '',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFBE123C),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Campo de Quantidade
              TextFormField(
                controller: _qtyController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                onChanged: _onQtyChanged,
                decoration: InputDecoration(
                  labelText: 'Quantidade para a Nova HU',
                  labelStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                  ),
                  suffixText: widget.hu.productBaseUnit,
                  suffixStyle: TextStyle(
                    color: context.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: context.cardSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.border),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe a quantidade';
                  }
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Quantidade inválida';
                  if (val >= maxAvailable) {
                    return 'Deve ser inferior a ${maxAvailable.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Seletor de Embalagens cadastradas no Produto
              DropdownButtonFormField<String>(
                initialValue:
                    productPacks.any(
                      (p) => p.packagingTypeId == _selectedPackagingTypeId,
                    )
                    ? _selectedPackagingTypeId
                    : null,
                isExpanded: true,
                dropdownColor: context.card,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Embalagem do Produto',
                  labelStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                  helperText: productPacks.isEmpty
                      ? 'A carregar embalagens do produto...'
                      : null,
                  helperStyle: TextStyle(
                    color: context.textMuted,
                    fontSize: 10,
                  ),
                  filled: true,
                  fillColor: context.cardSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.border),
                  ),
                ),
                items: productPacks.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.packagingTypeId,
                    child: Text(
                      '${p.code} - ${p.description} (${p.conversionFactor.toStringAsFixed(0)} ${widget.hu.productBaseUnit})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedPackagingTypeId = val),
              ),
              const SizedBox(height: 12),

              // Indicador Visual de Balanço de Saldo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: remainingAfterSplit > 0
                      ? context.cardSubtle
                      : (isDark
                            ? const Color(0xFF450A0A)
                            : const Color(0xFFFFF1F2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: remainingAfterSplit > 0
                        ? context.border
                        : (isDark
                              ? const Color(0xFF991B1B)
                              : const Color(0xFFFECDD3)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo Restante na Mãe:',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${remainingAfterSplit >= 0 ? remainingAfterSplit.toStringAsFixed(0) : "0"} ${widget.hu.productBaseUnit}',
                      style: TextStyle(
                        color: remainingAfterSplit > 0
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.isSplitting
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
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: provider.isSplitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: provider.isSplitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CONFIRMAR SPLIT',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
