import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/theme_provider.dart';
import 'auth_provider.dart';
import 'widgets/server_config_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  int _logoRefreshKey = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthProvider>().login(
        _emailController.text,
        _passwordController.text,
      );
    }
  }

  void _openServerConfig(BuildContext context) {
    final storage = context.read<StorageService>();
    final api = context.read<ApiClient>();

    showDialog(
      context: context,
      builder: (_) => ServerConfigDialog(
        apiClient: api,
        storageService: storage,
        onSaved: () {
          setState(() {
            _logoRefreshKey++;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final api = context.watch<ApiClient>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logoUrl = '${api.baseUrl}/logo.png';

    // Variáveis que alternam conforme o tema ativo
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final inputFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final inputBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final primaryBtnBg = isDark
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F172A);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF0A0F1D),
                    Color(0xFF020617),
                  ]
                : const [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Botões Superiores: Alternar Tema (Sol/Lua) e Configuração do Servidor
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isDark ? LucideIcons.sun : LucideIcons.moon,
                        color: subtitleColor,
                        size: 20,
                      ),
                      tooltip: isDark
                          ? 'Ativar Tema Claro'
                          : 'Ativar Tema Escuro',
                      onPressed: () => themeProvider.toggleTheme(),
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.settings,
                        color: subtitleColor,
                        size: 20,
                      ),
                      tooltip: 'Configurar Servidor',
                      onPressed: () => _openServerConfig(context),
                    ),
                  ],
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 1. LOGO DINÂMICO
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 90,
                            maxWidth: 260,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Image.network(
                            logoUrl,
                            key: ValueKey('$logoUrl-$_logoRefreshKey'),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.warehouse,
                                      color: Color(0xFF2563EB),
                                      size: 26,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Armazém Geral',
                                      style: TextStyle(
                                        color: titleColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // 2. SELO "POWERED BY COREWMS"
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.03,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Powered by ',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Icon(
                                LucideIcons.box,
                                size: 13,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'CoreWMS',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. CARD DE LOGIN ADAPTÁVEL
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : const Color(0xFF64748B)
                                          .withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF3B82F6),
                                        Color(0xFF4F46E5),
                                      ],
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    24,
                                    24,
                                    28,
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Acessar Plataforma',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Entre com suas credenciais para gerenciar a operação',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        if (auth.errorMessage != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF450A0A)
                                                  : const Color(0xFFFFF1F2),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF991B1B)
                                                    : const Color(0xFFFECDD3),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  LucideIcons
                                                      .circle_exclamation_point,
                                                  color: isDark
                                                      ? const Color(0xFFFCA5A5)
                                                      : const Color(0xFFE11D48),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    auth.errorMessage!,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFFCA5A5,
                                                            )
                                                          : const Color(
                                                              0xFFBE123C,
                                                            ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],

                                        Text(
                                          'E-mail corporativo',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 14,
                                          ),
                                          onFieldSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                          decoration: InputDecoration(
                                            hintText: 'nome@empresa.com',
                                            prefixIcon: Icon(
                                              LucideIcons.mail,
                                              color: subtitleColor,
                                              size: 18,
                                            ),
                                            filled: true,
                                            fillColor: inputFill,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: inputBorder,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: inputBorder,
                                              ),
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                              ? 'Informe seu e-mail'
                                              : null,
                                        ),
                                        const SizedBox(height: 16),

                                        Text(
                                          'Senha',
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          obscureText: true,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _submit(),
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 14,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '••••••••',
                                            prefixIcon: Icon(
                                              LucideIcons.lock,
                                              color: subtitleColor,
                                              size: 18,
                                            ),
                                            filled: true,
                                            fillColor: inputFill,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: inputBorder,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: inputBorder,
                                              ),
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.isEmpty)
                                              ? 'Informe sua senha'
                                              : null,
                                        ),
                                        const SizedBox(height: 22),

                                        SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading
                                                ? null
                                                : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryBtnBg,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              elevation: 2,
                                            ),
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Entrar na Conta',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        LucideIcons.log_in,
                                                        size: 16,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'CoreWMS • Sistema Inteligente de Gestão de Armazéns',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Overlay de Carregamento
              if (auth.isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Autenticando...',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sincronizando credenciais e ambiente.',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
