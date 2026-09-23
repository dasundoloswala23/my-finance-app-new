import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/pending_sms_txn.dart';

/// Stores SMS-detected transaction candidates under
/// `users/{uid}/pendingSmsTxns`, separate from the real ledger.
class PendingSmsRepository {
  PendingSmsRepository(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  static const String collectionName = 'pendingSmsTxns';

  CollectionReference<Map<String, dynamic>> get _collection => _db
      .collection('users')
      .doc(uid)
      .collection(collectionName);

  Stream<List<PendingSmsTxn>> watchAll() {
    return _collection
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PendingSmsTxn.fromDoc).toList());
  }

  Future<void> add(PendingSmsTxn candidate) {
    return _collection.doc(candidate.id).set(candidate.toMap());
  }

  Future<void> discard(String id) {
    return _collection.doc(id).delete();
  }
}
