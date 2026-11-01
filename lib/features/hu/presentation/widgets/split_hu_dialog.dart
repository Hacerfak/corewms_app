import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      setState(() => _localError = 'A quantidade deve ser maior que zero.');
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
    final maxAvailable = widget.hu.currentQuantity;
    final remainingAfterSplit = maxAvailable - _splitQty;

    // Se o tipo da HU mãe existir na lista do produto, pré-seleciona
    final productPacks = provider.productPackagings;
    if (_selectedPackagingTypeId == null && productPacks.isNotEmpty) {
      final match = productPacks.firstWhere(
        (p) => p.packagingTypeId == widget.hu.packagingTypeId,
        orElse: () => productPacks.first,
      );
      _selectedPackagingTypeId = match.packagingTypeId;
    }

    return Dialog(
      backgroundColor: const Color(0xFF1E293B), // Slate 800
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
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.call_split_rounded,
                      color: Color(0xFFA78BFA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Split de HU (Transbordo)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Desmembrar saldo em uma nova HU filha',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'HU Origem (Mãe):',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          widget.hu.lpn,
                          style: const TextStyle(
                            color: Colors.white,
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
                        const Text(
                          'Saldo Atual:',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
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
                        const Text(
                          'Posição:',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          widget.hu.currentLocationPath,
                          style: const TextStyle(
                            color: Colors.white70,
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
                          const Text(
                            'Lote a herdar:',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            widget.hu.batch!,
                            style: const TextStyle(
                              color: Colors.white70,
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
                    color: const Color(0xFF450A0A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF991B1B)),
                  ),
                  child: Text(
                    _localError ?? provider.errorMessage ?? '',
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                onChanged: _onQtyChanged,
                decoration: InputDecoration(
                  labelText: 'Quantidade para a Nova HU',
                  labelStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  suffixText: widget.hu.productBaseUnit,
                  suffixStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe a quantidade';
                  }
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Quantidade inválida';
                  if (val >= maxAvailable) {
                    return 'Deve ser menor que ${maxAvailable.toStringAsFixed(0)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Seletor de Embalagens cadastradas no Produto
              DropdownButtonFormField<String>(
                value:
                    productPacks.any(
                      (p) => p.packagingTypeId == _selectedPackagingTypeId,
                    )
                    ? _selectedPackagingTypeId
                    : null,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Embalagem do Produto',
                  labelStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  helperText: productPacks.isEmpty
                      ? 'Carregando embalagens do produto...'
                      : null,
                  helperStyle: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: productPacks.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.packagingTypeId,
                    child: Text(
                      '${p.code} - ${p.description} (${p.conversionFactor.toStringAsFixed(0)} ${widget.hu.productBaseUnit})',
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
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Saldo Restante na Mãe:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Text(
                      '${remainingAfterSplit >= 0 ? remainingAfterSplit.toStringAsFixed(0) : "0"} ${widget.hu.productBaseUnit}',
                      style: TextStyle(
                        color: remainingAfterSplit > 0
                            ? const Color(0xFF38BDF8)
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
                        side: const BorderSide(color: Color(0xFF475569)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
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
                                color: Colors.white,
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
