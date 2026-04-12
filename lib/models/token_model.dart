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
  });

  factory TokenModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TokenModel(
      id: id,
      tokenNumber: data['tokenNumber'] ?? 0,
      parentName: data['parentName'] ?? '',
      parentMobile: data['parentMobile'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      status: data['status'] ?? 'pending',
      applicationId: data['applicationId'],
      childDob: data['childDob'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tokenNumber': tokenNumber,
      'parentName': parentName,
      'parentMobile': parentMobile,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'status': status,
      'applicationId': applicationId,
      'childDob': childDob,
    };
  }
}
