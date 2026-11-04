import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/hu_models.dart';

class MergeSuccessDialog extends StatelessWidget {
  final MergeHuResult result;

  const MergeSuccessDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

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
              'Agrupamento Concluído!',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Card com o Novo Saldo da HU de Destino
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1)
                      .withValues(alpha: isDark ? 0.5 : 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'HU CONSOLIDADORA (DESTINO)',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    result.destinationLpn,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF4F46E5),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Novo Saldo: ${result.destinationQuantity.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card de Status da HU de Origem
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: result.wasSourceFullyConsumed
                    ? (isDark
                          ? const Color(0xFF450A0A)
                          : const Color(0xFFFFF1F2))
                    : context.cardSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: result.wasSourceFullyConsumed
                      ? (isDark
                            ? const Color(0xFF991B1B)
                            : const Color(0xFFFECDD3))
                      : context.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    result.wasSourceFullyConsumed
                        ? LucideIcons.trash
                        : LucideIcons.box,
                    size: 16,
                    color: result.wasSourceFullyConsumed
                        ? (isDark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFE11D48))
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      result.wasSourceFullyConsumed
                          ? 'HU Origem (${result.sourceLpn}) foi 100% consumida.'
                          : 'HU Origem (${result.sourceLpn}) resta com ${result.sourceRemaining.toStringAsFixed(0)} un.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: result.wasSourceFullyConsumed
                            ? (isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFBE123C))
                            : context.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botão Concluir
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'CONCLUIR',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
