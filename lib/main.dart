import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/scanner/scanner_service.dart';
import 'core/storage/storage_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/company_selection_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/hu/data/hu_repository.dart';
import 'features/hu/presentation/hu_provider.dart';
import 'features/printing/data/printing_repository.dart';
import 'features/printing/presentation/printing_provider.dart';
import 'features/quality/data/quality_repository.dart';
import 'features/quality/presentation/quality_provider.dart';
import 'features/inbound/data/inbound_repository.dart';
import 'features/inbound/presentation/inbound_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  final api = ApiClient(storage);
  final authRepository = AuthRepository(api, storage);
  final scannerService = ScannerService()..initialize();
  final huRepository = HuRepository(api);
  final printingRepository = PrintingRepository(api);
  final qualityRepository = QualityRepository(api);
  final inboundRepository = InboundRepository(api);

  runApp(
    MultiProvider(
      providers: [
        Provider<ScannerService>.value(value: scannerService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authRepository, storage)..checkSession(),
        ),
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
    return MaterialApp(
      title: 'CoreWMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF1E293B),
        ),
      ),
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
