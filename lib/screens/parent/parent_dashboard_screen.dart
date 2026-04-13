import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/firestore_service.dart';
import '../../models/token_model.dart';
import '../../core/maintenance_mixin.dart';
import '../../widgets/no_internet_banner.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with MaintenanceWatcher {
  TokenModel? _token;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    startMaintenanceWatch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadToken();
    });
  }

  @override
  void dispose() {
    stopMaintenanceWatch();
    super.dispose();
  }

  Future<void> _loadToken() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = GoRouterState.of(context);
      String? tokenId = state.extra as String?;

      if (tokenId == null || tokenId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        tokenId = prefs.getString('token_id');
      }

      if (tokenId != null && tokenId.isNotEmpty) {
        final token = await FirestoreService().getTokenById(tokenId);
        if (mounted) {
          if (token == null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('token_id');
            await prefs.remove('token_number');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Session expired or token invalid. Please regenerate token.',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              context.go('/role');
            }
            return;
          }
          setState(() {
            _token = token;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) context.go('/role');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to load dashboard data.";
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showProfile() {
    if (_token == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _token!.parentName,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _token!.parentMobile,
                style: GoogleFonts.outfit(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Token #${_token!.tokenNumber}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00796B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('token_id');
                    await prefs.remove('token_number');
                    if (context.mounted) context.go('/role');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

  void _showQrCode() {
    if (_token == null) return;
    final String qrJson = jsonEncode({
      'tokenId': _token!.id,
      'tokenNumber': _token!.tokenNumber,
      'parentName': _token!.parentName,
      'parentMobile': _token!.parentMobile,
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My QR Code',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            QrImageView(
              data: qrJson,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF004D40),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This QR will be scanned at our office',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // do nothing
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            'My Application',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _showProfile,
              icon: const Icon(Icons.person_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            const NoInternetBanner(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00796B)),
                    )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadToken,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadToken,
                    color: const Color(0xFF00796B),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeCard(),
                          const SizedBox(height: 32),
                          Text(
                            'QUICK ACTIONS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMenuCard(
                                  icon: Icons.child_care_rounded,
                                  title: 'Child Profile',
                                  onTap: () => context.push(
                                    '/parent/child-profile',
                                    extra: _token!.id,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMenuCard(
                                  icon: Icons.assignment_turned_in_rounded,
                                  title: 'Application Status',
                                  subtitle: _token!.applicationId != null
                                      ? 'Application ID received!'
                                      : _token!.status.toUpperCase().replaceAll(
                                          '_',
                                          ' ',
                                        ),
                                  subtitleColor: _token!.applicationId != null
                                      ? Colors.green
                                      : _getStatusColor(_token!.status),
                                  showBadge: _token!.applicationId != null,
                                  onTap: () => context.push(
                                    '/parent/status',
                                    extra: _token!.id,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildMenuCardWide(
                            icon: Icons.upload_file_rounded,
                            title: 'Upload Documents',
                            subtitle: 'Crops, compress and upload vault',
                            onTap: () =>
                                context.push('/parent/documents', extra: _token!.id),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    if (_token == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${_token!.parentName.split(' ')[0]}!',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Token #${_token!.tokenNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if (_token!.applicationId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _token!.applicationId!,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DOB: ${_token!.childDob ?? ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _getStatusColor(_token!.status),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _token!.status.toUpperCase().replaceAll('_', ' '),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              onPressed: _showQrCode,
              icon: const Icon(
                Icons.qr_code_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    bool showBadge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: const Color(0xFF00796B)),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor ?? Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
            if (showBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCardWide({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: const Color(0xFF00796B)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }
}
