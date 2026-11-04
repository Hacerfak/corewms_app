import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api/jwt_helper.dart';
import '../../../core/storage/storage_service.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, selectingCompany, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final StorageService _storage;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  UserMeResponse? _user;
  UserMeResponse? get user => _user;

  String? _selectedCompanyName;
  String? get selectedCompanyName => _selectedCompanyName;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  VoidCallback? onForceLogout;

  AuthProvider(this._repository, this._storage);

  /// Valida sessão existente ao abrir o aplicativo
  Future<void> checkSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      final refreshToken = await _storage.getRefreshToken();

      // Sem credenciais salvas
      if (token == null ||
          token.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        _status = AuthStatus.unauthenticated;
        return;
      }

      // 1. Se o token estiver expirado (ou a 60s de expirar), reautentica com refresh token
      if (JwtHelper.isExpired(token, thresholdSeconds: 60)) {
        debugPrint(
          '[AUTH] Token expirado ao iniciar app. Tentando reautenticação...',
        );
        final newToken = await _repository.refreshToken();

        if (newToken == null || newToken.isEmpty) {
          debugPrint('[AUTH] Refresh token expirado/inválido ao abrir.');
          await _storage.clearAll();
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Sua sessão expirou. Faça login novamente.';
          return;
        }
      }

      // 2. Com token válido/renovado, consulta o perfil atualizado e valida com o servidor
      final companyId = await _storage.getCompanyId();
      UserMeResponse? userMe;

      try {
        userMe = await _repository.getMe(companyId: companyId);
      } on DioException catch (e) {
        // Se a API rejeitou com 401 e o refresh também não foi possível
        if (e.response?.statusCode == 401) {
          await _storage.clearAll();
          _status = AuthStatus.unauthenticated;
          _errorMessage = 'Sua sessão expirou. Faça login novamente.';
          return;
        }
        // Em falhas pontuais de conexão (offline), restaura do cache local
        userMe = await _repository.getCachedUser();
      }

      if (userMe == null) {
        await _storage.clearAll();
        _status = AuthStatus.unauthenticated;
        return;
      }

      _user = userMe;

      if (companyId != null &&
          companyId.isNotEmpty &&
          userMe.companies.any((c) => c.id == companyId)) {
        _selectedCompanyName = await _storage.getCompanyName();
        _status = AuthStatus.authenticated;
      } else {
        _selectedCompanyName = null;
        _status = AuthStatus.selectingCompany;
      }
    } catch (e) {
      debugPrint('[AUTH] Falha ao verificar sessão: $e');
      await _storage.clearAll();
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Sua sessão expirou. Faça login novamente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza o login inicial
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _repository.login(email, password);

      if (_user!.companies.isEmpty) {
        throw Exception('Usuário sem vínculo com nenhuma empresa.');
      }

      if (_user!.companies.length == 1) {
        await selectCompany(_user!.companies.first);
      } else {
        _status = AuthStatus.selectingCompany;
        notifyListeners();
      }
      return true;
    } catch (e, stack) {
      debugPrint('[LOGIN ERROR]: $e');
      debugPrint('[LOGIN STACK]: $stack');

      if (e is DioException) {
        final serverMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  e.response?.data['error'])
            : null;

        _errorMessage =
            serverMessage?.toString() ??
            (e.type == DioExceptionType.connectionError
                ? 'Sem conexão com o servidor. Verifique o Wi-Fi.'
                : 'Falha na comunicação com a API (${e.response?.statusCode ?? "Rede"}).');
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seleção de empresa ativa
  Future<void> selectCompany(UserCompany company) async {
    _isLoading = true;
    notifyListeners();

    try {
      final permissions = await _repository.selectCompany(company);

      if (_user != null) {
        _user = _user!.copyWith(permissions: permissions);
      }

      _selectedCompanyName = company.corporateName;
      _status = AuthStatus.authenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Troca de empresa
  void switchCompany() {
    if (_user != null) {
      _user = _user!.copyWith(permissions: const []);
    }
    _selectedCompanyName = null;
    _status = AuthStatus.selectingCompany;
    notifyListeners();
  }

  /// Logout normal
  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _selectedCompanyName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Força o logout e redireciona imediatamente para o Login
  void forceLogout({String? reason}) {
    _user = null;
    _selectedCompanyName = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = reason ?? 'Sua sessão expirou. Faça login novamente.';
    notifyListeners();
    onForceLogout?.call();
  }
}
