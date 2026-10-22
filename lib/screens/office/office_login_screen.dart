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
      body: Stack(
        children: [
          // 1. Dynamic Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF004D40), // Deep Teal
                  Color(0xFF00251A), // Darker Teal
                  Color(0xFF0D2B2B), // Very Dark
                ],
              ),
            ),
          ),
          
          // 2. Decorative Background blobs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00796B).withOpacity(0.1),
              ),
            ),
          ),

          // 3. Content
          Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        // Back Button
                        Align(
                          alignment: Alignment.topLeft,
                          child: InkWell(
                            onTap: () => context.go('/role'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        // Admin Icon
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 50,
                            color: Color(0xFFFFD54F),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        Text(
                          'Office Login',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your credentials to access the portal',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Glass Login Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('Username'),
                              TextField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  'Enter username',
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 24),
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
                              
                              // Premium Login Button
                              SizedBox(
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _isLocked) ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isLocked 
                                        ? Colors.grey[800] 
                                        : const Color(0xFF00796B),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : _isLocked
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.lock_clock_rounded, size: 20),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Try in ${_lockSecondsRemaining}s',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              'Login',
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        if (_failedAttempts > 0 && !_isLocked) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                width: 12,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: index < _failedAttempts
                                      ? Colors.redAccent
                                      : Colors.white12,
                                ),
                              );
                            }),
                          ),
                        ],
                        
                        const SizedBox(height: 48),
                        Text(
                          'For Office credentials contact',
                          style: GoogleFonts.outfit(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Email: arshadali.app431@gmail.com',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFFD54F).withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
