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

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
      } else {
        final companyId = await _storage.getCompanyId();
        _user = await _repository.getUserPermissions();

        if (companyId != null && companyId.isNotEmpty) {
          _selectedCompanyName = await _storage.getCompanyName();
          _status = AuthStatus.authenticated;
        } else {
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

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.login(email, password);
      _user = await _repository.getUserPermissions();

      if (_user!.companies.isEmpty) {
        throw Exception('Usuário não possui vínculo com nenhuma empresa.');
      }

      // Se possui apenas 1 empresa vinculada, seleciona automaticamente
      if (_user!.companies.length == 1) {
        await selectCompany(_user!.companies.first);
      } else {
        _status = AuthStatus.selectingCompany;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e is Exception
          ? e.toString().replaceAll('Exception: ', '')
          : 'Erro ao realizar login.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCompany(UserCompany company) async {
    _isLoading = true;
    notifyListeners();

    await _repository.selectCompany(company);
    _selectedCompanyName = company.corporateName;
    _status = AuthStatus.authenticated;

    _isLoading = false;
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
