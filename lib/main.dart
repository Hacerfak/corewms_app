import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/scanner/scanner_service.dart';
import 'core/storage/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/company_selection_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/hu/data/hu_repository.dart';
import 'features/hu/presentation/hu_provider.dart';
import 'features/inbound/data/inbound_repository.dart';
import 'features/inbound/presentation/inbound_provider.dart';
import 'features/printing/data/printing_repository.dart';
import 'features/printing/presentation/printing_provider.dart';
import 'features/quality/data/quality_repository.dart';
import 'features/quality/presentation/quality_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final initialBaseUrl = await storage.getBaseUrl();
  final api = ApiClient(storage, initialBaseUrl: initialBaseUrl);

  final authRepository = AuthRepository(api, storage);
  final scannerService = ScannerService()..initialize();
  final huRepository = HuRepository(api);
  final printingRepository = PrintingRepository(api);
  final qualityRepository = QualityRepository(api);
  final inboundRepository = InboundRepository(api);

  final authProvider = AuthProvider(authRepository, storage);

  api.onSessionExpired = (reason) {
    authProvider.forceLogout(reason: reason);
  };

  authProvider.onForceLogout = () {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ), // <-- Provedor de Tema
        Provider<StorageService>.value(value: storage),
        Provider<ApiClient>.value(value: api),
        Provider<ScannerService>.value(value: scannerService),
        ChangeNotifierProvider.value(value: authProvider..checkSession()),
        ChangeNotifierProvider(create: (_) => HuProvider(huRepository)),
        ChangeNotifierProvider(
          create: (_) => PrintingProvider(printingRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => QualityProvider(qualityRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => InboundProvider(inboundRepository),
        ),
      ],
      child: const CoreWmsApp(),
    ),
  );
}

class CoreWmsApp extends StatelessWidget {
  const CoreWmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CoreWMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode, // <-- Responde dinamicamente ao tema
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.unknown:
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              );
            case AuthStatus.unauthenticated:
              return const LoginScreen();
            case AuthStatus.selectingCompany:
              return const CompanySelectionScreen();
            case AuthStatus.authenticated:
              return const HomeScreen();
          }
        },
      ),
    );
  }
}
