import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/token_model.dart';
import '../models/child_model.dart';
import '../models/document_model.dart';
import '../models/maintenance_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ── In-memory cache ────────────────────────────────────────────────────
  // Removed strict 2-minute cache for dashboard counts as it caused UI discrepancies.
  Map<String, int>? _cachedCounts;
  DateTime? _countsCachedAt;

  List<TokenModel>? _cachedRecentTokens;
  DateTime? _recentCachedAt;
  static const _recentCacheDuration = Duration(minutes: 1);

  /// Call after token create or sync completes to force fresh counts on next load.
  void invalidateCache() {
    _cachedCounts = null;
    _countsCachedAt = null;
    _cachedRecentTokens = null;
    _recentCachedAt = null;
  }

  // ────────── Token Operations ──────────

  Future<String> createToken(
    String parentName,
    String parentMobile,
    String createdBy,
  ) async {
    // Use Firestore transaction to prevent race condition
    return await _db.runTransaction<String>((transaction) async {
      // Step 1: Read current counter
      final counterRef = _db
          .collection(AppConstants.kMetaCollection)
          .doc(AppConstants.kTokenCounterDoc);
      final counterSnap = await transaction.get(counterRef);

      int lastNumber = 0;
      if (counterSnap.exists) {
        final val = counterSnap.data()?['lastTokenNumber'];
        lastNumber = (val is num && val.isFinite) ? val.toInt() : 0;
      }

      // Step 2: Calculate new token number
      final newTokenNumber = lastNumber + 1;

      // Step 3: Document ID = "{newTokenNumber}"
      final tokenDocId = '$newTokenNumber';
      final tokenRef = _db
          .collection(AppConstants.kTokensCollection)
          .doc(tokenDocId);

      // Step 4: Write counter update + new token in same transaction
      transaction.set(counterRef, {'lastTokenNumber': newTokenNumber});
      transaction.set(tokenRef, {
        'tokenNumber': newTokenNumber,
        'parentName': parentName,
        'parentMobile': parentMobile,
        'createdBy': createdBy,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'applicationId': null,
        'childDob': null,
      });

      return tokenDocId; // return "53"
    });
  }

  /// Stream that emits the NEXT token number in realtime
  /// Listens to meta/token_counter document changes
  Stream<int> streamNextTokenNumber() {
    return _db
        .collection(AppConstants.kMetaCollection)
        .doc(AppConstants.kTokenCounterDoc)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return 1;
          final val = snap.data()?['lastTokenNumber'];
          final last = (val is num && val.isFinite) ? val.toInt() : 0;
          return last + 1;
        });
  }

  Future<TokenModel?> getTokenByTokenNumber(int tokenNumber) async {
    final docId = '$tokenNumber';
    final doc = await _db
        .collection(AppConstants.kTokensCollection)
        .doc(docId)
        .get();

    if (!doc.exists) return null;
    return TokenModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<TokenModel?> getTokenById(
    String tokenId, {
    bool forceServer = false,
  }) async {
    final doc = await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .get(
          GetOptions(
            source: forceServer ? Source.server : Source.serverAndCache,
          ),
        );
    if (!doc.exists || doc.data() == null) return null;
    return TokenModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getTokensPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? category,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection(
      AppConstants.kTokensCollection,
    );

    // ── Apply filter FIRST, then paginate ──────────────────────────────
    // For All Generated: orderBy tokenNumber descending (auto-indexed, no manual index needed)
    // For categories: where only — NO orderBy — avoids composite index requirement
    if (category == null || category == 'All Generated') {
      query = query.orderBy('tokenNumber', descending: true);
    } else if (category == 'Re-submitted') {
      query = query.where('applicationHistory', isNotEqualTo: []);
    } else {
      // APPROVED / CANCELLED / CORRECTION
      query = query.where('govStatus', isEqualTo: category.toUpperCase());
    }

    query = query.limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  Future<void> updateTokenStatus(
    String tokenId,
    String status, {
    String? applicationId,
    String? childDob,
    Map<String, dynamic>? historyEntry,
  }) async {
    final Map<String, dynamic> data = {'status': status};
    if (applicationId != null) data['applicationId'] = applicationId;
    if (childDob != null) data['childDob'] = childDob;

    if (historyEntry != null) {
      data['applicationHistory'] = FieldValue.arrayUnion([historyEntry]);
    }

    await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .update(data);
  }

  Future<void> updateParentInfo(
    String tokenId,
    String name,
    String mobile,
  ) async {
    await _db.collection(AppConstants.kTokensCollection).doc(tokenId).update({
      'parentName': name,
      'parentMobile': mobile,
    });
  }

  Future<void> updateGovStatus(
    String tokenId, {
    required String govStatus,
    required String message,
    String? govChildName,
    String? govParentMobile,
  }) async {
    final data = <String, dynamic>{
      'govStatus': govStatus,
      'govStatusMessage': message,
      'lastSyncAt': FieldValue.serverTimestamp(),
    };

    // 🔥 Only update if valid (avoid overwrite with null)
    if (govChildName != null && govChildName.trim().isNotEmpty) {
      data['govChildName'] = govChildName.trim();
    }
    
    if (govParentMobile != null && govParentMobile.trim().isNotEmpty) {
      data['govParentMobile'] = govParentMobile.trim();
    }

    await _db.collection(AppConstants.kTokensCollection).doc(tokenId).update(data);

    // 🔥 Update meta document to trigger real-time auto-refresh in dashboard
    await _db.collection(AppConstants.kMetaCollection).doc(AppConstants.kTokenCounterDoc).update({
      'lastUpdateAt': FieldValue.serverTimestamp(),
    });
  }

  // ────────── Child Operations ──────────

  Future<String> addChild(String tokenId, ChildModel child) async {
    final colRef = _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kChildrenCollection);
    final docRef = await colRef.add(child.toMap());
    return docRef.id;
  }

  Future<void> updateChild(
    String tokenId,
    String childId,
    ChildModel child,
  ) async {
    await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kChildrenCollection)
        .doc(childId)
        .update(child.toMap());
  }

  Future<Map<String, int>> getTokenCounts({bool forceRefresh = false}) async {
    // Run all count queries IN PARALLEL
    // Note: Firestore .count() is not real-time so we fetch it on demand.
    final results = await Future.wait([
      _db.collection(AppConstants.kTokensCollection).count().get(),
      _db
          .collection(AppConstants.kTokensCollection)
          .where('govStatus', isEqualTo: 'APPROVED')
          .count()
          .get(),
      _db
          .collection(AppConstants.kTokensCollection)
          .where('govStatus', isEqualTo: 'SUBMITTED')
          .count()
          .get(),
      _db
          .collection(AppConstants.kTokensCollection)
          .where('govStatus', isEqualTo: 'PENDING')
          .count()
          .get(),
      _db
          .collection(AppConstants.kTokensCollection)
          .where('govStatus', isEqualTo: 'CORRECTION')
          .count()
          .get(),
      _db
          .collection(AppConstants.kTokensCollection)
          .where('govStatus', isEqualTo: 'CANCELLED')
          .count()
          .get(),
    ]);

    _cachedCounts = {
      'total': results[0].count ?? 0,
      'approved': results[1].count ?? 0,
      'submitted': results[2].count ?? 0,
      'pending': results[3].count ?? 0,
      'correction': results[4].count ?? 0,
      'cancelled': results[5].count ?? 0,
    };
    _countsCachedAt = DateTime.now();
    return _cachedCounts!;
  }

  /// Stream that emits token counts roughly in realtime by listening to meta changes.
  /// Note: Since Firestore .count() doesn't have a stream, we trigger this
  /// manually or listen to the meta counter for a 'hint' to refresh.
  Stream<Map<String, int>> streamTokenCounts() {
    final docRef = _db
        .collection(AppConstants.kMetaCollection)
        .doc(AppConstants.kTokenCounterDoc);
    return docRef.snapshots().asyncMap((_) async {
      return await getTokenCounts(forceRefresh: true);
    });
  }

  Future<List<ChildModel>> getChildren(String tokenId) async {
    final query = await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kChildrenCollection)
        .get();

    return query.docs
        .map((doc) => ChildModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // ────────── Document Operations ──────────

  Future<String> addDocument(String tokenId, DocumentModel doc) async {
    final colRef = _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kDocumentsCollection);
    final docRef = await colRef.add(doc.toMap());
    return docRef.id;
  }

  Future<List<DocumentModel>> getDocuments(String tokenId) async {
    final query = await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kDocumentsCollection)
        .get();

    return query.docs
        .map((doc) => DocumentModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<void> deleteDocument(String tokenId, String docId) async {
    await _db
        .collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kDocumentsCollection)
        .doc(docId)
        .delete();
  }

  Future<void> deleteToken(String tokenId) async {
    await _db.collection(AppConstants.kTokensCollection).doc(tokenId).delete();
  }

  // ────────── Search & Recent ──────────

  Future<List<TokenModel>> getRecentTokens(
    int limit, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedRecentTokens != null &&
        _recentCachedAt != null &&
        DateTime.now().difference(_recentCachedAt!) < _recentCacheDuration) {
      return _cachedRecentTokens!;
    }

    final snapshot = await _db
        .collection(AppConstants.kTokensCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    _cachedRecentTokens = snapshot.docs
        .map((doc) => TokenModel.fromFirestore(doc.data(), doc.id))
        .toList();
    _recentCachedAt = DateTime.now();
    return _cachedRecentTokens!;
  }

  Future<List<TokenModel>> searchByMobile(String mobile) async {
    final query = await _db
        .collection(AppConstants.kTokensCollection)
        .where('parentMobile', isEqualTo: mobile)
        .limit(50) // Safety cap — a mobile won't have 50+ tokens
        .get();
    return query.docs
        .map((doc) => TokenModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<List<TokenModel>> searchByName(String name) async {
    final query = await _db
        .collection(AppConstants.kTokensCollection)
        .where('parentName', isGreaterThanOrEqualTo: name)
        .where('parentName', isLessThanOrEqualTo: '$name\uf8ff')
        .limit(50)
        .get();
    return query.docs
        .map((doc) => TokenModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Search by Token Number — direct document ID lookup (fastest possible)
  Future<TokenModel?> searchByTokenNumber(int tokenNumber) async {
    final doc = await _db
        .collection(AppConstants.kTokensCollection)
        .doc('$tokenNumber')
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return TokenModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Search by Application ID — exact match on 'applicationId' field
  Future<List<TokenModel>> searchByApplicationId(String appId) async {
    final query = await _db
        .collection(AppConstants.kTokensCollection)
        .where('applicationId', isEqualTo: appId.trim())
        .limit(10)
        .get();
    return query.docs
        .map((doc) => TokenModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Fetch tokens for sync in pages of [chunkSize] to avoid loading 500+ at once.
  /// Calls [onChunk] with each batch so the UI can update progress incrementally.
  Future<void> getTokensForSync({
    int chunkSize = 100,
    required Future<void> Function(List<TokenModel> chunk) onChunk,
  }) async {
    DocumentSnapshot? lastDoc;
    int total = 0;
    while (true) {
      Query<Map<String, dynamic>> q = _db
          .collection(AppConstants.kTokensCollection)
          .orderBy(
            'tokenNumber',
          ) // ascending — auto-indexed, no manual index needed
          .limit(chunkSize);
      if (lastDoc != null) q = q.startAfterDocument(lastDoc);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      final tokens = snap.docs
          .map((d) => TokenModel.fromFirestore(d.data(), d.id))
          .toList();
      await onChunk(tokens);
      total += tokens.length;
      lastDoc = snap.docs.last;
      if (snap.docs.length < chunkSize) break; // Last page
    }
    debugPrint('Sync complete: $total records processed.');
  }

  // ────────── Admin Auth ──────────

  Future<Map<String, dynamic>> getAdminConfig() async {
    final snap = await _db
        .collection(AppConstants.kAdminCollection)
        .doc(AppConstants.kAdminDoc)
        .get();
    return snap.data() ?? {};
  }

  Future<bool> verifyAdmin(String username, String password) async {
    try {
      final snap = await _db
          .collection(AppConstants.kAdminCollection)
          .doc(AppConstants.kAdminDoc)
          .get();
      if (!snap.exists) return false;

      final data = snap.data();
      return (data?['username'] == username && data?['password'] == password);
    } catch (e) {
      return false;
    }
  }

  // ────────── Maintenance ──────────

  Future<MaintenanceModel> getMaintenanceStatus() async {
    try {
      final doc = await _db.collection('rte-2026-27').doc('admin').get();
      if (!doc.exists) return MaintenanceModel.defaults();
      return MaintenanceModel.fromFirestore(doc.data()!);
    } catch (e) {
      return MaintenanceModel.defaults(); // fail safe — never block app
    }
  }

  /// Realtime stream for maintenance status
  Stream<MaintenanceModel> streamMaintenanceStatus() {
    return _db.collection('rte-2026-27').doc('admin').snapshots().map((snap) {
      if (!snap.exists) return MaintenanceModel.defaults();
      return MaintenanceModel.fromFirestore(snap.data()!);
    });
  }
}
