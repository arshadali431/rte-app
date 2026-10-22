import 'package:cloud_firestore/cloud_firestore.dart';

class TokenModel {
  final String id;
  final int tokenNumber;
  final String parentName;
  final String parentMobile;
  final DateTime? createdAt;
  final String createdBy;
  final String status; // "pending" | "in_progress" | "completed"
  final String? applicationId;
  final String? childDob;
  final List<Map<String, dynamic>> applicationHistory;
  final String? govStatus; // "APPROVED", "CANCELLED", "PENDING", "ERROR"
  final String? govStatusMessage; // Full Gujarati text/Reason
  final String? govChildName; // Child's name from govt portal (Gujarati script)
  final String? govParentMobile; // Primary mobile number from govt portal
  final DateTime? lastSyncAt;

  /// True while the parent's self-service deletion request is pending.
  /// Office lists/searches/counters hide these tokens and the office token
  /// detail shows only a neutral "Deletion requested" state.
  final bool deletionPending;

  TokenModel({
    required this.id,
    required this.tokenNumber,
    required this.parentName,
    required this.parentMobile,
    this.createdAt,
    required this.createdBy,
    required this.status,
    this.applicationId,
    this.childDob,
    this.applicationHistory = const [],
    this.govStatus,
    this.govStatusMessage,
    this.govChildName,
    this.govParentMobile,
    this.lastSyncAt,
    this.deletionPending = false,
  });

  factory TokenModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TokenModel(
      id: id,
      tokenNumber: (data['tokenNumber'] is num && (data['tokenNumber'] as num).isFinite)
          ? (data['tokenNumber'] as num).toInt()
          : 0,
      parentName: data['parentName'] ?? '',
      parentMobile: data['parentMobile'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      status: data['status'] ?? 'pending',
      applicationId: data['applicationId'],
      childDob: data['childDob'],
      applicationHistory: List<Map<String, dynamic>>.from(
        data['applicationHistory'] ?? [],
      ),
      govStatus: data['govStatus'],
      govStatusMessage: data['govStatusMessage'],
      govChildName: data['govChildName'],
      govParentMobile: data['govParentMobile'],
      lastSyncAt: (data['lastSyncAt'] as Timestamp?)?.toDate(),
      deletionPending: data['deletionPending'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tokenNumber': tokenNumber,
      'parentName': parentName,
      'parentMobile': parentMobile,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'status': status,
      'applicationId': applicationId,
      'childDob': childDob,
      'applicationHistory': applicationHistory,
      'govStatus': govStatus,
      'govStatusMessage': govStatusMessage,
      'govChildName': govChildName,
      'govParentMobile': govParentMobile,
      'lastSyncAt': lastSyncAt != null ? Timestamp.fromDate(lastSyncAt!) : null,
      'deletionPending': deletionPending,
    };
  }
}
