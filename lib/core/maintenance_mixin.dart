import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

mixin MaintenanceWatcher<T extends StatefulWidget> on State<T> {
  
  void startMaintenanceWatch() {
    // Listen to AppState changes (already updated by splash stream)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Initial check
      _checkMaintenance();
      
      // Listen for future changes
      context.read<AppState>().addListener(_checkMaintenance);
    });
  }

  void _checkMaintenance() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    if (appState.maintenance.centralMaintenance) {
      context.go('/maintenance/central');
    }
  }

  void stopMaintenanceWatch() {
    try {
      if (mounted) {
        context.read<AppState>().removeListener(_checkMaintenance);
      }
    } catch (_) {
      // Ignore if provider not found or already disposed
    }
  }
}
