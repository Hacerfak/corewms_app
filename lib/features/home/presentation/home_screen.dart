import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../hu/presentation/hu_consultation_screen.dart';
import 'widgets/menu_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();

    final scanner = context.read<ScannerService>();
    _scanSubscription = scanner.onScan.listen((barcode) {
      if (!mounted) return;
      _handleQuickScan(barcode);
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  /// Ao bipar com o laser na tela inicial, direciona direto para a consulta da HU
  void _handleQuickScan(String barcode) {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: Color(0xFF3B82F6),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Identificando HU: $cleanCode...',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HuConsultationScreen(initialLpn: cleanCode),
      ),
    );
  }

  bool _hasPermission(AuthProvider auth, String requiredPerm) {
    if (auth.user?.isMaster == true) return true;
    final perms = auth.user?.permissions ?? [];
    return perms.contains('*') || perms.contains(requiredPerm);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.selectedCompanyName ?? 'CoreWMS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              auth.user?.name ?? 'Operador',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
            tooltip: 'Trocar Empresa / Unidade',
            onPressed: () => context.read<AuthProvider>().switchCompany(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de Instrução do Laser
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pressione o gatilho para bipar qualquer HU ou toque na rotina desejada:',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grid dos 6 Módulos Operacionais
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    // 1. Gestão de HUs (Mover, Split, Merge, Qualidade, Estorno, Reimpressão)
                    MenuCard(
                      title: 'Gestão de HU',
                      subtitle: 'Consulta, Mover, Merge, Split e Qualidade',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF3B82F6),
                      badge: 'ESTOQUE',
                      isEnabled: _hasPermission(auth, 'inventory:view'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HuConsultationScreen(),
                          ),
                        );
                      },
                    ),

                    // 2. Recebimento de NF-e (Itens pendentes item a item)
                    MenuCard(
                      title: 'Recebimento',
                      subtitle: 'Descarga e conferência cega/guiada de NF-e',
                      icon: Icons.move_to_inbox_rounded,
                      color: const Color(0xFF10B981), // Esmeralda
                      badge: 'INBOUND',
                      isEnabled: _hasPermission(auth, 'inbound:manage'),
                      onTap: () {
                        // Navega para lista de NF-es revisadas
                      },
                    ),

                    // 3. Separação de Expedição (Agrupado por Posição de Estoque)
                    MenuCard(
                      title: 'Separação',
                      subtitle: 'Picking consolidado e guiado por endereço',
                      icon: Icons.alt_route_rounded,
                      color: const Color(0xFFF59E0B), // Âmbar
                      badge: 'PICKING',
                      isEnabled: _hasPermission(auth, 'outbound:picking'),
                      onTap: () {
                        // Navega para tarefas de picking
                      },
                    ),

                    // 4. Embalagem (Packing & Montagem de Volumes)
                    MenuCard(
                      title: 'Embalagem',
                      subtitle: 'Conferência de mesa e formação de volumes',
                      icon: Icons.archive_outlined,
                      color: const Color(0xFF8B5CF6), // Roxo
                      badge: 'PACKING',
                      isEnabled: _hasPermission(auth, 'outbound:packing'),
                      onTap: () {
                        // Navega para pedidos em packing
                      },
                    ),

                    // 5. Conferência de Expedição (Carregamento e Doca)
                    MenuCard(
                      title: 'Conferência',
                      subtitle: 'Check-out de expedição e validação de carga',
                      icon: Icons.fact_check_outlined,
                      color: const Color(0xFF06B6D4), // Ciano
                      badge: 'EXPEDIÇÃO',
                      isEnabled: _hasPermission(auth, 'outbound:checking'),
                      onTap: () {
                        // Navega para checking de expedição
                      },
                    ),

                    // 6. Inventário Cíclico (Contagem Cega por Posição)
                    MenuCard(
                      title: 'Inventário',
                      subtitle: 'Contagem física cega agrupada por posição',
                      icon: Icons.visibility_off_outlined,
                      color: const Color(0xFFEC4899), // Rosa
                      badge: 'AUDITORIA',
                      isEnabled: _hasPermission(auth, 'cyclecount:execute'),
                      onTap: () {
                        // Navega para tarefas de inventário
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
