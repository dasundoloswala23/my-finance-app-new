import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';
import '../../../core/firestore_refs.dart';
import '../../accounts/data/account_repository.dart';
import '../domain/debt.dart';
import '../domain/debt_settlement.dart';

/// Reads and writes debts and their settlements.
///
/// Every write runs inside `runTransaction` alongside the account balance
/// update, so a debt can never exist without the cash having moved, and a
/// settlement can never be recorded without the balance following it.
///
/// Firestore requires all reads in a transaction to happen before any write,
/// and [AccountRepository.applyBalanceDeltas] reads the account documents
/// itself — so wherever the debt document is also needed, it is read *first*.
class DebtRepository {
  DebtRepository(this._db, String uid)
    : _refs = FirestoreRefs(_db, uid),
      _accounts = AccountRepository(_db, uid);

  final FirebaseFirestore _db;
  final FirestoreRefs _refs;
  final AccountRepository _accounts;

  /// Live debt list, newest first.
  Stream<List<Debt>> watchDebts() {
    return _refs.debts
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Debt.fromDoc).toList());
  }

  /// Settlements for one debt, newest first.
  ///
  /// Sorted client-side: ordering by `date` alongside the `debtId` filter would
  /// need a composite index, and a single debt never has many settlements.
  Stream<List<DebtSettlement>> watchSettlementsFor(String debtId) {
    return _refs.debtSettlements
        .where('debtId', isEqualTo: debtId)
        .snapshots()
        .map((snapshot) {
          final settlements = snapshot.docs
              .map(DebtSettlement.fromDoc)
              .toList();
          settlements.sort((a, b) => b.date.compareTo(a.date));
          return settlements;
        });
  }

  /// Every settlement, for the activity feed.
  Stream<List<DebtSettlement>> watchAllSettlements({int? limit}) {
    Query<Map<String, dynamic>> query = _refs.debtSettlements.orderBy(
      'date',
      descending: true,
    );
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(DebtSettlement.fromDoc).toList(),
    );
  }

  Future<void> create({
    required String personName,
    required DebtDirection direction,
    required int principalMinor,
    required String accountId,
    required DateTime date,
    DateTime? dueDate,
    String note = '',
  }) async {
    if (principalMinor <= 0) {
      throw ArgumentError('A debt must be greater than zero.');
    }

    final docRef = _refs.debts.doc();
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        applyDebt(
          accountId: accountId,
          direction: direction,
          amountMinor: principalMinor,
        ),
      );
      transaction.set(docRef, {
        'personName': personName,
        'direction': direction.name,
        'principalMinor': principalMinor,
        'settledMinor': 0,
        'accountId': accountId,
        'date': Timestamp.fromDate(date),
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'note': note,
        'isSettled': false,
      });
    });
  }

  /// Edits a debt, reversing its old balance effect and applying the new one
  /// atomically.
  ///
  /// The new principal cannot drop below what has already been settled — that
  /// would leave the debt over-settled and the arithmetic inconsistent.
  Future<void> update(
    Debt original, {
    required String personName,
    required DebtDirection direction,
    required int principalMinor,
    required String accountId,
    required DateTime date,
    DateTime? dueDate,
    String note = '',
  }) async {
    if (principalMinor <= 0) {
      throw ArgumentError('A debt must be greater than zero.');
    }
    if (principalMinor < original.settledMinor) {
      throw ArgumentError(
        'This debt already has settlements totalling more than that amount.',
      );
    }

    final docRef = _refs.debts.doc(original.id);
    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(
        transaction,
        editDebt(
          oldAccountId: original.accountId,
          oldDirection: original.direction,
          oldAmountMinor: original.principalMinor,
          newAccountId: accountId,
          newDirection: direction,
          newAmountMinor: principalMinor,
        ),
      );
      transaction.update(docRef, {
        'personName': personName,
        'direction': direction.name,
        'principalMinor': principalMinor,
        'accountId': accountId,
        'date': Timestamp.fromDate(date),
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
        'note': note,
        'isSettled': principalMinor - original.settledMinor <= 0,
      });
    });
  }

  /// Deletes a debt and every settlement recorded against it.
  ///
  /// The settlements' balance effects are reversed too — deleting a partly
  /// settled debt while leaving its repayments applied would strand money in
  /// the account.
  Future<void> delete(Debt debt) async {
    // Read outside the transaction: a Firestore transaction cannot run a query,
    // only document reads. The settlement set for one debt is small and the
    // balance deltas below are still applied atomically.
    final settlementDocs = await _refs.debtSettlements
        .where('debtId', isEqualTo: debt.id)
        .get();
    final settlements = settlementDocs.docs.map(DebtSettlement.fromDoc).toList();

    final deltas = mergeDeltas([
      reverseDebt(
        accountId: debt.accountId,
        direction: debt.direction,
        amountMinor: debt.principalMinor,
      ),
      for (final settlement in settlements)
        reverseDebtSettlement(
          accountId: settlement.accountId,
          direction: debt.direction,
          amountMinor: settlement.amountMinor,
        ),
    ]);

    await _db.runTransaction((transaction) async {
      await _accounts.applyBalanceDeltas(transaction, deltas);
      for (final settlement in settlements) {
        transaction.delete(_refs.debtSettlements.doc(settlement.id));
      }
      transaction.delete(_refs.debts.doc(debt.id));
    });
  }

  /// Records a repayment against [debt].
  ///
  /// Rejects anything above the outstanding amount rather than letting
  /// `settledMinor` run past the principal.
  Future<void> addSettlement(
    Debt debt, {
    required int amountMinor,
    required String accountId,
    required DateTime date,
    String note = '',
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('A settlement must be greater than zero.');
    }

    final debtRef = _refs.debts.doc(debt.id);
    final settlementRef = _refs.debtSettlements.doc();

    await _db.runTransaction((transaction) async {
      // Read the debt before any write, and before applyBalanceDeltas issues
      // its own reads.
      final snapshot = await transaction.get(debtRef);
      if (!snapshot.exists) {
        throw StateError('That debt no longer exists.');
      }
      final current = Debt.fromDoc(snapshot);
      if (amountMinor > current.outstandingMinor) {
        throw ArgumentError(
          'That is more than the outstanding amount on this debt.',
        );
      }

      await _accounts.applyBalanceDeltas(
        transaction,
        applyDebtSettlement(
          accountId: accountId,
          direction: current.direction,
          amountMinor: amountMinor,
        ),
      );

      final newSettled = current.settledMinor + amountMinor;
      transaction.update(debtRef, {
        'settledMinor': newSettled,
        'isSettled': newSettled >= current.principalMinor,
      });
      transaction.set(settlementRef, {
        'debtId': debt.id,
        'amountMinor': amountMinor,
        'accountId': accountId,
        'date': Timestamp.fromDate(date),
        'note': note,
      });
    });
  }

  Future<void> updateSettlement(
    Debt debt,
    DebtSettlement original, {
    required int amountMinor,
    required String accountId,
    required DateTime date,
    String note = '',
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('A settlement must be greater than zero.');
    }

    final debtRef = _refs.debts.doc(debt.id);
    final settlementRef = _refs.debtSettlements.doc(original.id);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      if (!snapshot.exists) {
        throw StateError('That debt no longer exists.');
      }
      final current = Debt.fromDoc(snapshot);

      // Outstanding excluding this settlement, so editing it upwards is judged
      // against the right ceiling.
      final settledWithout = current.settledMinor - original.amountMinor;
      if (amountMinor > current.principalMinor - settledWithout) {
        throw ArgumentError(
          'That is more than the outstanding amount on this debt.',
        );
      }

      await _accounts.applyBalanceDeltas(
        transaction,
        editDebtSettlement(
          oldAccountId: original.accountId,
          oldAmountMinor: original.amountMinor,
          newAccountId: accountId,
          newAmountMinor: amountMinor,
          direction: current.direction,
        ),
      );

      final newSettled = settledWithout + amountMinor;
      transaction.update(debtRef, {
        'settledMinor': newSettled,
        'isSettled': newSettled >= current.principalMinor,
      });
      transaction.update(settlementRef, {
        'amountMinor': amountMinor,
        'accountId': accountId,
        'date': Timestamp.fromDate(date),
        'note': note,
      });
    });
  }

  Future<void> deleteSettlement(Debt debt, DebtSettlement settlement) async {
    final debtRef = _refs.debts.doc(debt.id);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      if (!snapshot.exists) {
        throw StateError('That debt no longer exists.');
      }
      final current = Debt.fromDoc(snapshot);

      await _accounts.applyBalanceDeltas(
        transaction,
        reverseDebtSettlement(
          accountId: settlement.accountId,
          direction: current.direction,
          amountMinor: settlement.amountMinor,
        ),
      );

      final newSettled = current.settledMinor - settlement.amountMinor;
      transaction.update(debtRef, {
        'settledMinor': newSettled < 0 ? 0 : newSettled,
        'isSettled': newSettled >= current.principalMinor,
      });
      transaction.delete(_refs.debtSettlements.doc(settlement.id));
    });
  }
}
