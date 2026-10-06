import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/balance_math.dart';

void main() {
  group('applyTransaction', () {
    test('income increases the account', () {
      expect(
        applyTransaction(
          accountId: 'a',
          type: TxnType.income,
          amountMinor: 5000,
        ),
        {'a': 5000},
      );
    });

    test('expense decreases the account', () {
      expect(
        applyTransaction(
          accountId: 'a',
          type: TxnType.expense,
          amountMinor: 5000,
        ),
        {'a': -5000},
      );
    });
  });

  group('reverseTransaction', () {
    test('cancels out the applied delta', () {
      const accountId = 'a';
      for (final type in TxnType.values) {
        final applied = applyTransaction(
          accountId: accountId,
          type: type,
          amountMinor: 1234,
        );
        final reversed = reverseTransaction(
          accountId: accountId,
          type: type,
          amountMinor: 1234,
        );
        expect(mergeDeltas([applied, reversed]), isEmpty);
      }
    });
  });

  group('editTransaction', () {
    test('same account, amount change yields a single net delta', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 1000,
        newAccountId: 'a',
        newType: TxnType.expense,
        newAmountMinor: 1500,
      );
      // Spending 500 more must reduce the balance by a further 500.
      expect(delta, {'a': -500});
    });

    test('flipping expense to income doubles back the amount', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 1000,
        newAccountId: 'a',
        newType: TxnType.income,
        newAmountMinor: 1000,
      );
      // Undo -1000 then apply +1000 = +2000.
      expect(delta, {'a': 2000});
    });

    test('moving to another account credits the old and debits the new', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 700,
        newAccountId: 'b',
        newType: TxnType.expense,
        newAmountMinor: 700,
      );
      expect(delta, {'a': 700, 'b': -700});
    });

    test('an unchanged edit produces no writes', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.income,
        oldAmountMinor: 250,
        newAccountId: 'a',
        newType: TxnType.income,
        newAmountMinor: 250,
      );
      expect(delta, isEmpty);
    });
  });

  group('applyTransfer', () {
    test('debits the source and credits the destination', () {
      expect(
        applyTransfer(fromAccountId: 'a', toAccountId: 'b', amountMinor: 2500),
        {'a': -2500, 'b': 2500},
      );
    });

    test('never changes net worth', () {
      final delta = applyTransfer(
        fromAccountId: 'a',
        toAccountId: 'b',
        amountMinor: 9999,
      );
      expect(delta.values.reduce((a, b) => a + b), 0);
    });
  });

  group('editTransfer', () {
    test('amount change on the same pair nets out correctly', () {
      final delta = editTransfer(
        oldFromAccountId: 'a',
        oldToAccountId: 'b',
        oldAmountMinor: 1000,
        newFromAccountId: 'a',
        newToAccountId: 'b',
        newAmountMinor: 1500,
      );
      expect(delta, {'a': -500, 'b': 500});
    });

    test('changing the destination restores the old one', () {
      final delta = editTransfer(
        oldFromAccountId: 'a',
        oldToAccountId: 'b',
        oldAmountMinor: 1000,
        newFromAccountId: 'a',
        newToAccountId: 'c',
        newAmountMinor: 1000,
      );
      // 'a' is unchanged and must not be written at all.
      expect(delta, {'b': -1000, 'c': 1000});
    });

    test('reversing direction swaps both sides', () {
      final delta = editTransfer(
        oldFromAccountId: 'a',
        oldToAccountId: 'b',
        oldAmountMinor: 1000,
        newFromAccountId: 'b',
        newToAccountId: 'a',
        newAmountMinor: 1000,
      );
      expect(delta, {'a': 2000, 'b': -2000});
    });
  });

  group('mergeDeltas', () {
    test('sums per account and drops zero-net entries', () {
      final merged = mergeDeltas([
        {'a': 100, 'b': -50},
        {'a': -100, 'c': 25},
      ]);
      expect(merged, {'b': -50, 'c': 25});
    });

    test('returns empty for no input', () {
      expect(mergeDeltas([]), isEmpty);
    });
  });

  group('affectsBalance on transactions', () {
    test('an entry that does not affect balance yields no delta', () {
      expect(
        applyTransaction(
          accountId: 'a',
          type: TxnType.income,
          amountMinor: 5000,
          affectsBalance: false,
        ),
        isEmpty,
      );
      expect(
        applyTransaction(
          accountId: 'a',
          type: TxnType.expense,
          amountMinor: 5000,
          affectsBalance: false,
        ),
        isEmpty,
      );
    });

    test('reversing one is also a no-op', () {
      expect(
        reverseTransaction(
          accountId: 'a',
          type: TxnType.expense,
          amountMinor: 5000,
          affectsBalance: false,
        ),
        isEmpty,
      );
    });

    test('turning the flag off on edit gives the money back', () {
      // Was an expense of 1000 against the balance; now record-only.
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 1000,
        newAccountId: 'a',
        newType: TxnType.expense,
        newAmountMinor: 1000,
        oldAffectsBalance: true,
        newAffectsBalance: false,
      );
      expect(delta, {'a': 1000});
    });

    test('turning the flag on on edit applies it for the first time', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 1000,
        newAccountId: 'a',
        newType: TxnType.expense,
        newAmountMinor: 1000,
        oldAffectsBalance: false,
        newAffectsBalance: true,
      );
      expect(delta, {'a': -1000});
    });

    test('editing an amount while the flag stays off changes nothing', () {
      final delta = editTransaction(
        oldAccountId: 'a',
        oldType: TxnType.expense,
        oldAmountMinor: 1000,
        newAccountId: 'b',
        newType: TxnType.income,
        newAmountMinor: 9999,
        oldAffectsBalance: false,
        newAffectsBalance: false,
      );
      expect(delta, isEmpty);
    });
  });

  group('affectsBalance on debts', () {
    test('a record-only debt moves no cash either way', () {
      for (final direction in DebtDirection.values) {
        expect(
          applyDebt(
            accountId: 'a',
            direction: direction,
            amountMinor: 500000,
            affectsBalance: false,
          ),
          isEmpty,
        );
      }
    });

    test('a record-only debt settled against an account still credits it', () {
      // Lent before the app existed, repaid into the bank today.
      final net = mergeDeltas([
        applyDebt(
          accountId: 'bank',
          direction: DebtDirection.given,
          amountMinor: 500000,
          affectsBalance: false,
        ),
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.given,
          amountMinor: 500000,
          affectsBalance: true,
        ),
      ]);
      expect(net, {'bank': 500000});
    });

    test('a record-only settlement leaves the balance alone', () {
      final net = mergeDeltas([
        applyDebt(
          accountId: 'bank',
          direction: DebtDirection.given,
          amountMinor: 500000,
        ),
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.given,
          amountMinor: 500000,
          affectsBalance: false,
        ),
      ]);
      // The cash left when lent and was repaid outside the tracked accounts.
      expect(net, {'bank': -500000});
    });

    test('both flags off nets to nothing', () {
      final net = mergeDeltas([
        applyDebt(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: 400000,
          affectsBalance: false,
        ),
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: 400000,
          affectsBalance: false,
        ),
      ]);
      expect(net, isEmpty);
    });

    test('turning a debt flag off on edit restores the account', () {
      final delta = editDebt(
        oldAccountId: 'hand',
        oldDirection: DebtDirection.given,
        oldAmountMinor: 500000,
        newAccountId: 'hand',
        newDirection: DebtDirection.given,
        newAmountMinor: 500000,
        oldAffectsBalance: true,
        newAffectsBalance: false,
      );
      expect(delta, {'hand': 500000});
    });

    test('turning a settlement flag off on edit undoes its credit', () {
      final delta = editDebtSettlement(
        oldAccountId: 'bank',
        oldAmountMinor: 200000,
        newAccountId: 'bank',
        newAmountMinor: 200000,
        direction: DebtDirection.given,
        oldAffectsBalance: true,
        newAffectsBalance: false,
      );
      expect(delta, {'bank': -200000});
    });
  });
}
