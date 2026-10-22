import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';

/// Service for reading and writing consent records.
///
/// Collection: consent_records
/// Document ID: {subjectId}_{consentVersion}
///
/// Write policy: CREATE-ONLY — never update, never delete.
class ConsentService {
  static const String kCollection = 'consent_records';

  /// Current consent version deployed in this build.
  static const int kConsentVersion = 1;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Singleton
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  // ---------------------------------------------------------------------------
  // SHA-256 helper
  // ---------------------------------------------------------------------------

  /// Returns a lowercase hex SHA-256 digest of [text] using package:crypto.
  static String sha256Hex(String text) {
    return crypto.sha256.convert(utf8.encode(text)).toString();
  }

  // ---------------------------------------------------------------------------
  // Firestore helpers
  // ---------------------------------------------------------------------------

  /// Checks whether a valid consent record exists for [subjectId] at
  /// [kConsentVersion] or higher. Returns true if consent can be skipped.
  Future<bool> hasValidConsent(String subjectId) async {
    try {
      final doc = await _db
          .collection(kCollection)
          .doc('${subjectId}_$kConsentVersion')
          .get();
      if (!doc.exists) return false;
      final storedVersion = doc.data()?['consent_version'];
      if (storedVersion is int && storedVersion >= kConsentVersion) return true;
      return false;
    } catch (e) {
      debugPrint('[ConsentService] hasValidConsent error: $e');
      return false;
    }
  }

  /// Writes a CREATE-ONLY consent record to Firestore.
  ///
  /// Throws if the document already exists (Firestore precondition enforces this).
  Future<void> recordConsent({
    required String subjectId,
    required String consentText,
    required String language,
    required String appVersion,
    required String platform,
    required int holdDurationMs,
  }) async {
    final docId = '${subjectId}_$kConsentVersion';
    final docRef = _db.collection(kCollection).doc(docId);

    final textHash = sha256Hex(consentText);

    // CREATE-ONLY: will throw if document already exists
    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (snap.exists) {
        // Already recorded — idempotent, treat as success
        debugPrint('[ConsentService] Consent already recorded for $docId');
        return;
      }
      txn.set(docRef, {
        'subjectId': subjectId,
        'consent_version': kConsentVersion,
        'sha256': textHash,
        'text_sha256': textHash,
        'language': language,
        'timestamp': FieldValue.serverTimestamp(),
        'app_version': appVersion,
        'platform': platform,
        'scrolledToEnd': true,
        'holdDurationMs': holdDurationMs,
      });
    });

    debugPrint('[ConsentService] Consent recorded: $docId  sha256=$textHash');
  }
}
