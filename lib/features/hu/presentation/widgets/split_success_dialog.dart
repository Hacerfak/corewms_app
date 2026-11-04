import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/hu_models.dart';

class SplitSuccessDialog extends StatelessWidget {
  final SplitHuResult result;

  const SplitSuccessDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final newHu = result.createdHus.isNotEmpty ? result.createdHus.first : null;

    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de Sucesso
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981)
                    .withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.circle_check,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Transbordo Concluído!',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Uma nova HU foi gerada com o saldo desmembrado:',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Card da Nova HU Criada
            if (newHu != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2563EB)
                        .withValues(alpha: isDark ? 0.5 : 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'NOVA HU GERADA (LPN)',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      newHu.lpn,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF2563EB),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quantidade: ${newHu.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Text(
              'Saldo restante na HU mãe (${result.sourceLpn}): ${result.sourceRemaining.toStringAsFixed(0)}',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 20),

            // Botões de Ação
            Row(
              children: [
                if (newHu != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: newHu.lpn));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('LPN copiado!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: context.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        LucideIcons.copy,
                        color: context.textPrimary,
                        size: 16,
                      ),
                      label: Text(
                        'COPIAR LPN',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (newHu != null) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(newHu?.lpn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'CONCLUIR',
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
