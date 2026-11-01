import 'package:flutter/material.dart';

import '../../data/hu_models.dart';

class MergeSuccessDialog extends StatelessWidget {
  final MergeHuResult result;

  const MergeSuccessDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Agrupamento Concluído!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Card com o Novo Saldo da HU de Destino
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'HU CONSOLIDADORA (DESTINO)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    result.destinationLpn,
                    style: const TextStyle(
                      color: Color(0xFF818CF8),
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

            // Status da Origem
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: result.wasSourceFullyConsumed
                    ? const Color(0xFF450A0A)
                    : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    result.wasSourceFullyConsumed
                        ? Icons.delete_outline
                        : Icons.inventory_2_outlined,
                    size: 16,
                    color: result.wasSourceFullyConsumed
                        ? const Color(0xFFF87171)
                        : const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.wasSourceFullyConsumed
                        ? 'HU Origem (${result.sourceLpn}) foi 100% consumida.'
                        : 'HU Origem (${result.sourceLpn}) resta com ${result.sourceRemaining.toStringAsFixed(0)} un.',
                    style: TextStyle(
                      color: result.wasSourceFullyConsumed
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'CONCLUIR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
