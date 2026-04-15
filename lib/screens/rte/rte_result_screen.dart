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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                'Application Status',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatusCard(context),
                  const SizedBox(height: 16),
                  ...data.sections.entries.map((section) {
                    return _buildInfoSection(context, section.key, section.value);
                  }),
                  if (data.schools.isNotEmpty)
                    _buildGridSection(context, "Selected Schools", data.schools, Icons.school_rounded),
                  if (data.documents.isNotEmpty)
                    _buildDocumentsSection(context, data.documents),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final msg = data.statusMessage.toLowerCase();
    final bool isApproved = msg.contains('મંજૂ') || msg.contains('approved') || msg.contains('accept') || msg.contains('ફાળવ');
    final bool isRejected = msg.contains('નામંજૂ') || msg.contains('reject') || msg.contains('refused');

    final Color statusColor = isApproved
        ? const Color(0xFF2E7D32)
        : isRejected
            ? const Color(0xFFC62828)
            : const Color(0xFFE65100);

    final IconData statusIcon = isApproved
        ? Icons.check_circle_rounded
        : isRejected
            ? Icons.cancel_rounded
            : Icons.access_time_filled_rounded;

    return Card(
      elevation: 4,
      shadowColor: statusColor.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: statusColor.withOpacity(0.35), width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.08),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 16),
                Text(
                  'અરજીની સ્થિતિ',
                  style: GoogleFonts.notoSansGujarati(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              data.statusMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansGujarati(
                fontSize: 17,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, Map<String, String> fields) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: GoogleFonts.notoSansGujarati(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary),
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
                        child: Text(
                          e.key,
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          e.value,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.notoSansGujarati(fontSize: 14, fontWeight: FontWeight.bold),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
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

  Widget _buildDocumentsSection(BuildContext context, List<List<String>> rows) {
    if (rows.isEmpty) return const SizedBox();
    final colorScheme = Theme.of(context).colorScheme;
    final dataRows = rows.skip(1).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.file_present_rounded, color: colorScheme.primary, size: 22),
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
                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(docIcon, color: colorScheme.primary, size: 22),
                ),
                title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(size, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                trailing: url.isNotEmpty
                    ? ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
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
