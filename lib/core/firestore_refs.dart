import 'package:cloud_firestore/cloud_firestore.dart';

/// Central definition of the Firestore layout.
///
/// Everything a user owns lives under `users/{uid}`, which is what the security
/// rules key on. Collection names are fixed here so no screen ever hardcodes a
/// path string.
class FirestoreRefs {
  const FirestoreRefs(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  static const String usersCollection = 'users';
  static const String accountsCollection = 'accounts';
  static const String categoriesCollection = 'categories';
  static const String transactionsCollection = 'transactions';
  static const String transfersCollection = 'transfers';
  static const String debtsCollection = 'debts';
  static const String debtSettlementsCollection = 'debtSettlements';

  DocumentReference<Map<String, dynamic>> get user =>
      _db.collection(usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> get accounts =>
      user.collection(accountsCollection);

  CollectionReference<Map<String, dynamic>> get categories =>
      user.collection(categoriesCollection);

  CollectionReference<Map<String, dynamic>> get transactions =>
      user.collection(transactionsCollection);

  CollectionReference<Map<String, dynamic>> get transfers =>
      user.collection(transfersCollection);

  CollectionReference<Map<String, dynamic>> get debts =>
      user.collection(debtsCollection);

  /// Settlements are top-level and carry a `debtId`, so every settlement can be
  /// read in one query for the activity feed.
  CollectionReference<Map<String, dynamic>> get debtSettlements =>
      user.collection(debtSettlementsCollection);
}
