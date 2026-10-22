import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';
import '../../widgets/privacy_policy_link.dart';

class OfficeLoginScreen extends StatefulWidget {
  const OfficeLoginScreen({super.key});

  @override
  State<OfficeLoginScreen> createState() => _OfficeLoginScreenState();
}

class _OfficeLoginScreenState extends State<OfficeLoginScreen>
    with MaintenanceWatcher {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockSecondsRemaining = 0;
  Timer? _lockTimer;

  static const _accent = Color(0xFF4DB6AC);
  static const _background = Color(0xFF082923);
  static const _fieldBackground = Color(0xFF102F2B);

  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
  }

  void _startLockout() {
    _lockTimer?.cancel();
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

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFB83A46) : const Color(0xFF257B69),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    if (_isLocked || _isLoading) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Please enter your username and password.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final success = await AuthService().signIn(username, password);

      if (!mounted) return;

      if (success) {
        await AuthService().saveLoginState(username);
        if (mounted) context.go('/office/dashboard');
      } else {
        _failedAttempts++;
        _usernameController.clear();
        _passwordController.clear();

        if (_failedAttempts >= 3) {
          _startLockout();
          _showMessage('Too many failed attempts. Please wait 30 seconds.');
        } else {
          _showMessage(
            'Invalid credentials. ${3 - _failedAttempts} attempt(s) remaining.',
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Office login failed: $e\n$stackTrace');
      _showMessage('Something went wrong. Please try again.');
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
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Container(
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
          child: Column(
            children: [
              const NoInternetBanner(),
              Expanded(
                child: Stack(
                  children: [
                    // Main content remains vertically balanced and scrollable.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 440),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Keep the original space so the form position does not shift.
                                    //const SizedBox(height: 44),
                                    //const SizedBox(height: 28),

                                    // Screen heading
                                    Row(
                                      children: [
                                        // Container(
                                        //   width: 48,
                                        //   height: 48,
                                        //   decoration: BoxDecoration(
                                        //     color: _accent.withOpacity(0.12),
                                        //     borderRadius: BorderRadius.circular(14),
                                        //   ),
                                        //   child: const Icon(
                                        //     Icons.admin_panel_settings_outlined,
                                        //     color: _accent,
                                        //     size: 27,
                                        //   ),
                                        // ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Office Login',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 27,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Sign in to manage RTE applications',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: Colors.white.withOpacity(0.64),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 28),

                                    // Login form
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.045),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.09),
                                        ),
                                      ),
                                      child: AutofillGroup(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildLabel('Username'),
                                            TextField(
                                              controller: _usernameController,
                                              enabled: !_isLocked && !_isLoading,
                                              textInputAction: TextInputAction.next,
                                              autofillHints: const [AutofillHints.username],
                                              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                              decoration: _inputDecoration(
                                                'Enter username',
                                                Icons.person_outline_rounded,
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            _buildLabel('Password'),
                                            TextField(
                                              controller: _passwordController,
                                              focusNode: _passwordFocusNode,
                                              enabled: !_isLocked && !_isLoading,
                                              obscureText: _obscurePassword,
                                              textInputAction: TextInputAction.done,
                                              autofillHints: const [AutofillHints.password],
                                              onSubmitted: (_) => _login(),
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                              decoration: _inputDecoration(
                                                'Enter password',
                                                Icons.lock_outline_rounded,
                                                suffixIcon: IconButton(
                                                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                                  onPressed: () => setState(
                                                        () => _obscurePassword = !_obscurePassword,
                                                  ),
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons.visibility_outlined
                                                        : Icons.visibility_off_outlined,
                                                    size: 20,
                                                    color: Colors.white.withOpacity(0.58),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_failedAttempts > 0) ...[
                                              const SizedBox(height: 14),
                                              Row(
                                                children: List.generate(3, (index) {
                                                  final failed = index < _failedAttempts;
                                                  return Expanded(
                                                    child: Container(
                                                      margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(4),
                                                        color: failed
                                                            ? const Color(0xFFE57373)
                                                            : Colors.white.withOpacity(0.12),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _isLocked
                                                    ? 'Login temporarily locked. Try again in ${_lockSecondsRemaining}s.'
                                                    : '${3 - _failedAttempts} attempt(s) remaining',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  color: _isLocked
                                                      ? const Color(0xFFFFAB91)
                                                      : Colors.white.withOpacity(0.58),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 24),
                                            SizedBox(
                                              height: 50,
                                              child: ElevatedButton(
                                                onPressed: (_isLoading || _isLocked) ? null : _login,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _accent,
                                                  foregroundColor: _background,
                                                  disabledBackgroundColor: _accent.withOpacity(0.35),
                                                  disabledForegroundColor: Colors.white70,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    color: _background,
                                                    strokeWidth: 2.2,
                                                  ),
                                                )
                                                    : _isLocked
                                                    ? Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.lock_clock_rounded, size: 18),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Try again in ${_lockSecondsRemaining}s',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                    : Text(
                                                  'Login',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Center(
                                      child: PrivacyPolicyLink(
                                        language: 'en',
                                        color: _accent.withValues(alpha: 0.85),
                                        dense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 15,
                                          color: Colors.white.withOpacity(0.42),
                                        ),
                                        const SizedBox(width: 7),
                                        Flexible(
                                          child: Text(
                                            'For office access, contact your administrator.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.48),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Fixed back button: anchored near the top-left of the app content.
                    Positioned(
                      top: 12,
                      left: 20,
                      child: Material(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.go('/role'),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.78),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
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
      hintStyle: GoogleFonts.outfit(
        color: Colors.white.withOpacity(0.38),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withOpacity(0.58),
        size: 19,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.3),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
      ),
    );
  }
}
