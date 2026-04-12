import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/token_model.dart';
import '../models/child_model.dart';
import '../models/document_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ────────── Token Operations ──────────

  Future<String> createToken(String parentName, String parentMobile, String createdBy) async {
    // Use Firestore transaction to prevent race condition
    return await _db.runTransaction<String>((transaction) async {
      
      // Step 1: Read current counter
      final counterRef = _db.collection(AppConstants.kMetaCollection).doc(AppConstants.kTokenCounterDoc);
      final counterSnap = await transaction.get(counterRef);
      
      int lastNumber = 0;
      if (counterSnap.exists) {
        lastNumber = (counterSnap.data()?['lastTokenNumber'] ?? 0) as int;
      }
      
      // Step 2: Calculate new token number
      final newTokenNumber = lastNumber + 1;
      
      // Step 3: Document ID = "{newTokenNumber}"
      final tokenDocId = '$newTokenNumber';
      final tokenRef = _db.collection(AppConstants.kTokensCollection).doc(tokenDocId);
      
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
          final last = (snap.data()?['lastTokenNumber'] ?? 0) as int;
          return last + 1;
        });
  }

  Future<TokenModel?> getTokenByTokenNumber(int tokenNumber) async {
    final docId = '$tokenNumber';
    final doc = await _db.collection(AppConstants.kTokensCollection).doc(docId).get();
          
    if (!doc.exists) return null;
    return TokenModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<TokenModel?> getTokenById(String tokenId) async {
    final doc = await _db.collection(AppConstants.kTokensCollection).doc(tokenId).get();
    if (!doc.exists) return null;
    return TokenModel.fromFirestore(doc.data()!, doc.id);
  }

  Stream<List<TokenModel>> getAllTokens() {
    return _db.collection(AppConstants.kTokensCollection)
        .orderBy('tokenNumber', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TokenModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateTokenStatus(
    String tokenId, 
    String status, {
    String? applicationId,
    String? childDob,
  }) async {
    final Map<String, dynamic> data = {'status': status};
    if (applicationId != null) data['applicationId'] = applicationId;
    if (childDob != null) data['childDob'] = childDob;
    
    await _db.collection(AppConstants.kTokensCollection).doc(tokenId).update(data);
  }

  // ────────── Child Operations ──────────

  Future<String> addChild(String tokenId, ChildModel child) async {
    final colRef = _db.collection(AppConstants.kTokensCollection).doc(tokenId).collection(AppConstants.kChildrenCollection);
    final docRef = await colRef.add(child.toMap());
    return docRef.id;
  }

  Future<void> updateChild(String tokenId, String childId, ChildModel child) async {
    await _db.collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kChildrenCollection)
        .doc(childId)
        .update(child.toMap());
  }

  Future<List<ChildModel>> getChildren(String tokenId) async {
    final query = await _db.collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kChildrenCollection)
        .get();
        
    return query.docs.map((doc) => ChildModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  // ────────── Document Operations ──────────

  Future<String> addDocument(String tokenId, DocumentModel doc) async {
    final colRef = _db.collection(AppConstants.kTokensCollection).doc(tokenId).collection(AppConstants.kDocumentsCollection);
    final docRef = await colRef.add(doc.toMap());
    return docRef.id;
  }

  Future<List<DocumentModel>> getDocuments(String tokenId) async {
    final query = await _db.collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kDocumentsCollection)
        .get();
        
    return query.docs.map((doc) => DocumentModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<void> deleteDocument(String tokenId, String docId) async {
    await _db.collection(AppConstants.kTokensCollection)
        .doc(tokenId)
        .collection(AppConstants.kDocumentsCollection)
        .doc(docId)
        .delete();
  }

  // ────────── Search ──────────

  Future<List<TokenModel>> searchByMobile(String mobile) async {
    final query = await _db.collection(AppConstants.kTokensCollection)
        .where('parentMobile', isEqualTo: mobile)
        .get();
    return query.docs.map((doc) => TokenModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  Future<List<TokenModel>> searchByName(String name) async {
    final query = await _db.collection(AppConstants.kTokensCollection)
        .where('parentName', isGreaterThanOrEqualTo: name)
        .where('parentName', isLessThanOrEqualTo: '$name\uf8ff')
        .get();
    return query.docs.map((doc) => TokenModel.fromFirestore(doc.data(), doc.id)).toList();
  }

  // ────────── Admin Auth ──────────

  Future<bool> verifyAdmin(String username, String password) async {
    try {
      final snap = await _db.collection(AppConstants.kAdminCollection).doc(AppConstants.kAdminDoc).get();
      if (!snap.exists) return false;
      
      final data = snap.data();
      return (data?['username'] == username && data?['password'] == password);
    } catch (e) {
      return false;
    }
  }
}
