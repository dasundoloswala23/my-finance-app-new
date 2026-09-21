import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore_refs.dart';
import '../domain/account.dart';

class AccountRepository {
  AccountRepository(this._db, String uid) : _refs = FirestoreRefs(_db, uid);

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;

  /// Live list of accounts, Hand Money first, then alphabetical.
  ///
  /// Sorting happens client-side because a composite Firestore index on
  /// (type, name) would need provisioning and the account list is tiny.
  Stream<List<Account>> watchAccounts({bool includeArchived = false}) {
    return _refs.accounts.snapshots().map((snapshot) {
      final accounts = snapshot.docs.map(Account.fromDoc).where((account) {
        return includeArchived || !account.isArchived;
      }).toList();

      accounts.sort((a, b) {
        if (a.isHandMoney != b.isHandMoney) return a.isHandMoney ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return accounts;
    });
  }

  Future<void> create({
    required String name,
    required AccountType type,
    required int openingBalanceMinor,
  }) async {
    await _refs.accounts.add({
      'name': name,
      'type': type.name,
      'balanceMinor': openingBalanceMinor,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Renames or retypes an account. Balance is deliberately not editable here —
  /// it is derived from transactions and transfers, and letting a form
  /// overwrite it would silently desync the ledger.
  Future<void> update(
    String accountId, {
    required String name,
    required AccountType type,
  }) async {
    await _refs.accounts.doc(accountId).update({
      'name': name,
      'type': type.name,
    });
  }

  Future<void> setArchived(String accountId, bool isArchived) async {
    await _refs.accounts.doc(accountId).update({'isArchived': isArchived});
  }

  Future<void> delete(String accountId) async {
    await _refs.accounts.doc(accountId).delete();
  }

  /// Applies a set of `accountId -> delta` balance changes atomically.
  ///
  /// Used by the transaction and transfer repositories. Reads happen before
  /// writes, as Firestore transactions require.
  Future<void> applyBalanceDeltas(
    Transaction transaction,
    Map<String, int> deltas,
  ) async {
    final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final accountId in deltas.keys) {
      final ref = _refs.accounts.doc(accountId);
      snapshots[accountId] = await transaction.get(ref);
    }

    deltas.forEach((accountId, delta) {
      final snapshot = snapshots[accountId];
      if (snapshot == null || !snapshot.exists) return;
      final current = (snapshot.data()?['balanceMinor'] as num?)?.toInt() ?? 0;
      transaction.update(_refs.accounts.doc(accountId), {
        'balanceMinor': current + delta,
      });
    });
  }

  /// Creates the Hand Money account if it does not already exist.
  ///
  /// Called once per sign-in. Safe to repeat — it queries first.
  Future<void> ensureHandMoneyAccount() async {
    final existing = await _refs.accounts
        .where('type', isEqualTo: AccountType.hand.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _refs.accounts.add({
      'name': 'Hand Money',
      'type': AccountType.hand.name,
      'balanceMinor': 0,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  FirebaseFirestore get db => _db;
}
