import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/yard_models.dart';
import '../yard_provider.dart';

/// Formatador automático de CPF (000.000.000-00)
class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ==========================================
// 1. DIÁLOGO DE REGISTRO AVULSO (WALK-IN)
// ==========================================
class YardWalkInDialog extends StatefulWidget {
  const YardWalkInDialog({super.key});

  @override
  State<YardWalkInDialog> createState() => _YardWalkInDialogState();
}

class _YardWalkInDialogState extends State<YardWalkInDialog> {
  final _plateController = TextEditingController();
  final _driverController = TextEditingController();
  final _cpfController = TextEditingController();
  final _carrierController = TextEditingController();

  int _type = 1; // 1 = Inbound (Descarga), 2 = Outbound (Carga)
  String? _localError;

  @override
  void dispose() {
    _plateController.dispose();
    _driverController.dispose();
    _cpfController.dispose();
    _carrierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      setState(() => _localError = 'A placa do veículo é obrigatória.');
      HapticFeedback.heavyImpact();
      return;
    }

    final cpfDigits = _cpfController.text.replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.isNotEmpty && cpfDigits.length != 11) {
      setState(() => _localError = 'Informe um CPF válido com 11 dígitos.');
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<YardProvider>();
    final res = await provider.createWalkInAppointment(
      type: _type,
      scheduledDate: DateTime.now(),
      vehiclePlate: plate,
      driverName: _driverController.text,
      driverCpf: _cpfController.text,
      carrierName: _carrierController.text,
      directCheckIn: true,
    );

    if (!mounted) return;

    if (res != null) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(res['message'] ?? 'Veículo registrado no pátio!'),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YardProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
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
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.truck,
                        color: Color(0xFF06B6D4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar Veículo Avulso',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Entrada direta no pátio (Check-in imediato)',
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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

            // Seletor tátil de Tipo de Operação
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    context: context,
                    value: 1,
                    label: 'Descarga (Entrada)',
                    icon: LucideIcons.corner_right_down,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeOption(
                    context: context,
                    value: 2,
                    label: 'Carga (Saída)',
                    icon: LucideIcons.corner_right_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Placa do Veículo *',
                hintText: 'Ex: ABC1D23',
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _driverController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Nome do Motorista'),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _cpfController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [_CpfInputFormatter()],
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                labelText: 'CPF do Motorista',
                hintText: '000.000.000-00',
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _carrierController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Transportadora'),
            ),
            const SizedBox(height: 18),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: provider.isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
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
                        'REGISTRAR ENTRADA NO PÁTIO',
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
    );
  }

  Widget _buildTypeOption({
    required BuildContext context,
    required int value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _type == value;
    const activeColor = Color(0xFF06B6D4);

    return InkWell(
      onTap: () => setState(() => _type = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.14)
              : context.cardSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : context.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? activeColor : context.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. DIÁLOGO ENCOSTAR NA DOCA
// ==========================================
class YardMoveToDockDialog extends StatefulWidget {
  final String appointmentId;

  const YardMoveToDockDialog({super.key, required this.appointmentId});

  @override
  State<YardMoveToDockDialog> createState() => _YardMoveToDockDialogState();
}

class _YardMoveToDockDialogState extends State<YardMoveToDockDialog> {
  String? _selectedDockId;
  String? _localError;

  Future<void> _submit() async {
    if (_selectedDockId == null || _selectedDockId!.isEmpty) {
      setState(() => _localError = 'Selecione uma doca física.');
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<YardProvider>();
    final success = await provider.executeMoveToDock(
      appointmentId: widget.appointmentId,
      dockLocationId: _selectedDockId!,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Veículo posicionado na doca com sucesso!'),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YardProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              Text(
                'Encostar na Doca',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.x,
                  color: context.textSecondary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_localError != null || provider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _localError ?? provider.errorMessage ?? '',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
          ],

          DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: context.card,
            style: TextStyle(
              color: context.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(labelText: 'Selecione a Doca *'),
            items: provider.docks.map((d) {
              return DropdownMenuItem(value: d.id, child: Text(d.fullPath));
            }).toList(),
            onChanged: (v) => setState(() => _selectedDockId = v),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: provider.isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
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
                      'CONFIRMAR ENCOSTE',
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
  }
}

// ==========================================
// 3. DIÁLOGO VINCULAR ORDEM (RECEBIMENTO / EXPEDIÇÃO)
// ==========================================
class YardLinkOrderDialog extends StatefulWidget {
  final YardAppointmentModel appointment;

  const YardLinkOrderDialog({super.key, required this.appointment});

  @override
  State<YardLinkOrderDialog> createState() => _YardLinkOrderDialogState();
}

class _YardLinkOrderDialogState extends State<YardLinkOrderDialog> {
  String? _selectedOrderId;
  List<AvailableOrderLinkItem> _availableOrders = [];
  bool _isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
  }

  Future<void> _loadAvailableOrders() async {
    final provider = context.read<YardProvider>();
    final orders = await provider.loadAvailableOrders(widget.appointment.type);
    if (mounted) {
      setState(() {
        _availableOrders = orders;
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedOrderId == null) {
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<YardProvider>();
    final success = await provider.executeLinkOrder(
      appointmentId: widget.appointment.id,
      type: widget.appointment.type,
      orderId: _selectedOrderId!,
    );

    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Ordem vinculada com sucesso!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YardProvider>();
    final color = widget.appointment.isInbound
        ? const Color(0xFF2563EB)
        : const Color(0xFF8B5CF6);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              Text(
                widget.appointment.isInbound
                    ? 'Vincular Ordem de Recebimento'
                    : 'Vincular Ordem de Expedição',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  LucideIcons.x,
                  color: context.textSecondary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoadingOrders)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: CircularProgressIndicator(color: color),
            )
          else if (_availableOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cardSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.border),
              ),
              child: Text(
                'Nenhuma ordem aberta sem vínculo no momento.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.separated(
                itemCount: _availableOrders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final order = _availableOrders[idx];
                  final isSelected = _selectedOrderId == order.id;

                  return InkWell(
                    onTap: () => setState(() => _selectedOrderId = order.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : context.cardSubtle,
                        border: Border.all(
                          color: isSelected ? color : context.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? LucideIcons.circle_check
                                : LucideIcons.circle,
                            color: isSelected ? color : context.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.appointment.isInbound
                                      ? (order.invoiceNumber != null
                                            ? 'NF-e: ${order.invoiceNumber}'
                                            : 'Sem NF')
                                      : 'Pedido #${order.orderNumber}',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  order.customerOrDestinationName ?? '',
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
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_selectedOrderId == null || provider.isSubmitting)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
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
                      'VINCULAR ORDEM',
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
  }
}
