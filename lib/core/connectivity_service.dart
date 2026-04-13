import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_state.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  StreamSubscription? _subscription;

  /// Call once from main.dart or splash
  /// Listens to connectivity changes instantly
  void init(AppState appState) {
    // Check immediately on start
    _checkAndUpdate(appState);

    // Listen for changes — fires instantly when network changes
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Small delay to let network stabilize
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkAndUpdate(appState);
    });
  }

  Future<void> _checkAndUpdate(AppState appState) async {
    final hasInternet = await _hasActualInternet();
    appState.updateInternet(hasInternet);
  }

  /// Connectivity plugin only checks if connected to WiFi/mobile
  /// but not if there's actual internet access.
  /// So we do a real lookup to verify actual internet.
  Future<bool> _hasActualInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
