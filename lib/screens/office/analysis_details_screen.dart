import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/token_model.dart';

class AnalysisDetailsScreen extends StatelessWidget {
  final String category;
  final List<TokenModel> tokens;

  const AnalysisDetailsScreen({
    super.key,
    required this.category,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B2B),
      appBar: AppBar(
        title: Text(
          '$category Applications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2B2B), Color(0xFF004D40)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3535),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: tokens.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingTextStyle: GoogleFonts.outfit(
                              color: const Color(0xFF81D4FA),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            dataTextStyle: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('TOKEN')),
                              DataColumn(label: Text('PARENT NAME')),
                              DataColumn(label: Text('APPLICATION ID')),
                              DataColumn(label: Text('DOB')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('SYNC DATE')),
                            ],
                            rows: tokens.map((token) {
                              final bool hasHistory = token.applicationHistory.isNotEmpty;
                              final bool isNoStatus = token.govStatusMessage?.contains('No status information found') ?? false;
                              
                              final Color statusColor = isNoStatus 
                                ? Colors.white38
                                : token.govStatus == 'APPROVED' 
                                  ? Colors.greenAccent 
                                  : token.govStatus == 'CANCELLED' 
                                    ? Colors.redAccent 
                                    : token.govStatus == 'CORRECTION' 
                                      ? Colors.orangeAccent 
                                      : token.govStatus == 'ERROR'
                                        ? Colors.redAccent
                                        : Colors.white24;

                              return DataRow(
                                onSelectChanged: (_) {
                                  context.push('/office/token-detail', extra: token);
                                },
                                cells: [
                                  DataCell(Text('#${token.tokenNumber}')),
                                  DataCell(Text(token.parentName)),
                                  DataCell(Text(token.applicationId ?? 'N/A')),
                                  DataCell(Text(token.childDob ?? 'N/A')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (hasHistory ? Colors.blueAccent : statusColor).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: (hasHistory ? Colors.blueAccent : statusColor).withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (hasHistory)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                'RE-SUBMITTED (Attempt #${token.applicationHistory.length + 1})',
                                                style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                              ),
                                            ),
                                          Text(
                                            token.govStatusMessage ?? (token.govStatus ?? 'PENDING'),
                                            style: GoogleFonts.notoSansGujarati(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: hasHistory ? Colors.blueAccent : statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      token.lastSyncAt != null
                                          ? DateFormat('dd/MM HH:mm').format(token.lastSyncAt!)
                                          : 'Never',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_late_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'No records found for this category',
            style: GoogleFonts.outfit(color: Colors.white24),
          ),
        ],
      ),
    );
  }
}
