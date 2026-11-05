import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/packing_models.dart';
import '../packing_provider.dart';

class FinalizePackingDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const FinalizePackingDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<FinalizePackingDialog> createState() => _FinalizePackingDialogState();
}

class _FinalizePackingDialogState extends State<FinalizePackingDialog> {
  String? _selectedDockId;
  String? _selectedHandlingServiceId;
  bool _usedStretchFilm = false;

  final List<ShippingVolumeEntry> _shippingVolumes = [];
  final _volCountController = TextEditingController(text: '1');
  final _weightController = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PackingProvider>();
    if (provider.docks.isNotEmpty) {
      _selectedDockId = provider.docks.first.id;
    }
    // Cria 1 volume padrão inicial
    _shippingVolumes.add(
      ShippingVolumeEntry(
        packagingTypeId: provider.docks.isNotEmpty
            ? provider.docks.first.id
            : '',
        packagingCode: 'VOL',
        volumeCount: 1,
      ),
    );
  }

  @override
  void dispose() {
    _volCountController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedDockId == null || _selectedDockId!.isEmpty) {
      setState(() => _localError = 'Selecione a Doca de Embarque.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_shippingVolumes.isEmpty) {
      setState(
        () => _localError = 'Informe ao menos um volume final de transporte.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<PackingProvider>();
    final success = await provider.finalizePacking(
      orderId: widget.orderId,
      dockLocationId: _selectedDockId!,
      usedStretchFilm: _usedStretchFilm,
      shippingVolumes: _shippingVolumes,
      handlingServiceId: _selectedHandlingServiceId,
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
                    color: const Color(0xFF10B981)
                        .withValues(alpha: context.isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.warehouse,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finalizar Embalagem (Packing)',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pedido #${widget.orderNumber} • Envio para Doca',
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

            // 1. Doca de Embarque Destino
            DropdownButtonFormField<String>(
              initialValue: _selectedDockId,
              isExpanded: true,
              dropdownColor: context.card,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Doca de Embarque Destino *',
              ),
              items: provider.docks.map((d) {
                return DropdownMenuItem(value: d.id, child: Text(d.fullPath));
              }).toList(),
              onChanged: (v) => setState(() => _selectedDockId = v),
            ),
            const SizedBox(height: 12),

            // 2. Serviço de Handling (Cobrança)
            if (provider.billingServices.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedHandlingServiceId,
                isExpanded: true,
                dropdownColor: context.card,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Serviço de Expedição (Opcional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Nenhum serviço cobrado'),
                  ),
                  ...provider.billingServices.map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _selectedHandlingServiceId = v),
              ),
              const SizedBox(height: 12),
            ],

            // 3. Filme Stretch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: const Color(0xFF8B5CF6),
              title: Text(
                'Utilizou Filme Stretch?',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Aplica taxa operacional de embalagem',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
              value: _usedStretchFilm,
              onChanged: (val) => setState(() => _usedStretchFilm = val),
            ),
            const SizedBox(height: 12),

            // 4. Quantidade de Volumes Finais
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _volCountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Total Volumes Finais',
                    ),
                    onChanged: (v) {
                      final count = int.tryParse(v) ?? 1;
                      if (_shippingVolumes.isNotEmpty) {
                        _shippingVolumes.first.volumeCount = count;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso Bruto (kg)',
                      suffixText: 'kg',
                    ),
                    onChanged: (v) {
                      final w = double.tryParse(v.replaceAll(',', '.'));
                      if (_shippingVolumes.isNotEmpty) {
                        _shippingVolumes.first.grossWeight = w;
                      }
                    },
                  ),
                ),
              ],
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
                    onPressed: provider.isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
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
                            'FINALIZAR & ENVIAR',
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
