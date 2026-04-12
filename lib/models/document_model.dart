import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String? id;
  final String docType;
  final String fileName;
  final String storagePath;
  final DateTime? uploadedAt;

  DocumentModel({
    this.id,
    required this.docType,
    required this.fileName,
    required this.storagePath,
    this.uploadedAt,
  });

  factory DocumentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return DocumentModel(
      id: id,
      docType: data['docType'] ?? '',
      fileName: data['fileName'] ?? '',
      storagePath: data['storagePath'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'docType': docType,
      'fileName': fileName,
      'storagePath': storagePath,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
