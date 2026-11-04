import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import 'auth_provider.dart';
import 'widgets/server_config_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'master@corewms.com.br');
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
            _logoRefreshKey++; // Força a atualização do logo da rede
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final api = context.watch<ApiClient>();
    final logoUrl = '${api.baseUrl}/logo.png';

    return Scaffold(
      // Gradiente de fundo idêntico ao Web (from-slate-50 via-slate-100/60 to-slate-200/40)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // Slate 50
              Color(0xFFF1F5F9), // Slate 100
              Color(0xFFE2E8F0), // Slate 200
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Botão Configurar Servidor (Canto Superior Direito)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(
                    LucideIcons.settings,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  tooltip: 'Configurar Servidor',
                  onPressed: () => _openServerConfig(context),
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
                        // 1. CABEÇALHO COM LOGOTIPO DO CLIENTE DINÂMICO
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
                              // Placeholder elegante caso a URL seja inválida ou o servidor não tenha logo.png
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.warehouse,
                                      color: Color(0xFF2563EB),
                                      size: 26,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Armazém Geral',
                                      style: TextStyle(
                                        color: Color(0xFF0F172A),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Powered by ',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(
                                LucideIcons.box,
                                size: 13,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'CoreWMS',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. CARD DE LOGIN IDÊNTICO AO WEB
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF64748B)
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
                                // Linha Gradiente Azul no Topo do Card
                                Container(
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB), // Blue 600
                                        Color(0xFF3B82F6), // Blue 500
                                        Color(0xFF4F46E5), // Indigo 600
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
                                        // Título e Subtítulo
                                        const Text(
                                          'Acessar Plataforma',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Entre com suas credenciais para gerenciar a operação',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Alerta de Erro
                                        if (auth.errorMessage != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1F2),
                                              border: Border.all(
                                                color: const Color(0xFFFECDD3),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  LucideIcons.circle_alert,
                                                  color: Color(0xFFE11D48),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    auth.errorMessage!,
                                                    style: const TextStyle(
                                                      color: Color(0xFFBE123C),
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

                                        // Campo E-mail
                                        const Text(
                                          'E-mail corporativo',
                                          style: TextStyle(
                                            color: Color(0xFF334155),
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
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                          ),
                                          onFieldSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                          decoration: InputDecoration(
                                            hintText: 'nome@empresa.com',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                            ),
                                            prefixIcon: const Icon(
                                              LucideIcons.mail,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF2563EB),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                              ? 'Informe seu e-mail'
                                              : null,
                                        ),
                                        const SizedBox(height: 16),

                                        // Campo Senha
                                        const Text(
                                          'Senha',
                                          style: TextStyle(
                                            color: Color(0xFF334155),
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
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '••••••••',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                            ),
                                            prefixIcon: const Icon(
                                              LucideIcons.lock,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF2563EB),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.isEmpty)
                                              ? 'Informe sua senha'
                                              : null,
                                        ),
                                        const SizedBox(height: 22),

                                        // Botão Entrar na Conta (Escuro como na Web)
                                        SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading
                                                ? null
                                                : _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF0F172A,
                                              ), // Slate 900
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
                                                        LucideIcons.arrow_right,
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

                        // Rodapé
                        const SizedBox(height: 24),
                        const Text(
                          'CoreWMS • Sistema Inteligente de Gestão de Armazéns',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Overlay de Autenticação em Tela Cheia (Igual à Web)
              if (auth.isLoading)
                Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 20),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Autenticando...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sincronizando credenciais e ambiente.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
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
