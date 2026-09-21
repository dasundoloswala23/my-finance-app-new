import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';
import '../../../core/firestore_refs.dart';
import '../../accounts/data/account_repository.dart';
import '../domain/txn.dart';

/// Reads and writes income/expense entries.
///
/// Every write that affects a balance runs inside `runTransaction` together
/// with the account update, so the ledger and the balances can never disagree
/// — even if the app is killed mid-write.
class TransactionRepository {
  TransactionRepository(this._db, String uid)
    : _refs = FirestoreRefs(_db, uid),
      _accounts = AccountRepository(_db, uid);

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;
  final AccountRepository _accounts;

  /// Most recent entries first. [limit] keeps the dashboard query small.
  Stream<List<Txn>> watchTransactions({int? limit}) {
    Query<Map<String, dynamic>> query = _refs.transactions.orderBy(
      'date',
      descending: true,
    );
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(Txn.fromDoc).toList(),
    );
  }

  /// Entries within a half-open date range, used for monthly totals.
  Stream<List<Txn>> watchRange(DateTime start, DateTime end) {
    return _refs.transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Txn.fromDoc).toList());
  }

  Future<void> create({
    required TxnType type,
    required int amountMinor,
    required String accountId,
    required DateTime date,
    String? categoryId,
    String note = '',
  }) async {
    final docRef = _refs.transactions.doc();
    await _db.runTransaction((transaction) async {
      // Reads must precede writes, so compute and apply balance deltas first.
      await _accounts.applyBalanceDeltas(
        transaction,
        applyTransaction(
          accountId: accountId,
          type: type,
          amountMinor: amountMinor,
        ),
      );
      transaction.set(docRef, {
        'type': type.name,
        'amountMinor': amountMinor,
        'accountId': accountId,
        'categoryId': categoryId,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
    });
  }

  /// Edits an entry, reversing its old balance effect and applying the new one
  /// in a single atomic step.
  Future<void> update(
    Txn original, {
    required TxnType type,
    required int amountMinor,
    required String accountId,
    required DateTime date,
    String? categoryId,
    String note = '',
  }) async {
    final docRef = _refs.transactions.doc(original.id);
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        editTransaction(
          oldAccountId: original.accountId,
          oldType: original.type,
          oldAmountMinor: original.amountMinor,
          newAccountId: accountId,
          newType: type,
          newAmountMinor: amountMinor,
        ),
      );
      transaction.update(docRef, {
        'type': type.name,
        'amountMinor': amountMinor,
        'accountId': accountId,
        'categoryId': categoryId,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
    });
  }

  Future<void> delete(Txn txn) async {
    final docRef = _refs.transactions.doc(txn.id);
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        reverseTransaction(
          accountId: txn.accountId,
          type: txn.type,
          amountMinor: txn.amountMinor,
        ),
      );
      transaction.delete(docRef);
    });
  }
}
