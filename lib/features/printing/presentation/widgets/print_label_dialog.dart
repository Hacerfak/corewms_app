import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
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
    final isDark = context.isDark;

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
                    color: const Color(0xFF0284C7)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.printer,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF0284C7),
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
                        'Despacho de comando ZPL para impressora',
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

            // Card com o resumo customizado do item que está a ser impresso
            widget.summaryWidget,
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
                        _localError ?? provider.errorMessage ?? '',
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

            // 1. Estação de Impressão (Agente)
            DropdownButtonFormField<PrintAgentModel>(
              initialValue: agents.contains(_selectedAgent)
                  ? _selectedAgent
                  : null,
              isExpanded: true,
              dropdownColor: context.card,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Estação de Impressão (Agente) *',
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
              dropdownColor: context.card,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Impressora *',
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
              dropdownColor: context.card,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Modelo da Etiqueta *',
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
                Text(
                  'Cópias:',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: context.cardSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          LucideIcons.minus,
                          size: 16,
                          color: context.textPrimary,
                        ),
                        onPressed: _copies > 1
                            ? () => setState(() => _copies--)
                            : null,
                      ),
                      Text(
                        '$_copies',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.plus,
                          size: 16,
                          color: context.textPrimary,
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
              title: Text(
                'Lembrar impressora para as próximas operações',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
              value: _saveAsDefault,
              activeColor: const Color(0xFF2563EB),
              onChanged: (val) => setState(() => _saveAsDefault = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.isPrinting
                        ? null
                        : () => Navigator.of(context).pop(false),
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
                    onPressed: provider.isPrinting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
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
