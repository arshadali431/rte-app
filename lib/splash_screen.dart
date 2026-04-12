import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIcon;
  late final Animation<double> _fadeTitle;
  late final Animation<Offset> _slideTitle;
  late final Animation<double> _fadeSub;
  late final Animation<double> _fadeFooter;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeIcon = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _fadeTitle = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
    );
    _slideTitle = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
    ));
    _fadeSub = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
    );
    _fadeFooter = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 3000), () { // splashScreen sec controls
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF004D40),
              Color(0xFF00796B),
              Color(0xFF26A69A),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fadeIcon,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/app_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SlideTransition(
              position: _slideTitle,
              child: FadeTransition(
                opacity: _fadeTitle,
                child: Text(
                  'RTE Status Checker',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeSub,
              child: Text(
                'Instant Application Tracking',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fadeFooter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 40),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                // child: Text(
                //   'SIT SURAT 104',
                //   style: GoogleFonts.outfit(
                //     fontSize: 16,
                //     fontWeight: FontWeight.w600,
                //     color: Colors.white.withOpacity(0.9),
                //     letterSpacing: 1.2,
                //   ),
                // ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
