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
}
