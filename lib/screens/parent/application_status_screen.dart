import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../services/rte_service.dart';
import '../../models/token_model.dart';
import '../../models.dart';
import '../../core/utils.dart';
import '../../widgets/no_internet_banner.dart';

// SSL Override Class
class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class ApplicationStatusScreen extends StatefulWidget {
  final String tokenId;

  const ApplicationStatusScreen({
    super.key,
    required this.tokenId,
  });

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  TokenModel? _token;
  bool _isLoading = true;
  String? _error;

  // Real RTE Data Variables with Timeouts
  RteApplicationData? _rteData;
  bool _rteLoading = false;
  String? _rteError;

  // Show the application ID notice once when an ID is first received.
  bool _showAppIdCard = false;

  @override
  void initState() {
    super.initState();
    HttpOverrides.global = _AppHttpOverrides();

    _loadData().then((_) async {
      if (_showAppIdCard && _token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_id_seen_${_token!.id}', true);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _rteError = null;
    });

    try {
      final token = await FirestoreService().getTokenById(widget.tokenId);
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        final seenKey = 'app_id_seen_${token.id}';
        final alreadySeen = prefs.getBool(seenKey) ?? false;

        if (mounted) {
          setState(() {
            _token = token;
            _showAppIdCard = !alreadySeen && token.applicationId != null && token.applicationId!.isNotEmpty;
            _isLoading = false;
          });

          if (token.applicationId != null && token.applicationId!.isNotEmpty) {
            await _fetchRteData();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Token not found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load data. Please retry.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRteData() async {
    if (!mounted || _token?.applicationId == null || _token?.childDob == null) return;

    setState(() {
      _rteLoading = true;
      _rteError = null;
    });

    try {
      final result = await RteService().fetchStatusWithChildName(
        _token!.applicationId!.trim(),
        _token!.childDob!.trim(),
      );

      // Update Firestore with real government status
      await FirestoreService().updateGovStatus(
        widget.tokenId,
        govStatus: result.classifiedStatus,
        message: result.statusMessage,
        govChildName: result.childName,
      );

      // For the full rich display we still need the parsed HTML data — reuse
      // the legacy path here (parent screen shows detailed sections).
      final data = await RteService().fetchApplicationStatus(
        _token!.applicationId!.trim(),
        _token!.childDob!.trim(),
      );

      if (mounted) {
        setState(() {
          _rteData = data;
          _rteLoading = false;
        });
      }
    } catch (e) {
      debugPrint('RTE FETCH ERROR: $e');
      if (mounted) {
        setState(() {
          _rteError = 'Unable to connect to government portal. Please check your internet connection and try again.';
          _rteLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00796B);
    const ink = Color(0xFF173B36);
    const pageBackground = Color(0xFFF4F7F6);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
        titleSpacing: 4,
        title: Text(
          'Application Tracking',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: ink,
          ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE7EEEC)),
        ),
      ),
      body: Column(
        children: [
          const NoInternetBanner(),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 2.5,
              ),
            )
                : _error != null || _token == null
                ? _buildLoadErrorState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: primary,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  if (_showAppIdCard) ...[
                    _buildPriorityIdCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailsCard(),
                  const SizedBox(height: 16),
                  _buildRteStatusSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState() {
    const primary = Color(0xFF00796B);
    final message = _error ?? 'Application details are unavailable.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xFF9EAAA7),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF314C47),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: Color(0xFFB9D8D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityIdCard() {
    final applicationId = _token?.applicationId;
    if (applicationId == null || applicationId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF00796B),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application ID received',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF173B36),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            applicationId,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: const Color(0xFF00695C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep this ID for future tracking.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF54736D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final token = _token;
    if (token == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Details',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF173B36),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Token Number', '#${token.tokenNumber}'),
          if (token.applicationId != null && token.applicationId!.isNotEmpty)
            _buildInfoRow('Application ID', token.applicationId!),
          _buildInfoRow('Parent Name', token.parentName),
          _buildInfoRow('Parent Mobile', token.parentMobile),
          _buildInfoRow(
            'Submitted On',
            DateFormat('dd MMM yyyy').format(
              token.createdAt ?? DateTime.now(),
            ),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: const Color(0xFF74827F),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF263F3A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteStatusSection() {
    if (_token?.applicationId == null || _token!.applicationId!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF7C908B),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Government portal status will appear here once an application ID is available.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF657772),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_rteLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE8)),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFF00796B),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Syncing with government portal',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF314C47),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Fetching the latest application updates…',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF879591),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_rteError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF9A6A30),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Portal sync unavailable',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF314C47),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _rteError!,
              style: GoogleFonts.outfit(
                color: const Color(0xFF74827F),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _rteLoading ? null : _fetchRteData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00796B),
                side: const BorderSide(color: Color(0xFFB9D8D2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_rteData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAE8)),
        ),
        child: Text(
          'Date of birth is required to fetch the government portal status.',
          style: GoogleFonts.outfit(
            fontSize: 13,
            height: 1.45,
            color: const Color(0xFF74827F),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRteStatusCard(context),
        const SizedBox(height: 16),
        ..._rteData!.sections.entries.map(
              (section) => _buildRteInfoSection(
            context,
            section.key,
            section.value,
          ),
        ),
        if (_rteData!.schools.isNotEmpty)
          _buildRteGridSection(
            context,
            'Selected Schools',
            _rteData!.schools,
            Icons.school_outlined,
          ),
        if (_rteData!.documents.isNotEmpty)
          _buildRteDocumentsSection(context, _rteData!.documents),
      ],
    );
  }

  Widget _buildRteStatusCard(BuildContext context) {
    final msg = _rteData!.statusMessage.toLowerCase();
    final bool isApproved = msg.contains('મંજૂ') ||
        msg.contains('approved') ||
        msg.contains('accept') ||
        msg.contains('ફાળવ');
    final bool isRejected = msg.contains('નામંજૂ') ||
        msg.contains('reject') ||
        msg.contains('refused');

    final Color statusColor = isApproved
        ? const Color(0xFF2E7D32)
        : isRejected
        ? const Color(0xFFC62828)
        : const Color(0xFF9A6A30);
    final IconData statusIcon = isApproved
        ? Icons.check_circle_rounded
        : isRejected
        ? Icons.cancel_rounded
        : Icons.access_time_filled_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Government Status',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF173B36),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isApproved ? 'APPROVED' : isRejected ? 'REJECTED' : 'UPDATE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _rteData!.statusMessage,
            textAlign: TextAlign.start,
            style: GoogleFonts.notoSansGujarati(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF314C47),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteInfoSection(
      BuildContext context,
      String title,
      Map<String, String> fields,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
            child: Text(
              title,
              style: GoogleFonts.notoSansGujarati(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF00796B),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF1F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: fields.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          entry.key,
                          style: GoogleFonts.notoSansGujarati(
                            fontSize: 12,
                            color: const Color(0xFF74827F),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.end,
                          softWrap: true,
                          style: GoogleFonts.notoSansGujarati(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF263F3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteGridSection(
      BuildContext context,
      String title,
      List<List<String>> rows,
      IconData icon,
      ) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF00796B), size: 21),
                const SizedBox(width: 12),
                Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF173B36))),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: rows[0]
                  .map(
                    (heading) => DataColumn(
                  label: Text(
                    heading,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
                  .toList(),
              rows: rows.skip(1).map((row) {
                return DataRow(
                  cells: row
                      .map(
                        (cell) => DataCell(
                      Text(
                        cell,
                        style: GoogleFonts.notoSansGujarati(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteDocumentsSection(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox();
    final dataRows = rows.skip(1).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.file_present_rounded,
                  color: Color(0xFF00796B),
                  size: 21,
                ),
                const SizedBox(width: 12),
                Text(
                  'Uploaded Documents',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF173B36),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...dataRows.map((row) {
            final category = row.length > 1 ? row[1] : '';
            final size     = row.length > 2 ? row[2] : '';
            final url      = row.length > 3 ? row[3] : '';

            IconData docIcon = Icons.insert_drive_file_rounded;
            if (category.toLowerCase().contains('photo')) docIcon = Icons.photo_rounded;
            if (category.toLowerCase().contains('birth')) docIcon = Icons.cake_rounded;
            if (category.toLowerCase().contains('income')) docIcon = Icons.receipt_long_rounded;
            if (category.toLowerCase().contains('address')) docIcon = Icons.home_rounded;
            if (category.toLowerCase().contains('pan')) docIcon = Icons.credit_card_rounded;
            if (category.toLowerCase().contains('sign')) docIcon = Icons.draw_rounded;
            if (category.toLowerCase().contains('declaration')) docIcon = Icons.verified_rounded;

            return Container(
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: Color(0xFFEDF1F0))),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF00796B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(docIcon, color: const Color(0xFF00796B), size: 22),
                ),
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                subtitle: Text(size, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                trailing: url.isNotEmpty
                    ? ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}
