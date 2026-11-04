import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../hu/data/hu_models.dart';
import '../../printing/presentation/printing_provider.dart';
import '../../printing/presentation/widgets/print_label_dialog.dart';
import '../../quality/data/quality_models.dart';
import '../../quality/presentation/quality_provider.dart';
import '../data/inbound_models.dart';
import '../data/inbound_repository.dart';
import 'inbound_provider.dart';

class StagedVolumeItem {
  final String tempId;
  final String packagingTypeId;
  final String packagingCode;
  final int volumeCount;
  final double quantityPerVolume;
  final double totalQuantity;
  final String? batch;
  final DateTime? manufactureDate;
  final DateTime? expirationDate;
  final String? serialNumber;
  final int qualityStatus;
  final String? qualityReasonId;
  final String? qualityNotes;
  final List<QualityImageAttachment> images;
  final String? billingServiceId;
  final String billingServiceName;

  StagedVolumeItem({
    required this.tempId,
    required this.packagingTypeId,
    required this.packagingCode,
    required this.volumeCount,
    required this.quantityPerVolume,
    required this.totalQuantity,
    this.batch,
    this.manufactureDate,
    this.expirationDate,
    this.serialNumber,
    required this.qualityStatus,
    this.qualityReasonId,
    this.qualityNotes,
    required this.images,
    this.billingServiceId,
    required this.billingServiceName,
  });
}

class ConferenciaItemScreen extends StatefulWidget {
  final String orderId;
  final String orderItemId;
  final Map<String, dynamic> itemData;
  final List<ProductPackagingOption> packagings;

  const ConferenciaItemScreen({
    super.key,
    required this.orderId,
    required this.orderItemId,
    required this.itemData,
    required this.packagings,
  });

  @override
  State<ConferenciaItemScreen> createState() => _ConferenciaItemScreenState();
}

class _ConferenciaItemScreenState extends State<ConferenciaItemScreen> {
  final _qtyController = TextEditingController();
  final _volCountController = TextEditingController(text: '1');
  final _batchController = TextEditingController();
  final _serialController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String? _selectedPackId;
  String? _selectedBillingServiceId;
  int _selectedQualityStatus = 1; // 1 = Liberado
  String? _selectedReasonId;
  DateTime? _mfgDate;
  DateTime? _expDate;

  // Regras de Rastreabilidade do Produto
  ProductTraceabilityRules _rules = ProductTraceabilityRules();
  bool _isLoadingRules = true;

  final List<QualityImageAttachment> _attachments = [];
  final List<StagedVolumeItem> _cart = [];
  List<GeneratedHuSummary>? _checkoutResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    if (widget.packagings.length == 1) {
      _onPackSelected(widget.packagings.first.packagingTypeId);
    } else {
      _selectedPackId = null;
    }
  }

  Future<void> _loadInitialData() async {
    final inboundRepo = context.read<InboundProvider>();
    inboundRepo.loadDocksAndServices();
    context.read<QualityProvider>().loadReasons();

    final productId = widget.itemData['productId']?.toString();
    if (productId != null && productId.isNotEmpty) {
      // Busca regras do produto diretamente do repositório
      final repository = InboundRepository(
        context.read<InboundProvider>().repositoryApi,
      );
      final rules = await repository.getProductRules(productId);

      if (mounted && rules != null) {
        setState(() {
          _rules = rules;
          _isLoadingRules = false;

          // Pré-preenchimento condicional: somente se o produto controlar a respectiva flag
          if (_rules.tracksBatch && widget.itemData['expectedBatch'] != null) {
            _batchController.text = widget.itemData['expectedBatch'];
          }
          if (_rules.tracksManufacture) {
            _mfgDate = widget.itemData['expectedManufactureDate'];
          }
          if (_rules.tracksExpiration) {
            _expDate = widget.itemData['expectedExpirationDate'];
          }
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoadingRules = false);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _volCountController.dispose();
    _batchController.dispose();
    _serialController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPackSelected(String? packId) {
    setState(() {
      _selectedPackId = packId;
      if (packId != null) {
        final pack = widget.packagings.firstWhere(
          (p) => p.packagingTypeId == packId,
        );
        _qtyController.text = pack.conversionFactor.toStringAsFixed(0);
      } else {
        _qtyController.clear();
      }
    });
  }

  Future<void> _pickDate({
    required BuildContext context,
    required bool isExpiration,
  }) async {
    final initial = isExpiration
        ? (_expDate ?? DateTime.now())
        : (_mfgDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isExpiration) {
          _expDate = picked;
        } else {
          _mfgDate = picked;
        }
      });
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
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
                : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
            base64Data: base64String,
            previewBytes: bytes,
          ),
        );
      });
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> _pauseAndRelease() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Pausar Conferência?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'O item será liberado na Doca para que outro operador possa continuar se necessário.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: const Text(
              'CONFIRMAR PAUSA',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<InboundProvider>().releaseItem(widget.orderItemId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _addToCart() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedBillingServiceId == null ||
        _selectedBillingServiceId!.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o Serviço Operacional de Recebimento.'),
        ),
      );
      return;
    }

    if (_selectedPackId == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a embalagem do volume.')),
      );
      return;
    }

    final volCount = int.tryParse(_volCountController.text) ?? 0;
    if (volCount <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantidade de volumes deve ser maior que zero.'),
        ),
      );
      return;
    }

    final qtyPerVol =
        double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 0;
    if (qtyPerVol <= 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade por volume inválida.')),
      );
      return;
    }

    // ==============================================================
    // VALIDAÇÕES ESTREITAS DE RASTREABILIDADE CONFORME REGRAS DO PRODUTO
    // ==============================================================
    final batchVal = _batchController.text.trim();
    if (_rules.tracksBatch && _rules.strictBatch && batchVal.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O lote é obrigatório para este produto.'),
        ),
      );
      return;
    }

    if (_rules.tracksManufacture &&
        _rules.strictManufacture &&
        _mfgDate == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A data de fabricação é obrigatória para este produto.',
          ),
        ),
      );
      return;
    }

    if (_rules.tracksExpiration &&
        _rules.strictExpiration &&
        _expDate == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de validade é obrigatória para este produto.'),
        ),
      );
      return;
    }

    final serialVal = _serialController.text.trim();
    if (_rules.tracksSerial && _rules.strictSerial && serialVal.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O número de série é obrigatório para este produto.'),
        ),
      );
      return;
    }

    if (_mfgDate != null && _expDate != null && _expDate!.isBefore(_mfgDate!)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A data de validade não pode ser anterior à data de fabricação.',
          ),
        ),
      );
      return;
    }

    // Regra Fiscal do Backend: Lote físico divergente da NF-e não pode entrar como Liberado
    final expectedBatch = widget.itemData['expectedBatch']?.toString().trim();
    if (_rules.tracksBatch &&
        expectedBatch != null &&
        expectedBatch.isNotEmpty &&
        batchVal.isNotEmpty &&
        batchVal.toUpperCase() != expectedBatch.toUpperCase() &&
        _selectedQualityStatus == 1) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            'Divergência Fiscal: Lote "$batchVal" difere da NF-e ("$expectedBatch"). Selecione um status de ocorrência/qualidade.',
          ),
        ),
      );
      return;
    }

    if (_selectedQualityStatus != 1 && _selectedReasonId == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o motivo da ocorrência de qualidade.'),
        ),
      );
      return;
    }

    final pack = widget.packagings.firstWhere(
      (p) => p.packagingTypeId == _selectedPackId,
    );

    final inboundProvider = context.read<InboundProvider>();
    String serviceName = 'Serviço Isento';
    if (_selectedBillingServiceId != 'exempt') {
      final srv = inboundProvider.billingServices.firstWhere(
        (s) => s.id == _selectedBillingServiceId,
        orElse: () => BillingServiceOption(id: '', name: 'Serviço Geral'),
      );
      serviceName = srv.name;
    }

    setState(() {
      _cart.add(
        StagedVolumeItem(
          tempId: DateTime.now().millisecondsSinceEpoch.toString(),
          packagingTypeId: pack.packagingTypeId,
          packagingCode: pack.code,
          volumeCount: volCount,
          quantityPerVolume: qtyPerVol,
          totalQuantity: volCount * qtyPerVol,
          batch: _rules.tracksBatch && batchVal.isNotEmpty ? batchVal : null,
          manufactureDate: _rules.tracksManufacture ? _mfgDate : null,
          expirationDate: _rules.tracksExpiration ? _expDate : null,
          serialNumber: _rules.tracksSerial && serialVal.isNotEmpty
              ? serialVal
              : null,
          qualityStatus: _selectedQualityStatus,
          qualityReasonId: _selectedReasonId,
          qualityNotes: _notesController.text.trim(),
          images: List.from(_attachments),
          billingServiceId: _selectedBillingServiceId == 'exempt'
              ? null
              : _selectedBillingServiceId,
          billingServiceName: serviceName,
        ),
      );

      _volCountController.text = '1';
      _selectedQualityStatus = 1;
      _selectedReasonId = null;
      _notesController.clear();
      _attachments.clear();

      if (widget.packagings.length > 1) {
        _selectedPackId = null;
        _qtyController.clear();
      }

      HapticFeedback.mediumImpact();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeLotFromCart(String tempId) {
    setState(() {
      _cart.removeWhere((item) => item.tempId == tempId);
      HapticFeedback.lightImpact();
    });
  }

  Future<void> _executeCheckout() async {
    if (_cart.isEmpty) return;

    final inboundProvider = context.read<InboundProvider>();

    final payloadVolumes = _cart
        .map(
          (v) => {
            'packagingTypeId': v.packagingTypeId,
            'volumeCount': v.volumeCount,
            'quantityPerVolume': v.quantityPerVolume,
            'batch': v.batch,
            'manufactureDate': v.manufactureDate?.toUtc().toIso8601String(),
            'expirationDate': v.expirationDate?.toUtc().toIso8601String(),
            'serialNumber': v.serialNumber,
            'targetLocationId': widget.itemData['dockLocationId'],
            'qualityStatus': v.qualityStatus,
            'qualityReasonId': v.qualityReasonId,
            'qualityNotes': v.qualityNotes,
            'qualityImages': v.images.isNotEmpty
                ? v.images.map((img) => img.toJson()).toList()
                : null,
            'billingServiceId': v.billingServiceId,
          },
        )
        .toList();

    final result = await inboundProvider.checkoutLote(
      orderItemId: widget.orderItemId,
      volumes: payloadVolumes,
    );

    if (result.isNotEmpty && mounted) {
      setState(() {
        _checkoutResult = result;
        _cart.clear();
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _openPrintModal() async {
    if (_checkoutResult == null || _checkoutResult!.isEmpty) return;

    final huIds = _checkoutResult!.map((h) => h.id).toList();

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrintLabelDialog(
        title: 'Imprimir HUs Recebidas',
        summaryWidget: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            children: [
              Text(
                '${huIds.length} nova(s) HU(s) gerada(s)',
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.itemData['sku']} • Doca: ${widget.itemData['dockLocationPath']}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ),
        onConfirmPrint:
            ({
              required String stationName,
              required String printerName,
              required String templateId,
              required int copies,
            }) {
              return context.read<PrintingProvider>().printHus(
                huIds: huIds,
                templateId: templateId,
                stationName: stationName,
                printerName: printerName,
                copies: copies,
              );
            },
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildQualityBadge(int status) {
    Color bg;
    Color text;
    String label;
    switch (status) {
      case 1:
        bg = const Color(0xFF065F46).withValues(alpha: 0.3);
        text = const Color(0xFF34D399);
        label = 'Liberado';
        break;
      case 2:
        bg = const Color(0xFF78350F).withValues(alpha: 0.3);
        text = const Color(0xFFFBBF24);
        label = 'Quarentena';
        break;
      case 3:
        bg = const Color(0xFF7F1D1D).withValues(alpha: 0.3);
        text = const Color(0xFFF87171);
        label = 'Avaria Física';
        break;
      case 4:
        bg = const Color(0xFF581C87).withValues(alpha: 0.3);
        text = const Color(0xFFC084FC);
        label = 'Falta Física';
        break;
      default:
        bg = const Color(0xFF334155);
        text = const Color(0xFF94A3B8);
        label = 'Indefinido';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: text.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qualityProvider = context.watch<QualityProvider>();
    final inboundProvider = context.watch<InboundProvider>();

    final double expected = (widget.itemData['expectedQuantity'] ?? 0)
        .toDouble();
    final double alreadyReceived = (widget.itemData['receivedQuantity'] ?? 0)
        .toDouble();
    final double inCart = _cart.fold(
      0.0,
      (sum, item) => sum + item.totalQuantity,
    );
    final String unit = widget.itemData['unit'] ?? 'UN';

    if (_checkoutResult != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Recebimento na Doca'),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Checkout Gravado na Doca!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_checkoutResult!.length} HUs geradas na Doca ${widget.itemData['dockLocationPath']}.\nUtilize o menu de Guarda para armazená-las nos porta-paletes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openPrintModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.printer, color: Colors.white),
                    label: const Text(
                      'IMPRIMIR ETIQUETAS DAS HUs',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'CONCLUIR E VOLTAR',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.itemData['sku'] ?? 'Conferência de Item',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.pause_circle_outline_rounded,
              color: Color(0xFFFBBF24),
            ),
            tooltip: 'Pausar e Liberar Item',
            onPressed: _pauseAndRelease,
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumo Superior do Item
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.itemData['description'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Doca: ${widget.itemData['dockLocationPath']}',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric(
                      'Esperado',
                      '${expected.toStringAsFixed(0)} $unit',
                      Colors.white,
                    ),
                    _buildMetric(
                      'Já Recebido',
                      '${alreadyReceived.toStringAsFixed(0)} $unit',
                      const Color(0xFF10B981),
                    ),
                    _buildMetric(
                      'No Carrinho',
                      '${inCart.toStringAsFixed(0)} $unit',
                      const Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Formulário com scroll
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. SERVIÇO DE COBRANÇA OBRIGATÓRIO
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBillingServiceId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Serviço Operacional de Recebimento *',
                        labelStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        ...inboundProvider.billingServices.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'exempt',
                          child: Row(
                            children: [
                              Icon(
                                Icons.money_off_csred_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Serviço isento (Sem tarifa)',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedBillingServiceId = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecione o serviço de recebimento'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // 2. EMBALAGEM E QUANTIDADES
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPackId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Embalagem do Volume *',
                        labelStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                        hintText: widget.packagings.length > 1
                            ? 'Selecione a embalagem do lote...'
                            : null,
                        hintStyle: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: widget.packagings
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.packagingTypeId,
                              child: Text(
                                '${p.code} - ${p.description} (${p.conversionFactor.toStringAsFixed(0)} $unit)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onPackSelected,
                      validator: (v) =>
                          v == null ? 'Selecione a embalagem' : null,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _volCountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Qtd Volumes (HU)',
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'X',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Peças por Volume',
                              labelStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ==============================================================
                    // 3. RASTREABILIDADE DINÂMICA BASEADA NAS REGRAS DO PRODUTO
                    // ==============================================================
                    if (_isLoadingRules) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_rules.hasAnyTracking) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rastreabilidade Exigida pelo Produto',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // CAMPO LOTE FÍSICO
                            if (_rules.tracksBatch) ...[
                              TextFormField(
                                controller: _batchController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                decoration: InputDecoration(
                                  labelText: _rules.strictBatch
                                      ? 'Lote Físico * (Obrigatório)'
                                      : 'Lote Físico (Opcional)',
                                  labelStyle: TextStyle(
                                    color: _rules.strictBatch
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: _rules.strictBatch
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // DATAS: VALIDADE E FABRICAÇÃO
                            if (_rules.tracksExpiration ||
                                _rules.tracksManufacture) ...[
                              Row(
                                children: [
                                  if (_rules.tracksExpiration)
                                    Expanded(
                                      child: _buildDateTile(
                                        title: 'Validade',
                                        isStrict: _rules.strictExpiration,
                                        date: _expDate,
                                        onTap: () => _pickDate(
                                          context: context,
                                          isExpiration: true,
                                        ),
                                        onClear: _rules.strictExpiration
                                            ? null
                                            : () => setState(
                                                () => _expDate = null,
                                              ),
                                      ),
                                    ),
                                  if (_rules.tracksExpiration &&
                                      _rules.tracksManufacture)
                                    const SizedBox(width: 8),
                                  if (_rules.tracksManufacture)
                                    Expanded(
                                      child: _buildDateTile(
                                        title: 'Fabricação',
                                        isStrict: _rules.strictManufacture,
                                        date: _mfgDate,
                                        onTap: () => _pickDate(
                                          context: context,
                                          isExpiration: false,
                                        ),
                                        onClear: _rules.strictManufacture
                                            ? null
                                            : () => setState(
                                                () => _mfgDate = null,
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],

                            // NÚMERO DE SÉRIE
                            if (_rules.tracksSerial) ...[
                              TextFormField(
                                controller: _serialController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                decoration: InputDecoration(
                                  labelText: _rules.strictSerial
                                      ? 'Número de Série * (Obrigatório)'
                                      : 'Número de Série (Opcional)',
                                  labelStyle: TextStyle(
                                    color: _rules.strictSerial
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: _rules.strictSerial
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. QUALIDADE E AVARIAS INLINE
                    const Text(
                      'Condição / Qualidade da Carga',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedQualityStatus,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _selectedQualityStatus == 1
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF450A0A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: _selectedQualityStatus != 1
                              ? const BorderSide(color: Color(0xFFEF4444))
                              : BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            'Liberado (Sem Avarias)',
                            style: TextStyle(color: Color(0xFF10B981)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            'Quarentena / Retido',
                            style: TextStyle(color: Color(0xFFF59E0B)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            'Avariado / Danificado',
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text(
                            'Falta Física / Divergência Fiscal',
                            style: TextStyle(color: Color(0xFFC084FC)),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedQualityStatus = v ?? 1),
                    ),

                    if (_selectedQualityStatus != 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF450A0A).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF991B1B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedReasonId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Motivo da Ocorrência *',
                                labelStyle: const TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: qualityProvider.reasons
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text(
                                        '${r.code} - ${r.description}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedReasonId = v),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _notesController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Descrição detalhada do problema *',
                                labelStyle: const TextStyle(
                                  color: Color(0xFFFCA5A5),
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Fotos (${_attachments.length})',
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        color: Color(0xFFFCA5A5),
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _takePhoto(ImageSource.camera),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.photo_library,
                                        color: Color(0xFFFCA5A5),
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _takePhoto(ImageSource.gallery),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_attachments.isNotEmpty)
                              SizedBox(
                                height: 60,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _attachments.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, idx) {
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.memory(
                                            _attachments[idx].previewBytes,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => setState(
                                              () => _attachments.removeAt(idx),
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.black87,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'ADICIONAR LOTE AO CARRINHO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 16),

                    // 5. MATERIALIZAÇÃO DO CARRINHO DE LOTES
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_rounded,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Carrinho de Lotes',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            '${_cart.length} lote(s)',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_cart.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                color: Color(0xFF64748B),
                                size: 36,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Nenhum lote adicionado ao carrinho.',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Preencha os campos e clique em "Adicionar Lote".',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cart.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = _cart[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB)
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            item.packagingCode,
                                            style: const TextStyle(
                                              color: Color(0xFF60A5FA),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.volumeCount} Vol x ${item.quantityPerVolume.toStringAsFixed(0)} = ${item.totalQuantity.toStringAsFixed(0)} $unit',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFF87171),
                                        size: 20,
                                      ),
                                      tooltip: 'Excluir Lote',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          _removeLotFromCart(item.tempId),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Serviço: ${item.billingServiceName}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Lote: ${item.batch ?? "Sem Lote"}',
                                      style: const TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (item.expirationDate != null)
                                      Text(
                                        'Val: ${_formatDate(item.expirationDate)}',
                                        style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                        ),
                                      ),
                                    _buildQualityBadge(item.qualityStatus),
                                  ],
                                ),
                                if (item.images.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 13,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${item.images.length} evidência(s) anexada(s)',
                                        style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // RODAPÉ DO CARRINHO COM CHECKOUT
      bottomNavigationBar: _cart.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF1E293B),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_cart.length} lote(s) pronto(s)',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Total: ${inCart.toStringAsFixed(0)} $unit',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: inboundProvider.isLoading
                            ? null
                            : _executeCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: inboundProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'GRAVAR CHECKOUT NA DOCA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDateTile({
    required String title,
    required bool isStrict,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isStrict && date == null
                ? const Color(0xFFEF4444)
                : const Color(0xFF334155),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title + (isStrict ? ' *' : ''),
                  style: TextStyle(
                    color: isStrict
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: isStrict ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (date != null && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: date != null
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  date != null ? _formatDate(date) : 'Selecionar...',
                  style: TextStyle(
                    color: date != null
                        ? Colors.white
                        : const Color(0xFF64748B),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: date != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
