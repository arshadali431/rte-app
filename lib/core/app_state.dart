import 'package:flutter/material.dart';
import '../models/maintenance_model.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // Maintenance
  MaintenanceModel _maintenance = MaintenanceModel.defaults();
  MaintenanceModel get maintenance => _maintenance;

  void updateMaintenance(MaintenanceModel model) {
    _maintenance = model;
    notifyListeners();
  }

  // Internet
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  void updateInternet(bool status) {
    if (_hasInternet != status) {
      _hasInternet = status;
      notifyListeners();
    }
  }
}
