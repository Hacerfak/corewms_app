import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/yard_models.dart';
import 'widgets/yard_dialogs.dart';
import 'yard_provider.dart';

class YardManagementScreen extends StatefulWidget {
  const YardManagementScreen({super.key});

  @override
  State<YardManagementScreen> createState() => _YardManagementScreenState();
}

class _YardManagementScreenState extends State<YardManagementScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<YardProvider>().loadData();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;

      final clean = barcode.trim().toUpperCase();
      if (clean.isNotEmpty) {
        _searchController.text = clean;
        _handleCheckIn(clean);
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckIn(String code) async {
    final provider = context.read<YardProvider>();
    final result = await provider.executeCheckIn(
      codeOrPlate: code,
      currentSearch: _searchController.text.trim(),
    );

    if (mounted) {
      if (result != null) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              result['message'] ?? 'Entrada registrada com sucesso!',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        _searchController.clear();
      } else {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              provider.errorMessage ?? 'Não foi possível registrar a entrada.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openCamera() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Placa ou Reserva',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _searchController.text = code.toUpperCase();
      _handleCheckIn(code);
    }
  }

  Future<void> _openWalkInRegistration() async {
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const YardWalkInDialog(),
    );

    if (success == true && mounted) {
      context.read<YardProvider>().loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<YardProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Portaria & Pátio',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? LucideIcons.sun : LucideIcons.moon,
              color: context.textSecondary,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(LucideIcons.refresh_cw, color: context.textSecondary),
            onPressed: () => provider.loadData(search: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // CABEÇALHO (CHECK-IN RÁPIDO E ENTRADA AVULSA)
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
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: _handleCheckIn,
                        decoration: InputDecoration(
                          hintText: 'Bipar ou digitar placa...',
                          hintStyle: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            fontFamily: 'sans-serif',
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.scan_line,
                            color: Color(0xFF06B6D4),
                            size: 20,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.camera,
                                  color: Color(0xFF06B6D4),
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
                                    provider.loadData();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: provider.isSubmitting
                            ? null
                            : () => _handleCheckIn(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
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
                            : const Icon(
                                LucideIcons.log_in,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _openWalkInRegistration,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(
                      LucideIcons.truck,
                      size: 16,
                      color: Color(0xFF06B6D4),
                    ),
                    label: const Text(
                      'REGISTRAR VEÍCULO AVULSO',
                      style: TextStyle(
                        color: Color(0xFF06B6D4),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FILTROS DE STATUS (ABAS)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: context.cardSubtle,
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildStatusFilter(
                  context,
                  null,
                  'Todos',
                  provider.appointments.where((a) => !a.isCanceled).length,
                ),
                _buildStatusFilter(
                  context,
                  1,
                  'Agendados',
                  provider.scheduledCount,
                ),
                _buildStatusFilter(
                  context,
                  2,
                  'No Pátio',
                  provider.inYardCount,
                ),
                _buildStatusFilter(
                  context,
                  3,
                  'Nas Docas',
                  provider.inDockCount,
                ),
                _buildStatusFilter(
                  context,
                  4,
                  'Finalizados',
                  provider.finishedCount,
                ),
              ],
            ),
          ),

          // LISTAGEM DE AGENDAMENTOS
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  )
                : provider.filteredAppointments.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.parking_meter,
                            size: 56,
                            color: context.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum veículo nesta etapa',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: provider.filteredAppointments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final appt = provider.filteredAppointments[idx];
                      return _AppointmentCard(
                        appointment: appt,
                        provider: provider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(
    BuildContext context,
    int? status,
    String label,
    int count,
  ) {
    final provider = context.watch<YardProvider>();
    final isSelected = provider.statusFilter == status;
    final isDark = context.isDark;

    Color badgeColor;
    if (status == null) {
      badgeColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    } else if (status == 1) {
      badgeColor = const Color(0xFF64748B);
    } else if (status == 2) {
      badgeColor = const Color(0xFFF59E0B);
    } else if (status == 3) {
      badgeColor = const Color(0xFF2563EB);
    } else {
      badgeColor = const Color(0xFF10B981);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => provider.setStatusFilter(status),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? badgeColor : context.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? badgeColor : context.border),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : context.cardSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : context.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final YardAppointmentModel appointment;
  final YardProvider provider;

  const _AppointmentCard({required this.appointment, required this.provider});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (appointment.status) {
      case 2:
        statusColor = const Color(0xFFF59E0B);
        break;
      case 3:
        statusColor = const Color(0xFF2563EB);
        break;
      case 4:
        statusColor = const Color(0xFF10B981);
        break;
      default:
        statusColor = context.textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tipo e Placa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: statusColor.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      appointment.isInbound
                          ? LucideIcons.corner_right_down
                          : LucideIcons.corner_right_up,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appointment.vehiclePlate ?? 'SEM PLACA',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
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
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appointment.statusDescription,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Informações Básicas
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.user,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appointment.driverName ?? 'Motorista não informado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.building,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appointment.carrierName ??
                            'Transportadora não informada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vínculos da Ordem / Doca
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.cardSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            appointment.hasLinkedOrder
                                ? (appointment.isInbound
                                      ? 'Ordem Rec: #${appointment.inboundOrderNumber}'
                                      : 'Ordem Exp: #${appointment.outboundOrderNumber}')
                                : (appointment.invoiceNumber != null
                                      ? 'NF-e: ${appointment.invoiceNumber}'
                                      : 'Sem Vínculo'),
                            style: TextStyle(
                              color: appointment.hasLinkedOrder
                                  ? (appointment.isInbound
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF8B5CF6))
                                  : context.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          if (!appointment.hasLinkedOrder)
                            InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: context.card,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  builder: (_) => YardLinkOrderDialog(
                                    appointment: appointment,
                                  ),
                                );
                              },
                              child: const Text(
                                'Vincular Agora',
                                style: TextStyle(
                                  color: Color(0xFF06B6D4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.map_pin,
                            size: 14,
                            color: appointment.dockName != null
                                ? const Color(0xFF10B981)
                                : context.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            appointment.dockName ?? 'Doca não definida',
                            style: TextStyle(
                              color: appointment.dockName != null
                                  ? context.textPrimary
                                  : context.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Ações Rápidas do Cartão
          if (!appointment.isFinished && !appointment.isCanceled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.border)),
              ),
              child: Row(
                children: [
                  if (appointment.isScheduled) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.isSubmitting
                            ? null
                            : () => provider.executeCheckIn(
                                codeOrPlate: appointment.reservationCode,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(LucideIcons.log_in, size: 16),
                        label: const Text(
                          'Dar Entrada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (appointment.isInYard) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: context.card,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (_) => YardMoveToDockDialog(
                              appointmentId: appointment.id,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(LucideIcons.map_pin, size: 16),
                        label: const Text(
                          'Encostar na Doca',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (appointment.isInDock) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.isSubmitting
                            ? null
                            : () => provider.executeCheckOut(appointment.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(LucideIcons.log_out, size: 16),
                        label: const Text(
                          'Finalizar Saída',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
