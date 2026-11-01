import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/qr_scanner_dialog.dart';
import '../../../core/scanner/scanner_service.dart';
import '../data/hu_models.dart';
import 'hu_provider.dart';
import 'widgets/move_hu_dialog.dart';

class HuConsultationScreen extends StatefulWidget {
  final String? initialLpn;

  const HuConsultationScreen({super.key, this.initialLpn});

  @override
  State<HuConsultationScreen> createState() => _HuConsultationScreenState();
}

class _HuConsultationScreenState extends State<HuConsultationScreen> {
  final _lpnController = TextEditingController();
  final _lpnFocus = FocusNode();
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();

    if (widget.initialLpn != null && widget.initialLpn!.isNotEmpty) {
      _lpnController.text = widget.initialLpn!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<HuProvider>().searchHu(widget.initialLpn!);
      });
    }

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _lpnController.text = barcode.trim();
      context.read<HuProvider>().searchHu(barcode.trim());
      HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _lpnController.dispose();
    _lpnFocus.dispose();
    super.dispose();
  }

  void _search() {
    if (_lpnController.text.trim().isNotEmpty) {
      _lpnFocus.unfocus();
      context.read<HuProvider>().searchHu(_lpnController.text.trim());
    }
  }

  Future<void> _openCameraScanner() async {
    final code = await QrScannerDialog.scan(
      context,
      title: 'Bipar QR Code da HU',
    );
    if (code != null && code.isNotEmpty && mounted) {
      _lpnController.text = code;
      context.read<HuProvider>().searchHu(code);
    }
  }

  Future<void> _openMoveDialog(HandlingUnitModel hu) async {
    final moved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MoveHuDialog(hu: hu),
    );

    if (moved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('HU movimentada com sucesso!'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality.toUpperCase()) {
      case 'AVAILABLE':
        return const Color(0xFF10B981);
      case 'QUARANTINE':
        return const Color(0xFFF59E0B);
      case 'REJECTED':
      case 'DAMAGED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getQualityLabel(String quality) {
    switch (quality.toUpperCase()) {
      case 'AVAILABLE':
        return 'Disponível';
      case 'QUARANTINE':
        return 'Quarentena';
      case 'REJECTED':
        return 'Rejeitado';
      case 'DAMAGED':
        return 'Avaria';
      default:
        return quality;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'STORED':
        return const Color(0xFF3B82F6); // Azul
      case 'INDOCK':
      case 'RECEIVING':
        return const Color(0xFF10B981); // Verde
      case 'ALLOCATED':
      case 'PICKING':
        return const Color(0xFFF59E0B); // Amarelo
      case 'CONSUMED':
      case 'SHIPPED':
      case 'BAIXADO':
        return const Color(0xFF64748B); // Cinza
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'STORED':
        return 'Armazenado';
      case 'INDOCK':
        return 'Na Doca';
      case 'ALLOCATED':
        return 'Alocado';
      case 'PICKING':
        return 'Em Separação';
      case 'CONSUMED':
        return 'Consumido / Baixado';
      case 'SHIPPED':
        return 'Expedido';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final huProvider = context.watch<HuProvider>();
    final hu = huProvider.currentHu;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Consulta & Manejo de HU',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (hu != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
              onPressed: () => huProvider.searchHu(hu.lpn),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // BARRA DE PESQUISA (BIP, CÂMERA OU DIGITAÇÃO)
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lpnController,
                      focusNode: _lpnFocus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Bipar ou digitar LPN da HU...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.qr_code_scanner,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.photo_camera_rounded,
                                color: Color(0xFF60A5FA),
                                size: 20,
                              ),
                              tooltip: 'Escanear via Câmera',
                              onPressed: _openCameraScanner,
                            ),
                            if (_lpnController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                                onPressed: () {
                                  _lpnController.clear();
                                  huProvider.clear();
                                },
                              ),
                          ],
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: huProvider.isLoading ? null : _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: huProvider.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'BUSCAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTEÚDO PRINCIPAL
            Expanded(
              child: huProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : huProvider.errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 56,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              huProvider.errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : hu == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 64,
                            color: Color(0xFF334155),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma HU selecionada',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pressione o gatilho, toque na câmera ou digite o LPN acima.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // AVISO SE A HU ESTIVER CONSUMIDA / BAIXADA
                          if (!hu.canPerformActions) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF450A0A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.block_rounded,
                                    color: Color(0xFFF87171),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HU ${hu.currentQuantity <= 0 ? "SEM SALDO" : "FINALIZADA"} (${_getStatusLabel(hu.status).toUpperCase()})',
                                          style: const TextStyle(
                                            color: Color(0xFFFCA5A5),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Text(
                                          'Esta unidade não está ativa no armazém. Movimentações bloqueadas.',
                                          style: TextStyle(
                                            color: Color(0xFFFCA5A5),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 1. CARD PRINCIPAL DA HU & STATUS REAL
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF334155),
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
                                          Icons.inventory_2,
                                          color: Color(0xFF3B82F6),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          hu.lpn,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // Badge do Status Físico/Ciclo da HU
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(hu.status)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: _getStatusColor(hu.status)
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            _getStatusLabel(hu.status),
                                            style: TextStyle(
                                              color: _getStatusColor(hu.status),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Badge de Qualidade
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getQualityColor(
                                              hu.qualityStatus,
                                            ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: _getQualityColor(
                                                hu.qualityStatus,
                                              ).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            _getQualityLabel(hu.qualityStatus),
                                            style: TextStyle(
                                              color: _getQualityColor(
                                                hu.qualityStatus,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Color(0xFF334155),
                                  height: 20,
                                ),

                                // Localização Atual
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFF06B6D4),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Endereço / Posição Física',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            hu.currentLocationPath,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. CARD COMPLETO DA NOTA FISCAL DE ENTRADA
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.4),
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
                                          Icons.receipt_long_rounded,
                                          color: Color(0xFF60A5FA),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          hu.invoiceNumber != null
                                              ? 'NF-e: ${hu.invoiceNumber}${hu.invoiceSerie != null ? ' - Série ${hu.invoiceSerie}' : ''}'
                                              : 'Entrada: Sem NF-e Vinculada',
                                          style: const TextStyle(
                                            color: Color(0xFF93C5FD),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hu.receiptDate != null)
                                      Text(
                                        'Entrada: ${_formatDate(hu.receiptDate)}',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (hu.issuerName != null &&
                                    hu.issuerName!.isNotEmpty) ...[
                                  Text(
                                    hu.issuerName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (hu.issuerCnpj != null &&
                                      hu.issuerCnpj!.isNotEmpty)
                                    Text(
                                      'CNPJ Fornecedor: ${hu.issuerCnpj}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                ],
                                if (hu.accessKey != null &&
                                    hu.accessKey!.isNotEmpty) ...[
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: hu.accessKey!),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text('Chave copiada!'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF334155),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.vpn_key_outlined,
                                            size: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              hu.accessKey!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.copy_rounded,
                                            size: 12,
                                            color: Color(0xFF60A5FA),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 3. PRODUTO & EMBALAGEM COMPLETA
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${hu.productSku} - ${hu.productDescription}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Depositante: ${hu.customerName}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Descrição da Embalagem
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.layers_outlined,
                                        size: 16,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          hu.packagingTypeCode != null ||
                                                  hu.packagingTypeDescription !=
                                                      null
                                              ? 'Embalagem: ${hu.packagingTypeCode ?? ""} ${hu.packagingTypeDescription != null ? "(${hu.packagingTypeDescription})" : ""}'
                                              : 'Embalagem: Padrão (UN)',
                                          style: const TextStyle(
                                            color: Color(0xFFE2E8F0),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 4. RASTREABILIDADE (LOTE E VALIDADE)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Quantidade',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${hu.currentQuantity.toStringAsFixed(0)} ${hu.productBaseUnit}',
                                      style: TextStyle(
                                        color: hu.currentQuantity > 0
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 28,
                                  width: 1,
                                  color: const Color(0xFF334155),
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Lote',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hu.batch ?? 'SEM LOTE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 28,
                                  width: 1,
                                  color: const Color(0xFF334155),
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Validade',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(hu.expirationDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 5. PESOS E VALOR PATRIMONIAL
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Peso Líq. Total',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${hu.totalNetWeight.toStringAsFixed(2)} kg',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFF334155),
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Peso Bruto Total',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${hu.totalGrossWeight.toStringAsFixed(2)} kg',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFF334155),
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      'Valor do Volume',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'R\$ ${hu.totalValue.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
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
                          const SizedBox(height: 16),

                          // 6. AÇÕES OPERACIONAIS (SÓ EXIBIDAS SE A HU ESTIVER ATIVA)
                          if (hu.canPerformActions) ...[
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () => _openMoveDialog(hu),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF06B6D4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.drive_file_move_outline,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                label: const Text(
                                  'MOVER HU (TRANSFERIR POSIÇÃO)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2.4,
                              children: [
                                _buildSecondaryActionButton(
                                  title: 'Split de HU',
                                  icon: Icons.call_split_rounded,
                                  color: const Color(0xFF8B5CF6),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Rotina de Split será implementada a seguir.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildSecondaryActionButton(
                                  title: 'Merge de HU',
                                  icon: Icons.call_merge_rounded,
                                  color: const Color(0xFF6366F1),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Rotina de Merge será implementada a seguir.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildSecondaryActionButton(
                                  title: 'Qualidade / Avaria',
                                  icon: Icons.security_rounded,
                                  color: const Color(0xFFF59E0B),
                                  onTap: () {},
                                ),
                                _buildSecondaryActionButton(
                                  title: 'Reimprimir LPN',
                                  icon: Icons.print_outlined,
                                  color: const Color(0xFF64748B),
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF334155)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
