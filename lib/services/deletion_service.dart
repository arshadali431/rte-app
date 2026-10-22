import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_links.dart';
import '../models/deletion_request.dart';
import '../models/token_model.dart';

/// Reason codes for a rejected deletion request.
class DeletionException implements Exception {
  /// tokenNotFound | tokenMismatch | mobileMismatch | unknown
  final String code;
  const DeletionException(this.code);

  @override
  String toString() => 'DeletionException($code)';
}

/// Pure, unit-testable rules for the self-service deletion flow.
///
/// Kept separate from Firestore so the security-sensitive checks can be tested
/// without emulator/auth setup.
class DeletionRules {
  const DeletionRules._();

  /// Fields the post-delete tombstone is allowed to contain. Mirrored by
  /// `functions/deleteScheduled.js` — never add personal data here.
  static const List<String> tombstoneFieldWhitelist = [
    'tokenId',
    'deletedAt',
    'consentGivenAt',
    'consentVersion',
    'withdrawnAt',
  ];

  /// STOPGAP identity check: token number + registered mobile number.
  /// TODO(auth-migration): Replace with Firebase Auth phone/OTP re-auth once
  /// Auth is live (see PROJECT_AUDIT.md P0-3).
  static bool tokenNumberMatches({
    required int tokenNumber,
    required String input,
  }) =>
      int.tryParse(input.trim()) == tokenNumber;

  static bool mobileMatches({
    required String registeredMobile,
    required String input,
  }) {
    final registered = _digits(registeredMobile);
    final entered = _digits(input);
    return registered.isNotEmpty && entered.isNotEmpty && registered == entered;
  }

  static bool identityMatches({
    required int tokenNumber,
    required String registeredMobile,
    required String tokenNumberInput,
    required String mobileInput,
  }) =>
      tokenNumberMatches(tokenNumber: tokenNumber, input: tokenNumberInput) &&
      mobileMatches(registeredMobile: registeredMobile, input: mobileInput);

  /// When the scheduled hard delete becomes eligible (grace period).
  static DateTime executeAfter(DateTime requestedAt) =>
      requestedAt.add(const Duration(hours: kDeletionGraceHours));

  /// Office lists / searches / counters hide tokens with a pending request.
  static bool isHiddenFromOffice({required bool deletionPending}) =>
      deletionPending;

  static bool shouldHideToken(TokenModel token) => token.deletionPending;

  static List<TokenModel> visibleToOffice(Iterable<TokenModel> tokens) =>
      tokens.where((token) => !token.deletionPending).toList();

  /// Minimal, non-personal tombstone written after a hard delete.
  static Map<String, dynamic> buildTombstone({
    required String tokenId,
    required DateTime deletedAt,
    DateTime? consentGivenAt,
    Object? consentVersion,
    DateTime? withdrawnAt,
  }) {
    final tombstone = <String, dynamic>{
      'tokenId': tokenId,
      'deletedAt': Timestamp.fromDate(deletedAt),
    };
    if (consentGivenAt != null) {
      tombstone['consentGivenAt'] = Timestamp.fromDate(consentGivenAt);
    }
    if (consentVersion != null) {
      tombstone['consentVersion'] = consentVersion;
    }
    if (withdrawnAt != null) {
      tombstone['withdrawnAt'] = Timestamp.fromDate(withdrawnAt);
    }
    return tombstone;
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}

/// Firestore side of the self-service deletion flow.
class DeletionService {
  DeletionService._();
  static final DeletionService _instance = DeletionService._();
  factory DeletionService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String kTokensCollection = 'tokens';
  static const String kDeletionRequestsCollection = 'deletion_requests';
  static const String kConsentCollection = 'consent_records';

  Future<DeletionRequest?> getRequest(String tokenId) async {
    try {
      final snap = await _db
          .collection(kDeletionRequestsCollection)
          .doc(tokenId)
          .get();
      if (!snap.exists || snap.data() == null) return null;
      return DeletionRequest.fromFirestore(snap.data()!, snap.id);
    } catch (_) {
      return null;
    }
  }

  /// True when the parent has an active (not yet executed/cancelled) request.
  Future<bool> hasPendingDeletion(String tokenId) async {
    final request = await getRequest(tokenId);
    return request?.isPendingAt(DateTime.now()) ?? false;
  }

  /// Validates the stopgap identity proof, then schedules the deletion.
  ///
  /// Writes both documents atomically:
  ///  * `deletion_requests/{tokenId}` — requestedAt, executeAfter, status
  ///  * `tokens/{tokenId}.deletionPending = true
  Future<void> requestDeletion({
    required String tokenId,
    required String tokenNumberInput,
    required String mobileInput,
  }) async {
    final tokenSnap = await _db.collection(kTokensCollection).doc(tokenId).get();
    if (!tokenSnap.exists || tokenSnap.data() == null) {
      throw const DeletionException('tokenNotFound');
    }

    final token = TokenModel.fromFirestore(tokenSnap.data()!, tokenSnap.id);
    if (!DeletionRules.tokenNumberMatches(
      tokenNumber: token.tokenNumber,
      input: tokenNumberInput,
    )) {
      throw const DeletionException('tokenMismatch');
    }
    if (!DeletionRules.mobileMatches(
      registeredMobile: token.parentMobile,
      input: mobileInput,
    )) {
      throw const DeletionException('mobileMismatch');
    }

    final executeAfter = DeletionRules.executeAfter(DateTime.now());
    final batch = _db.batch();
    batch.set(_db.collection(kDeletionRequestsCollection).doc(tokenId), {
      'requestedAt': FieldValue.serverTimestamp(),
      'executeAfter': Timestamp.fromDate(executeAfter),
      'status': 'pending',
    });
    batch.update(_db.collection(kTokensCollection).doc(tokenId), {
      'deletionPending': true,
      'deletionRequestedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Cancels a pending request and restores office visibility.
  Future<void> cancelDeletion(String tokenId) async {
    final batch = _db.batch();
    batch.update(
      _db.collection(kDeletionRequestsCollection).doc(tokenId),
      {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      },
    );
    batch.update(_db.collection(kTokensCollection).doc(tokenId), {
      'deletionPending': false,
    });
    await batch.commit();
  }
}
