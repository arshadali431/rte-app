import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../models/token_model.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> with SingleTickerProviderStateMixin {
  TokenModel? _token;
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenId = prefs.getString('token_id');

      if (tokenId != null) {
        final token = await FirestoreService().getTokenById(tokenId);
        if (mounted) {
          setState(() {
            _token = token;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Application Status', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF00796B),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                   if (_token?.applicationId != null) ...[
                     _buildPriorityIdCard(),
                     const SizedBox(height: 24),
                   ],
                   _buildStatusHeader(),
                   const SizedBox(height: 24),
                   _buildDetailsCard(),
                   const SizedBox(height: 24),
                   _buildNextStepsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPriorityIdCard() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1).withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00796B).withOpacity(_pulseAnimation.value),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎉', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text(
                    'Application ID Received!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SelectableText(
                _token!.applicationId!,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Child DOB: ${_token!.childDob}',
                style: GoogleFonts.outfit(color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _token!.applicationId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application ID copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Application ID'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00796B),
                    side: const BorderSide(color: Color(0xFF00796B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader() {
    final status = _token!.status;
    Color color;
    IconData icon;
    String description;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule_rounded;
        description = 'Your application has been received. Our team will review it shortly.';
        break;
      case 'in_progress':
        color = Colors.blue;
        icon = Icons.sync_rounded;
        description = 'Your application is currently being processed by our team.';
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        description = 'Your application process is complete. Please contact our office for next steps.';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline_rounded;
        description = 'Status unknown. Please contact support.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 60, color: color),
          const SizedBox(height: 16),
          Text(
            status.toUpperCase().replaceAll('_', ' '),
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _buildCard(
      title: 'Application Details',
      child: Column(
        children: [
          _buildInfoRow('Token Number', '#${_token!.tokenNumber}'),
          _buildInfoRow('Parent Name', _token!.parentName),
          _buildInfoRow('Parent Mobile', _token!.parentMobile),
          _buildInfoRow('Submitted On', DateFormat('dd MMM yyyy').format(_token!.createdAt ?? DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return _buildCard(
      title: "What's Next?",
      child: Column(
        children: [
          _buildStepRow(1, 'Complete your child profile'),
          _buildStepRow(2, 'Upload all required documents'),
          _buildStepRow(3, 'Visit our office on your scheduled date'),
          _buildStepRow(4, 'Await school allocation result'),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStepRow(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$num', style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: GoogleFonts.outfit(color: Colors.grey[700], fontSize: 14))),
        ],
      ),
    );
  }
}
