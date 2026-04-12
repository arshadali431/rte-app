import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../models/token_model.dart';
import '../../models.dart';
import '../../core/utils.dart';

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

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen>
    with SingleTickerProviderStateMixin {
  TokenModel? _token;
  bool _isLoading = true;
  String? _error;

  // Real RTE Data Variables with Timeouts
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
  ));
  
  RteApplicationData? _rteData;
  bool _rteLoading = false;
  String? _rteError;

  // New Property for Pulsing App ID Card
  bool _showAppIdCard = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    HttpOverrides.global = _AppHttpOverrides();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData().then((_) async {
      if (_showAppIdCard && _token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_id_seen_${_token!.id}', true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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
    if (_token?.applicationId == null || _token?.childDob == null) return;

    setState(() {
      _rteLoading = true;
      _rteError = null;
    });

    try {
      debugPrint("--- RTE FETCH: STEP 1 (GET TOKEN) ---");
      const String userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

      final getResponse = await _dio.get(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        options: Options(headers: {"User-Agent": userAgent}),
      );

      List<String> rawCookies = getResponse.headers["set-cookie"] ?? [];
      String cookieString = rawCookies.map((e) => e.split(";")[0]).join("; ");

      final tokenMatch = RegExp(r'name="__RequestVerificationToken".*?value="([^"]+)"', dotAll: true)
          .firstMatch(getResponse.data.toString());

      String? verifToken = tokenMatch?.group(1);

      if (verifToken == null) {
        throw Exception("Verification token missing");
      }

      debugPrint("--- RTE FETCH: STEP 2 (POST STATUS) ---");
      final postResponse = await _dio.post(
        "https://rte.orpgujarat.com/ApplicationFormStatus",
        data: {
          "__RequestVerificationToken": verifToken,
          "ApplicationNumber": _token!.applicationId!.trim(),
          "DateOfBirth": _token!.childDob!.trim(),
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Cookie": cookieString,
            "Origin": "https://rte.orpgujarat.com",
            "Referer": "https://rte.orpgujarat.com/ApplicationFormStatus",
            "User-Agent": userAgent,
          },
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = _parseResponseNew(postResponse.data.toString());
      if (mounted) {
        setState(() {
          _rteData = data;
          _rteLoading = false;
        });
      }
    } catch (e) {
      debugPrint("RTE FETCH ERROR: $e");
      if (mounted) {
        setState(() {
          _rteError = 'Unable to connect to government portal. Please check your internet connection and try again.';
          _rteLoading = false;
        });
      }
    }
  }

  RteApplicationData _parseResponseNew(String html) {
    final doc = parser.parse(html);
    String appNum = _token?.applicationId ?? '';
    final cardHeader = doc.querySelector('.card-header');
    if (cardHeader != null) {
      final match = RegExp(r'(?:for\s+)([A-Z0-9/\-]+)').firstMatch(cardHeader.text);
      if (match != null) appNum = match.group(1)!.trim();
    }

    String statusMsg = '';
    final allFieldsets = doc.querySelectorAll('fieldset');
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim().contains('અરજીની સ્થિતિ')) {
        final p = fs.querySelector('p');
        statusMsg = p != null ? p.text.trim() : fs.text.replaceAll(legend.text, '').trim();
        break;
      }
    }
    if (statusMsg.isEmpty) statusMsg = 'No status information found.';

    Map<String, Map<String, String>> sections = {};
    const tableFieldsets = {'Selected Schools', 'Uploaded Documents'};
    const skipLegendContains = 'અરજીની સ્થિતિ';

    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend == null) continue;
      final sectionTitle = legend.text.trim();
      if (sectionTitle.contains(skipLegendContains)) continue;
      if (tableFieldsets.contains(sectionTitle)) continue;

      Map<String, String> sectionData = {};
      for (final dl in fs.querySelectorAll('dl.row')) {
        final children = dl.children.where((el) => el.localName == 'dt' || el.localName == 'dd').toList();
        for (var i = 0; i < children.length - 1; i++) {
          if (children[i].localName == 'dt' && children[i + 1].localName == 'dd') {
            final key = children[i].text.trim().replaceAll(':', '').replaceAll(RegExp(r'\s+'), ' ').trim();
            final value = children[i + 1].text.trim().replaceAll(RegExp(r'\s+'), ' ').trim();
            if (key.isNotEmpty) sectionData[key] = value;
          }
        }
      }
      if (sectionData.isNotEmpty) sections[sectionTitle] = sectionData;
    }

    List<List<String>> schools = [];
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim() == 'Selected Schools') {
        final table = fs.querySelector('table');
        if (table != null) {
          for (final row in table.querySelectorAll('tr')) {
            final rowData = row.querySelectorAll('th, td').map((c) => c.text.trim().replaceAll(RegExp(r'\s+'), ' ')).toList();
            if (rowData.any((c) => c.isNotEmpty)) schools.add(rowData);
          }
        }
        break;
      }
    }

    List<List<String>> documents = [];
    for (final fs in allFieldsets) {
      final legend = fs.querySelector('legend');
      if (legend != null && legend.text.trim() == 'Uploaded Documents') {
        final table = fs.querySelector('table');
        if (table != null) {
          for (final row in table.querySelectorAll('tr')) {
            final rowData = row.querySelectorAll('th, td').map((c) {
              final anchor = c.querySelector('a');
              if (anchor != null) {
                final href = anchor.attributes['href'] ?? '';
                if (href.isEmpty) return '';
                return href.startsWith('http') ? href : 'https://rte.orpgujarat.com$href';
              }
              return c.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            }).toList();
            if (rowData.any((c) => c.isNotEmpty)) documents.add(rowData);
          }
        }
        break;
      }
    }

    return RteApplicationData(
      applicationNumber: appNum,
      statusMessage: statusMsg,
      sections: sections,
      schools: schools,
      documents: documents,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Application Tracking', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF00796B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_showAppIdCard) ...[
                      _buildPriorityIdCard(),
                      const SizedBox(height: 24),
                    ],
                    _buildDetailsCard(),
                    const SizedBox(height: 24),
                    _buildRteStatusSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPriorityIdCard() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00796B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00796B).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            Text(
              'APPLICATION ID RECEIVED',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _token!.applicationId!,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use this ID for future tracking',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Details',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Token Number', '#${_token!.tokenNumber}'),
          if (_token!.applicationId != null)
            _buildInfoRow('Application ID', _token!.applicationId!),
          _buildInfoRow('Parent Name', _token!.parentName),
          _buildInfoRow('Parent Mobile', _token!.parentMobile),
          _buildInfoRow('Submitted On', DateFormat('dd MMM yyyy').format(_token!.createdAt ?? DateTime.now())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label — fixed width
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.grey[500], 
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Value — takes remaining space, wraps if needed
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600, 
                fontSize: 13,
                color: Colors.blueGrey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteStatusSection() {
    if (_token?.applicationId == null) return const SizedBox();
    
    if (_rteLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF00796B)),
            const SizedBox(height: 20),
            Text('Syncing with Government Portal...',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.blueGrey[700], fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Fetching latest application updates',
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );
    }
    
    if (_rteError != null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.grey[300], size: 64),
            const SizedBox(height: 16),
            Text('Portal Sync Unavailable',
              style: GoogleFonts.outfit(color: Colors.blueGrey[900], fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_rteError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchRteData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_rteData == null) return const SizedBox();
    
    return Column(
      children: [
        _buildRteStatusCard(context),
        const SizedBox(height: 24),
        ..._rteData!.sections.entries.map((section) =>
          _buildRteInfoSection(context, section.key, section.value)),
        if (_rteData!.schools.isNotEmpty)
          _buildRteGridSection(context, "Selected Schools", 
            _rteData!.schools, Icons.school_rounded),
        if (_rteData!.documents.isNotEmpty)
          _buildRteDocumentsSection(context, _rteData!.documents),
      ],
    );
  }

  Widget _buildRteStatusCard(BuildContext context) {
    final msg = _rteData!.statusMessage.toLowerCase();
    final bool isApproved = msg.contains('મંજૂ') || msg.contains('approved') || msg.contains('accept') || msg.contains('ફાળવ');
    final bool isRejected = msg.contains('નામંજૂ') || msg.contains('reject') || msg.contains('refused');

    final Color statusColor = isApproved ? const Color(0xFF2E7D32) : isRejected ? const Color(0xFFC62828) : const Color(0xFFE65100);
    final IconData statusIcon = isApproved ? Icons.check_circle_rounded : isRejected ? Icons.cancel_rounded : Icons.access_time_filled_rounded;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.15), width: 2),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              const SizedBox(width: 12),
              Text('GOVERNMENT STATUS', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _rteData!.statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansGujarati(
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRteInfoSection(BuildContext context, String title, Map<String, String> fields) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: GoogleFonts.notoSansGujarati(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF00796B)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: fields.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(e.key, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(e.value, textAlign: TextAlign.end, style: GoogleFonts.notoSansGujarati(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
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

  Widget _buildRteGridSection(BuildContext context, String title, List<List<String>> rows, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF00796B), size: 22),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: rows[0].map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows.skip(1).map((row) {
                return DataRow(
                  cells: row.map((c) => DataCell(Text(c, style: GoogleFonts.notoSansGujarati(fontSize: 11)))).toList(),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded, color: Color(0xFF00796B), size: 22),
                const SizedBox(width: 12),
                const Text('Uploaded Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF00796B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(docIcon, color: const Color(0xFF00796B), size: 22),
                ),
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(size, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
