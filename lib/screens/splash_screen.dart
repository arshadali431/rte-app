import 'dart:async';

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

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _ctrl.forward();
  }

  Future<void> _initApp() async {
    // Keep maintenance state updated while the splash screen is visible.
    _maintenanceStream = FirestoreService()
        .streamMaintenanceStatus()
        .listen((maintenance) {
      if (mounted) {
        context.read<AppState>().updateMaintenance(maintenance);
      }
    });

    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    await _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    final appState = context.read<AppState>();
    if (appState.maintenance.centralMaintenance) {
      context.go('/maintenance/central');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final tokenId = prefs.getString('token_id');
    final isOfficeLoggedIn = prefs.getBool('is_office_logged_in') ?? false;

    if (!mounted) return;

    if (tokenId != null && tokenId.isNotEmpty) {
      context.go('/parent/dashboard', extra: tokenId);
    } else if (isOfficeLoggedIn) {
      context.go('/office/dashboard');
    } else {
      context.go('/role');
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
    const accent = Color(0xFF4DB6AC);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF092C26),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF103D35),
                Color(0xFF092C26),
                Color(0xFF081F20),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 76),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 108,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScaleTransition(
                                  scale: _scale,
                                  child: FadeTransition(
                                    opacity: _fade,
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.10),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/app_logo.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                        const Icon(
                                          Icons.how_to_reg_rounded,
                                          size: 48,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                SlideTransition(
                                  position: _slide,
                                  child: FadeTransition(
                                    opacity: _fade,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'RTE Status Checker',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        Text(
                                          'Track Your Future Instantly',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            color: Colors.white.withOpacity(0.68),
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const SizedBox(height: 22),
                                        Container(
                                          width: 34,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: accent.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(8),
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
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: FadeTransition(
                          opacity: _fade,
                          child: Text(
                            'VERSION 1.0.0',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.42),
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
