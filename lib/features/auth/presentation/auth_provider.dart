import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../../../core/storage/storage_service.dart';

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

  AuthProvider(this._repository, this._storage);

  /// Valida sessão existente ao abrir o aplicativo
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
      } else {
        final companyId = await _storage.getCompanyId();

        if (companyId != null && companyId.isNotEmpty) {
          // Empresa já selecionada anteriormente: busca permissões dela
          final permissions = await _repository.fetchCompanyPermissions(
            companyId,
          );
          _user = await _repository.getCachedUser(permissions: permissions);
          _selectedCompanyName = await _storage.getCompanyName();
          _status = AuthStatus.authenticated;
        } else {
          // Token válido, mas sem empresa escolhida: redireciona para seleção
          _user = await _repository.getCachedUser(permissions: const []);
          _status = AuthStatus.selectingCompany;
        }
      }
    } catch (_) {
      await _storage.clearAll();
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza o login. Se possuir 1 empresa só, seleciona automaticamente.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _repository.login(email, password);

      if (_user!.companies.isEmpty) {
        throw Exception('Usuário sem vínculo com nenhuma empresa.');
      }

      // Se possui apenas 1 empresa vinculada, seleciona e carrega permissões imediatamente
      if (_user!.companies.length == 1) {
        await selectCompany(_user!.companies.first);
      } else {
        // Múltiplas empresas: vai para a tela de seleção sem chamar permissões ainda
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

  /// Disparado ao tocar em uma empresa: busca as permissões daquela unidade e avança
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

  /// Retorna à tela de escolha de armazém/empresa e limpa permissões ativas
  void switchCompany() {
    if (_user != null) {
      _user = _user!.copyWith(permissions: const []);
    }
    _selectedCompanyName = null;
    _status = AuthStatus.selectingCompany;
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _selectedCompanyName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
