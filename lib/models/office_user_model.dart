import 'package:cloud_firestore/cloud_firestore.dart';

class OfficeUserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // "admin" | "volunteer"
  final DateTime? createdAt;

  OfficeUserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory OfficeUserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return OfficeUserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'volunteer',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
