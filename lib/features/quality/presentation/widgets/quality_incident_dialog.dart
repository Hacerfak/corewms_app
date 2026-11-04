import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/scanner/qr_scanner_dialog.dart';
import '../../../../core/scanner/scanner_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../hu/data/hu_models.dart';
import '../../../hu/presentation/hu_provider.dart';
import '../../data/quality_models.dart';
import '../quality_provider.dart';

class QualityIncidentDialog extends StatefulWidget {
  final String title;
  final Widget? headerSummary;
  final bool showLocationTransfer;
  final Future<bool> Function(QualityIncidentData data)? onConfirm;

  const QualityIncidentDialog({
    super.key,
    this.title = 'Apontamento de Qualidade',
    this.headerSummary,
    this.showLocationTransfer = true,
    this.onConfirm,
  });

  @override
  State<QualityIncidentDialog> createState() => _QualityIncidentDialogState();
}

class _QualityIncidentDialogState extends State<QualityIncidentDialog> {
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  StreamSubscription<String>? _scanSubscription;

  QualityStatusTarget _selectedStatus = QualityStatusTarget.damaged;
  String? _selectedReasonId;
  bool _shouldMoveToLocation = false;
  LocationModel? _resolvedLocation;
  bool _isResolvingLocation = false;
  String? _localError;

  final List<QualityImageAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QualityProvider>().loadReasons();
    });

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted || !_shouldMoveToLocation) return;
      _locationController.text = barcode.trim();
      _resolveLocation(barcode.trim());
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _attachments.add(
          QualityImageAttachment(
            fileName: file.name.isNotEmpty
                ? file.name
                : 'evidencia_${DateTime.now().millisecondsSinceEpoch}.jpg',
            base64Data: base64String,
            previewBytes: bytes,
          ),
        );
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _localError = 'Não foi possível capturar a imagem.');
    }
  }

  Future<void> _openCameraScannerLocation() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar Posição de Qualidade',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _locationController.text = code;
      _resolveLocation(code);
    }
  }

  Future<void> _resolveLocation(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;

    setState(() {
      _isResolvingLocation = true;
      _localError = null;
    });

    try {
      final location = await context.read<HuProvider>().findLocation(clean);
      if (!mounted) return;

      if (location == null) {
        setState(() {
          _resolvedLocation = null;
          _isResolvingLocation = false;
          _localError = 'Endereço "$clean" não cadastrado na Topologia.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() {
        _resolvedLocation = location;
        _isResolvingLocation = false;
        _localError = null;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedLocation = null;
        _isResolvingLocation = false;
        _localError = e.toString().replaceAll('Exception: ', '');
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedReasonId == null) {
      setState(() => _localError = 'Selecione o motivo da ocorrência.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_shouldMoveToLocation && _resolvedLocation == null) {
      setState(() => _localError = 'Bipe ou valide o endereço de destino.');
      HapticFeedback.heavyImpact();
      return;
    }

    final qualityProvider = context.read<QualityProvider>();
    final reasonObj = qualityProvider.reasons.firstWhere(
      (r) => r.id == _selectedReasonId,
      orElse: () => QualityReasonModel(
        id: _selectedReasonId!,
        code: 'OUTRO',
        description: '',
        isActive: true,
      ),
    );

    final incidentData = QualityIncidentData(
      status: _selectedStatus,
      reasonId: _selectedReasonId!,
      reasonCode: reasonObj.code,
      notes: _notesController.text.trim(),
      targetLocationId: _shouldMoveToLocation ? _resolvedLocation?.id : null,
      targetLocationPath: _shouldMoveToLocation
          ? _resolvedLocation?.fullPath
          : null,
      images: _attachments,
    );

    if (widget.onConfirm != null) {
      final success = await widget.onConfirm!(incidentData);
      if (!mounted) return;
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(incidentData);
      } else {
        HapticFeedback.heavyImpact();
      }
    } else {
      Navigator.of(context).pop(incidentData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qualityProvider = context.watch<QualityProvider>();
    final reasons = qualityProvider.reasons;
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
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
                      color: const Color(0xFFF59E0B)
                          .withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.shield_alert,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Avaria física, retenção e bloqueios',
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
              const SizedBox(height: 14),

              if (widget.headerSummary != null) ...[
                widget.headerSummary!,
                const SizedBox(height: 14),
              ],

              // Alerta de Erro
              if (_localError != null ||
                  qualityProvider.errorMessage != null) ...[
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
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circle_alert,
                        size: 16,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFE11D48),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localError ?? qualityProvider.errorMessage ?? '',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFBE123C),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Tipo de Bloqueio
              Text(
                'Tipo de Ocorrência',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusRadio(
                      context: context,
                      target: QualityStatusTarget.damaged,
                      icon: LucideIcons.bomb,
                      activeColor: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusRadio(
                      context: context,
                      target: QualityStatusTarget.quarantine,
                      icon: LucideIcons.lock,
                      activeColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Motivo da Ocorrência
              DropdownButtonFormField<String>(
                initialValue: _selectedReasonId,
                isExpanded: true,
                dropdownColor: context.card,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Motivo da Ocorrência *',
                  labelStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
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
                items: reasons.map((r) {
                  final label =
                      r.description.isNotEmpty && r.description != r.code
                      ? '${r.code} - ${r.description}'
                      : r.code;

                  return DropdownMenuItem<String>(
                    value: r.id,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedReasonId = val),
                validator: (v) => v == null ? 'Selecione o motivo' : null,
              ),
              const SizedBox(height: 12),

              // 3. Descrição / Observações
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 500,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Descrição detalhada do problema *',
                  labelStyle: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                  hintText: 'Ex: Caixa rompida, produto avariado no palete...',
                  hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a descrição da ocorrência'
                    : null,
              ),
              const SizedBox(height: 8),

              // 4. Movimentação Opcional Integrada
              if (widget.showLocationTransfer) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFF59E0B),
                  title: Text(
                    'Transferir para Posição de Qualidade',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Move fisicamente para a área de quarentena/avarias',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  value: _shouldMoveToLocation,
                  onChanged: (val) => setState(() {
                    _shouldMoveToLocation = val;
                    if (!val) _resolvedLocation = null;
                  }),
                ),
                if (_shouldMoveToLocation) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locationController,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: _resolveLocation,
                    decoration: InputDecoration(
                      labelText: 'Bipe ou digite o Endereço de Qualidade',
                      labelStyle: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        LucideIcons.scan,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              LucideIcons.camera,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB),
                              size: 18,
                            ),
                            onPressed: _openCameraScannerLocation,
                          ),
                          if (_isResolvingLocation)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(
                                LucideIcons.arrow_right,
                                color: Color(0xFFF59E0B),
                                size: 18,
                              ),
                              onPressed: () =>
                                  _resolveLocation(_locationController.text),
                            ),
                        ],
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
                  ),
                  if (_resolvedLocation != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B)
                            .withValues(alpha: isDark ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF059669)
                              : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.circle_check,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Destino: ${_resolvedLocation!.fullPath}',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ],

              // 5. Fotos / Evidências
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotos / Evidências (${_attachments.length})',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          LucideIcons.camera,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                        tooltip: 'Tirar Foto com a Câmara',
                        onPressed: () => _takePhoto(ImageSource.camera),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.image,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                        tooltip: 'Selecionar da Galeria',
                        onPressed: () => _takePhoto(ImageSource.gallery),
                      ),
                    ],
                  ),
                ],
              ),

              if (_attachments.isNotEmpty) ...[
                SizedBox(
                  height: 75,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final item = _attachments[idx];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              item.previewBytes,
                              width: 75,
                              height: 75,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _attachments.removeAt(idx)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.x,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Botões Finais
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: qualityProvider.isSubmitting
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
                      onPressed: qualityProvider.isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: qualityProvider.isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CONFIRMAR OCORRÊNCIA',
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

  Widget _buildStatusRadio({
    required BuildContext context,
    required QualityStatusTarget target,
    required IconData icon,
    required Color activeColor,
  }) {
    final isDark = context.isDark;
    final isSelected = _selectedStatus == target;

    return InkWell(
      onTap: () => setState(() => _selectedStatus = target),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : context.cardSubtle,
          border: Border.all(color: isSelected ? activeColor : context.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : context.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                target.label,
                style: TextStyle(
                  color: isSelected
                      ? context.textPrimary
                      : context.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
