import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';

class RteResultScreen extends StatelessWidget {
  final RteApplicationData data;

  const RteResultScreen({super.key, required this.data});

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
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00796B).withOpacity(0.12),
              ),
            ),
          ),

          // 3. Content
          Column(
            children: [
              // Custom Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 56, 16, 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
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
                      'Application Status',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                  child: Column(
                    children: [
                      _buildStatusCard(context),
                      const SizedBox(height: 32),
                      ...data.sections.entries.map((section) {
                        return _buildInfoSection(context, section.key, section.value);
                      }),
                      if (data.schools.isNotEmpty)
                        _buildGridSection(context, "Selected Schools", data.schools, Icons.school_rounded),
                      if (data.documents.isNotEmpty)
                        _buildDocumentsSection(context, data.documents),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final msg = data.statusMessage.toLowerCase();
    final bool isApproved = msg.contains('મંજૂ') || msg.contains('approved') || msg.contains('accept') || msg.contains('ફાળવ');
    final bool isRejected = msg.contains('નામંજૂ') || msg.contains('reject') || msg.contains('refused');

    final Color statusColor = isApproved
        ? const Color(0xFF69F0AE)
        : isRejected
            ? const Color(0xFFFF5252)
            : const Color(0xFFFFAB40);

    final IconData statusIcon = isApproved
        ? Icons.verified_rounded
        : isRejected
            ? Icons.error_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'અરજીની સ્થિતિ',
            style: GoogleFonts.notoSansGujarati(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: statusColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansGujarati(
              fontSize: 17,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, Map<String, String> fields) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Text(
              title,
              style: GoogleFonts.notoSansGujarati(
                fontSize: 18, 
                fontWeight: FontWeight.w900, 
                color: const Color(0xFF4DB6AC),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: fields.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          e.key,
                          style: GoogleFonts.notoSansGujarati(
                            fontSize: 13, 
                            color: Colors.white.withOpacity(0.4), 
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Text(
                          e.value,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.notoSansGujarati(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildGridSection(BuildContext context, String title, List<List<String>> rows, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF4DB6AC), size: 24),
                const SizedBox(width: 12),
                Text(
                  title, 
                  style: GoogleFonts.outfit(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: DataTable(
              showCheckboxColumn: false,
              headingTextStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold),
              columns: rows[0].map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows.skip(1).map((row) {
                return DataRow(
                  cells: row.map((c) => DataCell(Text(c, style: GoogleFonts.notoSansGujarati(fontSize: 11, color: Colors.white70)))).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox();
    final dataRows = rows.skip(1).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded, color: Color(0xFF4DB6AC), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Uploaded Documents', 
                  style: GoogleFonts.outfit(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
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
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DB6AC).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Icon(docIcon, color: const Color(0xFF4DB6AC), size: 22),
                ),
                title: Text(
                  category, 
                  style: GoogleFonts.notoSansGujarati(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: Colors.white,
                  )
                ),
                subtitle: Text(
                  size, 
                  style: GoogleFonts.outfit(
                    fontSize: 12, 
                    color: Colors.white.withOpacity(0.4),
                  )
                ),
                trailing: url.isNotEmpty
                    ? InkWell(
                        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'View',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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
