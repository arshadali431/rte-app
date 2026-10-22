import 'package:cloud_firestore/cloud_firestore.dart';

/// A parent's request to have their token data permanently deleted.
///
/// Firestore path: `deletion_requests/{tokenId}`. The document deliberately
/// carries no personal details — only lifecycle metadata. See
/// `functions/deleteScheduled.js` for the hard-delete worker.
class DeletionRequest {
  final String tokenId;
  final DateTime? requestedAt;
  final DateTime? executeAfter;
  final String status; // pending | cancelled | executed
  final DateTime? cancelledAt;
  final DateTime? executedAt;

  const DeletionRequest({
    required this.tokenId,
    this.requestedAt,
    this.executeAfter,
    required this.status,
    this.cancelledAt,
    this.executedAt,
  });

  factory DeletionRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return DeletionRequest(
      tokenId: id,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      executeAfter: (data['executeAfter'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'pending',
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      executedAt: (data['executedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending => status == 'pending';

  bool isPendingAt(DateTime now) {
    if (!isPending) return false;
    final execute = executeAfter;
    return execute == null || execute.isAfter(now);
  }
}
