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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLoading = false;
  
  StreamSubscription<int>? _tokenNumberSub;
  int? _nextTokenNumber; // null = loading

  @override
  void initState() {
    super.initState();
    _tokenNumberSub = FirestoreService()
        .streamNextTokenNumber()
        .listen((nextNumber) {
          if (mounted) {
            setState(() => _nextTokenNumber = nextNumber);
          }
        });
  }

  Future<void> _generateToken() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // createToken now handles counter increment + doc creation atomically
      final tokenDocId = await FirestoreService().createToken(
        _nameController.text.trim(),
        _mobileController.text.trim(),
        'office',
      );
      FirestoreService().invalidateCache(); // Bust count cache so dashboard shows +1

      // Fetch the created token to get tokenNumber and verify
      final token = await FirestoreService().getTokenById(tokenDocId);

      if (token != null && mounted) {
        context.push('/office/generated-token', extra: {
          'tokenId': token.id,
          'tokenNumber': token.tokenNumber,
          'parentName': token.parentName,
          'parentMobile': token.parentMobile,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate token. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          // Premium Navigation Header
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/office/dashboard');
                                  }
                                },
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
                              const SizedBox(width: 16),
                              Text(
                                'New Token',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Realtime Token Number Display Card (Enhanced Glassmorphism)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFF4DB6AC).withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'NEXT ALLOCATED TOKEN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF4DB6AC),
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _nextTokenNumber == null
                                    ? const SizedBox(
                                        height: 60,
                                        width: 60,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF4DB6AC),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        '#$_nextTokenNumber',
                                        style: GoogleFonts.outfit(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1,
                                          shadows: [
                                            Shadow(
                                              color: const Color(0xFF4DB6AC).withOpacity(0.5),
                                              blurRadius: 15,
                                            ),
                                          ],
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4DB6AC).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF4DB6AC)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'LIVE UPDATE',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: const Color(0xFF4DB6AC),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 48),

                          _buildInputLabel('Parent Full Name'),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                                'Enter full name', Icons.person_outline_rounded),
                            validator: (v) => v!.isEmpty ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 28),
                          _buildInputLabel('Parent Mobile Number'),
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                '10-digit number', Icons.phone_iphone_rounded),
                            validator: (v) =>
                                v!.length != 10 ? 'Enter valid 10-digit number' : null,
                          ),
                          
                          const SizedBox(height: 60),
                          
                          // Generate Button
                          SizedBox(
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _generateToken,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00796B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      'Generate Token',
                                      style: GoogleFonts.outfit(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      counterText: '',
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: const Color(0xFF1A3535),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF81D4FA), width: 1.5)),
    );
  }
}
