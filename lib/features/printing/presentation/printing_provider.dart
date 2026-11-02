import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/printing_models.dart';
import '../data/printing_repository.dart';

class PrintingProvider extends ChangeNotifier {
  final PrintingRepository _repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPrinting = false;
  bool get isPrinting => _isPrinting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<PrintAgentModel> _agents = [];
  List<PrintAgentModel> get agents => _agents;

  List<LabelTemplateModel> _templates = [];
  List<LabelTemplateModel> get templates => _templates;

  PrintingProvider(this._repository);

  /// Carrega as opções de hardware e templates do armazém
  Future<void> loadOptions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getAgents(),
        _repository.getTemplates(),
      ]);

      _agents = results[0] as List<PrintAgentModel>;
      _templates = results[1] as List<LabelTemplateModel>;
    } catch (e) {
      _errorMessage = 'Falha ao carregar impressoras e templates.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Despacha impressão para HUs
  Future<bool> printHus({
    required List<String> huIds,
    required String templateId,
    required String stationName,
    required String printerName,
    int copies = 1,
  }) async {
    _isPrinting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      for (int i = 0; i < copies; i++) {
        await _repository.printHandlingUnits(
          huIds: huIds,
          templateId: templateId,
          stationName: stationName,
          printerName: printerName,
        );
      }
      return true;
    } catch (e) {
      if (e is DioException) {
        _errorMessage = e.response?.data is Map
            ? (e.response?.data['message'] ??
                  e.response?.data['Message'] ??
                  'Falha ao despachar impressão.')
            : 'Erro ao comunicar com a fila de impressão.';
      } else {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      notifyListeners();
      return false;
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }

  /// Carrega predefinições salvas localmente no coletor
  Future<Map<String, String?>> getSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'station': prefs.getString('default_print_station'),
      'printer': prefs.getString('default_printer_name'),
      'templateId': prefs.getString('default_template_id'),
    };
  }

  /// Salva a impressora predefinida para as próximas operações
  Future<void> savePreferences({
    required String station,
    required String printer,
    required String templateId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_print_station', station);
    await prefs.setString('default_printer_name', printer);
    await prefs.setString('default_template_id', templateId);
  }
}
