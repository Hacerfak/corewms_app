import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_theme.dart';

class ServerConfigDialog extends StatefulWidget {
  final ApiClient apiClient;
  final StorageService storageService;
  final VoidCallback onSaved;

  const ServerConfigDialog({
    super.key,
    required this.apiClient,
    required this.storageService,
    required this.onSaved,
  });

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final _urlController = TextEditingController();
  bool _isTesting = false;
  bool? _testSuccess;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.apiClient.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _testSuccess = false;
        _statusMessage = 'Informe a URL do servidor.';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _statusMessage = 'Conectando ao servidor...';
    });

    final success = await widget.apiClient.testConnection(input);
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testSuccess = success;
      _statusMessage = success
          ? 'Conexão estabelecida com sucesso!'
          : 'Não foi possível conectar. Verifique o endereço e a internet.';
    });

    if (success) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _save() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    final sanitized = StorageService.sanitizeUrl(input);
    await widget.storageService.saveBaseUrl(sanitized);
    widget.apiClient.updateBaseUrl(sanitized);
    widget.onSaved();
    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Servidor configurado com sucesso!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _restoreDefault() {
    setState(() {
      _urlController.text = StorageService.defaultBaseUrl;
      _testSuccess = null;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // Cores dinâmicas para a caixa de status de teste
    final Color statusBoxBg;
    final Color statusBoxBorder;
    final Color statusTextColor;

    if (_testSuccess == true) {
      statusBoxBg = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.3)
          : const Color(0xFFECFDF5);
      statusBoxBorder = isDark
          ? const Color(0xFF059669)
          : const Color(0xFFA7F3D0);
      statusTextColor = isDark
          ? const Color(0xFF34D399)
          : const Color(0xFF065F46);
    } else {
      statusBoxBg = isDark
          ? const Color(0xFF450A0A).withValues(alpha: 0.35)
          : const Color(0xFFFEF2F2);
      statusBoxBorder = isDark
          ? const Color(0xFF991B1B)
          : const Color(0xFFFECACA);
      statusTextColor = isDark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFF991B1B);
    }

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB)
                        .withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.server,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conexão do Servidor',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Endereço da instância CoreWMS',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Campo de URL
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'URL Base do Servidor',
                labelStyle: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
                hintText: 'https://wms.empresa.com.br',
                hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
                prefixIcon: Icon(
                  LucideIcons.globe,
                  color: context.textSecondary,
                  size: 18,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    LucideIcons.rotate_ccw,
                    size: 16,
                    color: context.textSecondary,
                  ),
                  tooltip: 'Restaurar Padrão',
                  onPressed: _restoreDefault,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botão Testar Conexão
            OutlinedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textPrimary,
                side: BorderSide(color: context.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: _isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : const Icon(LucideIcons.activity, size: 16),
              label: Text(
                _isTesting ? 'Testando...' : 'Testar Comunicação',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Mensagem de Status
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusBoxBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBoxBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess == true
                          ? LucideIcons.circle_check
                          : LucideIcons.circle_alert,
                      size: 16,
                      color: statusTextColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Ações do Modal
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: context.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'SALVAR CONFIGURAÇÃO',
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
