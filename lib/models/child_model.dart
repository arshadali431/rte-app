import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String? id;
  final String childName;
  final String dob;
  final String gender;
  final String aadhaarNumber;
  final List<String> schoolPreferences;
  final DateTime? createdAt;

  ChildModel({
    this.id,
    required this.childName,
    required this.dob,
    required this.gender,
    required this.aadhaarNumber,
    required this.schoolPreferences,
    this.createdAt,
  });

  factory ChildModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ChildModel(
      id: id,
      childName: data['childName'] ?? '',
      dob: data['dob'] ?? '',
      gender: data['gender'] ?? '',
      aadhaarNumber: data['aadhaarNumber'] ?? '',
      schoolPreferences: List<String>.from(data['schoolPreferences'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'childName': childName,
      'dob': dob,
      'gender': gender,
      'aadhaarNumber': aadhaarNumber,
      'schoolPreferences': schoolPreferences,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
