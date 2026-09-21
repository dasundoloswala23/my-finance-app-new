import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';
import '../../../core/firestore_refs.dart';
import '../../accounts/data/account_repository.dart';
import '../domain/transfer.dart';

/// Reads and writes account-to-account transfers.
///
/// Like transactions, every write is atomic with the two balance updates, so a
/// transfer can never leave money debited from one account without crediting
/// the other.
class TransferRepository {
  TransferRepository(this._db, String uid)
    : _refs = FirestoreRefs(_db, uid),
      _accounts = AccountRepository(_db, uid);

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;
  final AccountRepository _accounts;

  Stream<List<Transfer>> watchTransfers({int? limit}) {
    Query<Map<String, dynamic>> query = _refs.transfers.orderBy(
      'date',
      descending: true,
    );
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(Transfer.fromDoc).toList(),
    );
  }

  Future<void> create({
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Cannot transfer to the same account.');
    }

    final docRef = _refs.transfers.doc();
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        applyTransfer(
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          amountMinor: amountMinor,
        ),
      );
      transaction.set(docRef, {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountMinor': amountMinor,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
    });
  }

  Future<void> update(
    Transfer original, {
    required String fromAccountId,
    required String toAccountId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Cannot transfer to the same account.');
    }

    final docRef = _refs.transfers.doc(original.id);
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        editTransfer(
          oldFromAccountId: original.fromAccountId,
          oldToAccountId: original.toAccountId,
          oldAmountMinor: original.amountMinor,
          newFromAccountId: fromAccountId,
          newToAccountId: toAccountId,
          newAmountMinor: amountMinor,
        ),
      );
      transaction.update(docRef, {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountMinor': amountMinor,
        'note': note,
        'date': Timestamp.fromDate(date),
      });
    });
  }

  Future<void> delete(Transfer transfer) async {
    final docRef = _refs.transfers.doc(transfer.id);
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        reverseTransfer(
          fromAccountId: transfer.fromAccountId,
          toAccountId: transfer.toAccountId,
          amountMinor: transfer.amountMinor,
        ),
      );
      transaction.delete(docRef);
    });
  }
}
