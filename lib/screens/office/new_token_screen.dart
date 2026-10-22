import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../services/firestore_service.dart';
import '../../widgets/no_internet_banner.dart';

class NewTokenScreen extends StatefulWidget {
  const NewTokenScreen({super.key});

  @override
  State<NewTokenScreen> createState() => _NewTokenScreenState();
}

class _NewTokenScreenState extends State<NewTokenScreen> {
  static const Color _accent = Color(0xFF4DB6AC);
  static const Color _background = Color(0xFF092C26);
  static const Color _fieldBackground = Color(0xFF102F2B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _isLoading = false;
  StreamSubscription<int>? _tokenNumberSub;
  int? _nextTokenNumber; // null while the initial value is loading

  @override
  void initState() {
    super.initState();
    _tokenNumberSub = FirestoreService().streamNextTokenNumber().listen(
          (nextNumber) {
        if (mounted) {
          setState(() => _nextTokenNumber = nextNumber);
        }
      },
    );
  }

  Future<void> _generateToken() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Counter increment and token creation are handled atomically by FirestoreService.
      final tokenDocId = await FirestoreService().createToken(
        _nameController.text.trim(),
        _mobileController.text.trim(),
        'office',
      );
      FirestoreService().invalidateCache();

      final token = await FirestoreService().getTokenById(tokenDocId);

      if (token != null && mounted) {
        context.push(
          '/office/generated-token',
          extra: {
            'tokenId': token.id,
            'tokenNumber': token.tokenNumber,
            'parentName': token.parentName,
            'parentMobile': token.parentMobile,
          },
        );
      } else if (mounted) {
        _showMessage('Token created, but its details could not be loaded.');
      }
    } catch (e, stackTrace) {
      debugPrint('Token generation failed: $e\n$stackTrace');
      if (mounted) {
        _showMessage('Failed to generate token. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.outfit(fontSize: 14),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF263A36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  void dispose() {
    _tokenNumberSub?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
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
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Material(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/office/dashboard');
                                  }
                                },
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Token',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Create a token for a parent',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Live token number
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.045),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.09),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'NEXT TOKEN NUMBER',
                                style: GoogleFonts.outfit(
                                  color: _accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _nextTokenNumber == null
                                    ? const SizedBox(
                                  key: ValueKey('token-loading'),
                                  height: 54,
                                  width: 54,
                                  child: CircularProgressIndicator(
                                    color: _accent,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                    : Text(
                                  '#$_nextTokenNumber',
                                  key: ValueKey(_nextTokenNumber),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 54,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: _accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Updates automatically',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Parent name
                        _buildInputLabel('Parent full name'),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            'Enter full name',
                            Icons.person_outline_rounded,
                          ),
                          validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Parent mobile number
                        _buildInputLabel('Parent mobile number'),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: _inputDecoration(
                            'Enter 10-digit mobile number',
                            Icons.phone_iphone_rounded,
                          ),
                          validator: (value) =>
                          value == null || value.trim().length != 10
                              ? 'Enter a valid 10-digit number'
                              : null,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _generateToken();
                          },
                        ),

                        const SizedBox(height: 28),

                        // Generate token
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _generateToken,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: const Color(0xFF082923),
                              disabledBackgroundColor:
                              _accent.withOpacity(0.45),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF082923),
                                strokeWidth: 2.2,
                              ),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  'Generate Token',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white.withOpacity(0.82),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.09)),
    );

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _accent, size: 20),
      counterText: '',
      hintStyle: GoogleFonts.outfit(
        color: Colors.white.withOpacity(0.4),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      filled: true,
      fillColor: _fieldBackground,
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF9A9A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF9A9A), width: 1.3),
      ),
    );
  }
}
