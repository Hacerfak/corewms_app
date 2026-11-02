import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/printing_models.dart';
import '../printing_provider.dart';

class PrintLabelDialog extends StatefulWidget {
  final String title;
  final Widget summaryWidget;
  final Future<bool> Function({
    required String stationName,
    required String printerName,
    required String templateId,
    required int copies,
  })
  onConfirmPrint;

  const PrintLabelDialog({
    super.key,
    required this.title,
    required this.summaryWidget,
    required this.onConfirmPrint,
  });

  @override
  State<PrintLabelDialog> createState() => _PrintLabelDialogState();
}

class _PrintLabelDialogState extends State<PrintLabelDialog> {
  PrintAgentModel? _selectedAgent;
  PrinterModel? _selectedPrinter;
  LabelTemplateModel? _selectedTemplate;

  int _copies = 1;
  bool _saveAsDefault = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final provider = context.read<PrintingProvider>();
    await provider.loadOptions();

    if (!mounted) return;

    final saved = await provider.getSavedPreferences();
    final savedStation = saved['station'];
    final savedPrinter = saved['printer'];
    final savedTemplateId = saved['templateId'];

    setState(() {
      // 1. Estação de Impressão (Agente)
      if (savedStation != null &&
          provider.agents.any((a) => a.name == savedStation)) {
        _selectedAgent = provider.agents.firstWhere(
          (a) => a.name == savedStation,
        );
      } else if (provider.agents.isNotEmpty) {
        _selectedAgent = provider.agents.firstWhere(
          (a) => a.isOnline,
          orElse: () => provider.agents.first,
        );
      }

      // 2. Impressora
      if (_selectedAgent != null && _selectedAgent!.printers.isNotEmpty) {
        if (savedPrinter != null &&
            _selectedAgent!.printers.any((p) => p.name == savedPrinter)) {
          _selectedPrinter = _selectedAgent!.printers.firstWhere(
            (p) => p.name == savedPrinter,
          );
        } else {
          _selectedPrinter = _selectedAgent!.printers.first;
        }
      }

      // 3. Template ZPL
      if (savedTemplateId != null &&
          provider.templates.any((t) => t.id == savedTemplateId)) {
        _selectedTemplate = provider.templates.firstWhere(
          (t) => t.id == savedTemplateId,
        );
      } else if (provider.templates.isNotEmpty) {
        _selectedTemplate = provider.templates.first;
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedAgent == null) {
      setState(() => _localError = 'Selecione uma estação de impressão.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_selectedPrinter == null) {
      setState(() => _localError = 'Selecione a impressora térmica.');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_selectedTemplate == null) {
      setState(() => _localError = 'Selecione o modelo da etiqueta.');
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<PrintingProvider>();

    if (_saveAsDefault) {
      await provider.savePreferences(
        station: _selectedAgent!.name,
        printer: _selectedPrinter!.name,
        templateId: _selectedTemplate!.id,
      );
    }

    final success = await widget.onConfirmPrint(
      stationName: _selectedAgent!.name,
      printerName: _selectedPrinter!.name,
      templateId: _selectedTemplate!.id,
      copies: _copies,
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
    final provider = context.watch<PrintingProvider>();
    final agents = provider.agents;
    final templates = provider.templates;
    final availablePrinters = _selectedAgent?.printers ?? [];

    return Dialog(
      backgroundColor: const Color(0xFF1E293B), // Slate 800
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
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.print_rounded,
                    color: Color(0xFF38BDF8),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Despacho de comando ZPL para impressora',
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

            // Card com o resumo customizado do item que está sendo impresso
            widget.summaryWidget,
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

            // 1. Estação de Impressão (Agente)
            DropdownButtonFormField<PrintAgentModel>(
              initialValue: agents.contains(_selectedAgent)
                  ? _selectedAgent
                  : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Estação de Impressão (Agente) *',
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
              items: agents.map((agent) {
                return DropdownMenuItem<PrintAgentModel>(
                  value: agent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          agent.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: agent.isOnline
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (agent) {
                setState(() {
                  _selectedAgent = agent;
                  _selectedPrinter =
                      (agent != null && agent.printers.isNotEmpty)
                      ? agent.printers.first
                      : null;
                  _localError = null;
                });
              },
            ),
            const SizedBox(height: 12),

            // 2. Impressora Térmica
            DropdownButtonFormField<PrinterModel>(
              initialValue: availablePrinters.contains(_selectedPrinter)
                  ? _selectedPrinter
                  : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Impressora *',
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
              items: availablePrinters.map((printer) {
                return DropdownMenuItem<PrinterModel>(
                  value: printer,
                  child: Text(
                    '${printer.name} (${printer.target})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (p) => setState(() => _selectedPrinter = p),
            ),
            const SizedBox(height: 12),

            // 3. Template ZPL
            DropdownButtonFormField<LabelTemplateModel>(
              initialValue: templates.contains(_selectedTemplate)
                  ? _selectedTemplate
                  : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Modelo da Etiqueta *',
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
              items: templates.map((tmpl) {
                return DropdownMenuItem<LabelTemplateModel>(
                  value: tmpl,
                  child: Text(
                    '${tmpl.name} (${tmpl.widthMm}x${tmpl.heightMm} mm)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (t) => setState(() => _selectedTemplate = t),
            ),
            const SizedBox(height: 14),

            // 4. Quantidade de Cópias
            Row(
              children: [
                const Text(
                  'Cópias:',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove,
                          size: 16,
                          color: Colors.white70,
                        ),
                        onPressed: _copies > 1
                            ? () => setState(() => _copies--)
                            : null,
                      ),
                      Text(
                        '$_copies',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          size: 16,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _copies++),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Lembrar impressora para as próximas operações',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
              ),
              value: _saveAsDefault,
              activeColor: const Color(0xFF2563EB),
              onChanged: (val) => setState(() => _saveAsDefault = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.isPrinting
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
                    onPressed: provider.isPrinting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: provider.isPrinting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'IMPRIMIR',
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
    );
  }
}
