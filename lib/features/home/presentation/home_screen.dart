import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../../core/scanner/scanner_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../hu/presentation/hu_consultation_screen.dart';
import '../../inbound/presentation/inbound_orders_list_screen.dart';
import '../../allocation/presentation/allocation_orders_screen.dart';
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

  void _handleQuickScan(String barcode) {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.card,
        content: Row(
          children: [
            const Icon(LucideIcons.scan, color: Color(0xFF3B82F6), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Identificando HU: $cleanCode...',
                style: TextStyle(
                  color: context.textPrimary,
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
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.selectedCompanyName ?? 'CoreWMS',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              auth.user?.name ?? 'Operador',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
              color: context.textSecondary,
            ),
            tooltip: 'Alternar Tema Claro / Escuro',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.arrow_left_right,
              color: context.textSecondary,
              size: 20,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.scan_line,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pressione o gatilho para bipar qualquer HU ou toque na rotina desejada:',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    MenuCard(
                      title: 'Gestão de HU',
                      subtitle: 'Consulta, Mover, Merge, Split e Qualidade',
                      icon: LucideIcons.box,
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
                    MenuCard(
                      title: 'Recebimento',
                      subtitle: 'Descarga e conferência cega/guiada de NF-e',
                      icon: LucideIcons.package_open,
                      color: const Color(0xFF10B981),
                      badge: 'INBOUND',
                      isEnabled:
                          _hasPermission(auth, 'inbound:receive') ||
                          _hasPermission(auth, 'inbound:manage') ||
                          _hasPermission(auth, 'inbound:view'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const InboundOrdersListScreen(),
                          ),
                        );
                      },
                    ),
                    MenuCard(
                      title: 'Alocação / Guarda',
                      subtitle: 'Armazenamento inteligente das HUs da doca',
                      icon: LucideIcons.arrow_down_to_dot,
                      color: const Color(0xFF0284C7),
                      badge: 'PUTAWAY',
                      isEnabled: _hasPermission(auth, 'inbound:receive'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AllocationOrdersScreen(),
                          ),
                        );
                      },
                    ),
                    MenuCard(
                      title: 'Separação',
                      subtitle: 'Picking consolidado e guiado por endereço',
                      icon: LucideIcons.blocks,
                      color: const Color(0xFFF59E0B),
                      badge: 'PICKING',
                      isEnabled: _hasPermission(auth, 'outbound:picking'),
                      onTap: () {},
                    ),
                    MenuCard(
                      title: 'Embalagem',
                      subtitle: 'Conferência de mesa e formação de volumes',
                      icon: LucideIcons.package_plus,
                      color: const Color(0xFF8B5CF6),
                      badge: 'PACKING',
                      isEnabled: _hasPermission(auth, 'outbound:packing'),
                      onTap: () {},
                    ),
                    MenuCard(
                      title: 'Conferência',
                      subtitle: 'Check-out de expedição e validação de carga',
                      icon: LucideIcons.clipboard_check,
                      color: const Color(0xFF06B6D4),
                      badge: 'EXPEDIÇÃO',
                      isEnabled: _hasPermission(auth, 'outbound:checking'),
                      onTap: () {},
                    ),
                    MenuCard(
                      title: 'Inventário',
                      subtitle: 'Contagem física cega agrupada por posição',
                      icon: LucideIcons.eye_off,
                      color: const Color(0xFFEC4899),
                      badge: 'AUDITORIA',
                      isEnabled: _hasPermission(auth, 'cyclecount:execute'),
                      onTap: () {},
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
