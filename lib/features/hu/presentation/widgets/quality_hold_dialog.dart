import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/scanner/qr_scanner_dialog.dart';
import '../../../../core/scanner/scanner_service.dart';
import '../../data/hu_models.dart';
import '../hu_provider.dart';

class QualityHoldDialog extends StatefulWidget {
  final HandlingUnitModel hu;

  const QualityHoldDialog({super.key, required this.hu});

  @override
  State<QualityHoldDialog> createState() => _QualityHoldDialogState();
}

class _QualityHoldDialogState extends State<QualityHoldDialog> {
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  StreamSubscription<String>? _scanSubscription;

  QualityStatusTarget _selectedStatus = QualityStatusTarget.damaged;
  String? _selectedReasonId;
  bool _shouldMoveToLocation = false;
  LocationModel? _resolvedQualityLocation;
  bool _isResolvingLocation = false;
  String? _localError;

  final List<QualityImageAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HuProvider>().loadQualityReasons();
    });

    // Escuta o laser do Movfast para leitura da posição de qualidade
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
          _resolvedQualityLocation = null;
          _isResolvingLocation = false;
          _localError = 'Endereço "$clean" não cadastrado na Topologia.';
        });
        HapticFeedback.heavyImpact();
        return;
      }

      setState(() {
        _resolvedQualityLocation = location;
        _isResolvingLocation = false;
        _localError = null;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedQualityLocation = null;
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

    if (_shouldMoveToLocation && _resolvedQualityLocation == null) {
      setState(
        () => _localError =
            'Bipe ou valide a posição de destino para transferir a HU.',
      );
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<HuProvider>();
    final success = await provider.executeQualityHold(
      newStatus: _selectedStatus.value,
      reasonId: _selectedReasonId!,
      notes: _notesController.text.trim(),
      qualityLocationId: _shouldMoveToLocation
          ? _resolvedQualityLocation?.id
          : null,
      images: _attachments,
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
    final provider = context.watch<HuProvider>();
    final reasons = provider.qualityReasons;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Color(0xFFFBBF24),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apontamento de Qualidade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Avaria física, retenção e bloqueios',
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
              const SizedBox(height: 14),

              // Resumo da HU
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hu.lpn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${widget.hu.productSku} • Saldo: ${widget.hu.currentQuantity.toStringAsFixed(0)} ${widget.hu.productBaseUnit}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.hu.currentLocationPath,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

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

              // 1. Tipo de Bloqueio (Avaria / Quarentena)
              const Text(
                'Tipo de Ocorrência',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusRadio(
                      target: QualityStatusTarget.damaged,
                      icon: Icons.broken_image_outlined,
                      activeColor: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusRadio(
                      target: QualityStatusTarget.quarantine,
                      icon: Icons.lock_clock_outlined,
                      activeColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Motivo da Ocorrência
              DropdownButtonFormField<String>(
                initialValue: _selectedReasonId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Motivo da Ocorrência *',
                  labelStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r.id,
                    child: Text('${r.code} - ${r.description}'),
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Descrição detalhada da avaria/retenção *',
                  labelStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                  hintText: 'Ex: Fardo rompido com vazamento visível no nível inferior...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a descrição da ocorrência'
                    : null,
              ),
              const SizedBox(height: 8),

              // 4. Movimentação Opcional Integrada
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFFF59E0B),
                activeTrackColor: const Color(0xFFF59E0B)
                    .withValues(alpha: 0.3),
                title: const Text(
                  'Transferir para Posição de Qualidade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Move fisicamente a HU para a área de quarentena/avarias',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                value: _shouldMoveToLocation,
                onChanged: (val) => setState(() {
                  _shouldMoveToLocation = val;
                  if (!val) _resolvedQualityLocation = null;
                }),
              ),

              if (_shouldMoveToLocation) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: _resolveLocation,
                  decoration: InputDecoration(
                    labelText: 'Bipe ou digite o Endereço de Qualidade',
                    labelStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.qr_code_scanner,
                      color: Color(0xFFF59E0B),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            color: Color(0xFF60A5FA),
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
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFF59E0B),
                            ),
                            onPressed: () =>
                                _resolveLocation(_locationController.text),
                          ),
                      ],
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_resolvedQualityLocation != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF059669)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF34D399),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Destino: ${_resolvedQualityLocation!.fullPath}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
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

              // 5. Seção de Fotos Anexas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fotos / Evidências (${_attachments.length})',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                        tooltip: 'Tirar Foto com a Câmera',
                        onPressed: () => _takePhoto(ImageSource.camera),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.photo_library_rounded,
                          color: Color(0xFF818CF8),
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
                                  Icons.close,
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
                      onPressed: provider.isHoldingQuality
                          ? null
                          : () => Navigator.of(context).pop(false),
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
                      onPressed: provider.isHoldingQuality ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: provider.isHoldingQuality
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'REGISTRAR BLOQUEIO',
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

  Widget _buildStatusRadio({
    required QualityStatusTarget target,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedStatus == target;

    return InkWell(
      onTap: () => setState(() => _selectedStatus = target),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF0F172A),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF334155),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : const Color(0xFF64748B),
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                target.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
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
