import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../core/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  StreamSubscription? _maintenanceStream;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initApp();
  }

  void _initAnimations() {
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  Future<void> _initApp() async {
    // Start realtime maintenance stream — updates AppState globally
    _maintenanceStream = FirestoreService()
        .streamMaintenanceStatus()
        .listen((maintenance) {
          if (mounted) {
            context.read<AppState>().updateMaintenance(maintenance);
          }
        });

    // Wait for splash duration (at least 2s, but 3s for premium feel)
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    await _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    // Read from AppState (already fetched by stream)
    final appState = context.read<AppState>();

    if (appState.maintenance.centralMaintenance) {
      if (mounted) context.go('/maintenance/central');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final tokenId = prefs.getString('token_id');
    final isOfficeLoggedIn = prefs.getBool('is_office_logged_in') ?? false;

    if (tokenId != null && tokenId.isNotEmpty) {
      if (mounted) context.go('/parent/dashboard', extra: tokenId);
    } else if (isOfficeLoggedIn) {
      if (mounted) context.go('/office/dashboard');
    } else {
      if (mounted) context.go('/role');
    }
  }

  @override
  void dispose() {
    _maintenanceStream?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D2B2B),
                Color(0xFF004D40),
                Color(0xFF00796B),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scale,
                        child: FadeTransition(
                          opacity: _fade,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/app_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.how_to_reg_rounded,
                                          size: 60, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SlideTransition(
                        position: _slide,
                        child: FadeTransition(
                          opacity: _fade,
                          child: Column(
                            children: [
                              Text(
                                'RTE Status Checker',
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Track Your Future Instantly',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.6),
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Text(
                        'VERSION 1.0.0',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
