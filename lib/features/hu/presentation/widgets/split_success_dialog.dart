import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/hu_models.dart';

class SplitSuccessDialog extends StatelessWidget {
  final SplitHuResult result;

  const SplitSuccessDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final newHu = result.createdHus.isNotEmpty ? result.createdHus.first : null;

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
              'Transbordo Concluído!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Uma nova HU foi gerada com o saldo desmembrado:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (newHu != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NOVA HU GERADA (LPN)',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      newHu.lpn,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
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
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
            ),
            const SizedBox(height: 20),

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
                        side: const BorderSide(color: Color(0xFF475569)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      label: const Text(
                        'COPIAR LPN',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                if (newHu != null) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(newHu?.lpn),
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
