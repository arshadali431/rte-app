import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';

class OfficeLoginScreen extends StatefulWidget {
  const OfficeLoginScreen({super.key});

  @override
  State<OfficeLoginScreen> createState() => _OfficeLoginScreenState();
}

class _OfficeLoginScreenState extends State<OfficeLoginScreen>
    with MaintenanceWatcher {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockSecondsRemaining = 0;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
  }

  void _startLockout() {
    setState(() {
      _isLocked = true;
      _lockSecondsRemaining = 30;
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockSecondsRemaining--;
        if (_lockSecondsRemaining <= 0) {
          _isLocked = false;
          _failedAttempts = 0;
          _lockSecondsRemaining = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _login() async {
    // Check if locked
    if (_isLocked) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter username and password'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService().signIn(username, password);

      if (success) {
        await AuthService().saveLoginState(username);
        if (mounted) context.go('/office/dashboard');
      } else {
        _failedAttempts++;
        _usernameController.clear();
        _passwordController.clear();

        if (_failedAttempts >= 3) {
          _startLockout();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Too many failed attempts. Please wait 30 seconds.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Invalid credentials. ${3 - _failedAttempts} attempt(s) remaining.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    stopMaintenanceWatch();
    _lockTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const NoInternetBanner(),
          Expanded(
            child: Container(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => context.go('/role'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 56,
                      color: Color(0xFF81D4FA),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Office Login',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Enter your credentials to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3535),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Username
                      _buildLabel('Username'),
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          'Enter username',
                          Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password
                      _buildLabel('Password'),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          'Enter password',
                          Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white38,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isLoading || _isLocked) ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isLocked ? Colors.grey[700] : const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : _isLocked
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.lock_clock_rounded, size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Try again in ${_lockSecondsRemaining}s',
                                          style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    )
                                  : Text('Login',
                                      style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_failedAttempts > 0 && !_isLocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _failedAttempts
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${3 - _failedAttempts} attempt(s) remaining',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Text(
                  'For Office username and password contact',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Email: arshadali.app431@gmail.com',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF81D4FA).withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ],
),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0D2B2B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF81D4FA), width: 1.5),
      ),
    );
  }
}
