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
import '../../widgets/privacy_policy_link.dart';

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
  bool _sessionMissing = false;

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
      _sessionMissing = false;
    });

    try {
      final extra = GoRouterState.of(context).extra;
      String? tokenId = extra is String ? extra : null;

      // Also tolerate a map-shaped route extra in case another entry point uses it.
      if ((tokenId == null || tokenId.isEmpty) && extra is Map) {
        final extraTokenId = extra['tokenId'];
        if (extraTokenId is String) tokenId = extraTokenId;
      }

      if (tokenId == null || tokenId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        tokenId = prefs.getString('token_id');
      }

      if (tokenId == null || tokenId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _token = null;
            _sessionMissing = true;
            _error = 'No saved application was found. Scan your token QR code to continue.';
          });
        }
        return;
      }

      debugPrint('Parent dashboard: loading token $tokenId');
      final token = await FirestoreService()
          .getTokenById(tokenId)
          .timeout(const Duration(seconds: 15));
      debugPrint('Parent dashboard: token load completed (${token != null})');
      if (!mounted) return;

      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token_id');
        await prefs.remove('token_number');

        if (mounted) {
          setState(() {
            _isLoading = false;
            _token = null;
            _sessionMissing = true;
            _error = 'Your saved application could not be found. Scan your token QR code again.';
          });
        }
        return;
      }

      setState(() {
        _token = token;
        _isLoading = false;
        _sessionMissing = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Parent dashboard load failed: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load dashboard data. Check your connection and try again.';
          _sessionMissing = false;
        });
      }
    }
  }

  void _showProfile() {
    if (_token == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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
                  color: Colors.black,
                ),
              ),
              Text(
                _token!.parentMobile.isEmpty ? 'N/A' : _token!.parentMobile,
                style: GoogleFonts.outfit(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                'Token #${_token!.tokenNumber}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00796B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              PrivacyPolicyLink(language: 'en'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Show confirmation dialog before logout
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('Log Out', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                        content: Text('Are you sure you want to log out from your session?', style: GoogleFonts.outfit(color: Colors.black87)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Log Out', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('token_id');
                      await prefs.remove('token_number');
                      if (context.mounted) {
                        Navigator.pop(context); // Close profile sheet
                        context.go('/role');
                      }
                    }
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
              const SizedBox(height: 8),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  if (mounted) context.push('/parent/delete-data');
                },
                icon: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red[400],
                  size: 19,
                ),
                label: Text(
                  'Delete my data',
                  style: GoogleFonts.outfit(
                    color: Colors.red[400],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
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
    const primary = Color(0xFF087C6B);
    const pageBackground = Color(0xFFF5F8F7);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Parent dashboard is the root of this navigation flow.
      },
      child: Scaffold(
        backgroundColor: pageBackground,
        appBar: AppBar(
          title: Text(
            'My Application',
            style: GoogleFonts.outfit(
              color: const Color(0xFF173B35),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF173B35),
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: 'My profile',
              onPressed: _showProfile,
              icon: const Icon(Icons.person_outline_rounded),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFE8EFED)),
          ),
        ),
        body: Stack(
          children: [
            // The main content fills the body independently of the network banner.
            Positioned.fill(child: _buildDashboardBody()),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NoInternetBanner(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    const primary = Color(0xFF087C6B);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 30,
                  color: Color(0xFFB83A46),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: const Color(0xFF425650),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _sessionMissing
                    ? () => context.go('/role')
                    : _loadToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _sessionMissing ? 'Return to role selection' : 'Try again',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_token == null) return _buildMissingTokenState();

    return RefreshIndicator(
      onRefresh: _loadToken,
      color: primary,
      backgroundColor: Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 28),
          Text(
            'QUICK ACTIONS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF637771),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // ListView gives this Row unbounded vertical space.
          // Do not stretch children vertically; each menu card has its own fixed height.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildMenuCard(
                  icon: Icons.child_care_rounded,
                  title: 'Child Profile',
                  subtitle: 'View child details',
                  onTap: () => context.push(
                    '/parent/child-profile',
                    extra: _token!.id,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMenuCard(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Application Status',
                  subtitle: _token!.applicationId != null
                      ? 'Application ID received'
                      : _token!.status.toUpperCase().replaceAll('_', ' '),
                  subtitleColor: _token!.applicationId != null
                      ? const Color(0xFF23845D)
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
            icon: Icons.upload_file_outlined,
            title: 'Upload Documents',
            subtitle: 'Add or manage required documents',
            onTap: () => context.push(
              '/parent/documents',
              extra: _token!.id,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingTokenState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                size: 30,
                color: Color(0xFF087C6B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Application not available',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF173B35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Return to role selection and scan your token QR code to open your dashboard.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                height: 1.45,
                color: const Color(0xFF637771),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/role'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087C6B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Return to role selection',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    if (_token == null) return const SizedBox.shrink();

    const deepTeal = Color(0xFF0B5549);
    const textSecondary = Color(0xFFD8EEE8);
    final firstName = _token!.parentName.trim().split(RegExp(r'\s+')).first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087C6B), deepTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$firstName!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Token #${_token!.tokenNumber}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showQrCode,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_token!.applicationId != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.18)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APPLICATION ID',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _token!.applicationId!,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (_token!.childDob?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'DOB: ${_token!.childDob}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _getStatusColor(_token!.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _token!.status.toUpperCase().replaceAll('_', ' '),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
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
    const primary = Color(0xFF087C6B);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 148,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EBE8)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5F2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 24, color: primary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF203D37),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor ?? const Color(0xFF75847F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D9B69),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EBE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 25,
                  color: const Color(0xFF087C6B),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF203D37),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF71817B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8A9A94),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFB7791F);
      case 'in_progress':
        return const Color(0xFF2876B8);
      case 'completed':
        return const Color(0xFF2D9B69);
      default:
        return const Color(0xFF7B8984);
    }
  }
}
