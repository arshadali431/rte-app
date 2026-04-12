import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/firestore_service.dart';

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
        'office', // createdBy
      );

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
      backgroundColor: const Color(0xFF0D2B2B),
      appBar: AppBar(
        title: Text('New Token', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/office/dashboard');
            }
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B2B), Color(0xFF0A1A1A)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Generate Token',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill details to generate a new token for the family',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                ),
                
                const SizedBox(height: 32),

                // Realtime Token Number Display Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3535),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF81D4FA).withOpacity(0.3), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOKEN WILL BE ALLOCATED',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white38,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _nextTokenNumber == null
                          ? const SizedBox(
                              height: 48,
                              width: 48,
                              child: CircularProgressIndicator(
                                color: Color(0xFF81D4FA),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '#$_nextTokenNumber',
                              style: GoogleFonts.outfit(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF81D4FA),
                                height: 1,
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        'This number updates live',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                
                _buildInputLabel('Parent Name'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Enter full name', Icons.person_outline_rounded),
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 24),
                _buildInputLabel('Parent Mobile'),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('10-digit number', Icons.phone_iphone_rounded),
                  validator: (v) => v!.length != 10 ? 'Enter valid 10-digit number' : null,
                ),
                const SizedBox(height: 60),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _generateToken,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Generate Token', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
