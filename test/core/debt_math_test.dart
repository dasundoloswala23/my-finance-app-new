import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/balance_math.dart';

void main() {
  group('applyDebt', () {
    test('lending money out reduces the account', () {
      expect(
        applyDebt(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 500000,
        ),
        {'hand': -500000},
      );
    });

    test('borrowing money increases the account', () {
      expect(
        applyDebt(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: 400000,
        ),
        {'bank': 400000},
      );
    });

    test('the two directions are exact opposites', () {
      final given = applyDebt(
        accountId: 'a',
        direction: DebtDirection.given,
        amountMinor: 1234,
      );
      final taken = applyDebt(
        accountId: 'a',
        direction: DebtDirection.taken,
        amountMinor: 1234,
      );
      expect(mergeDeltas([given, taken]), isEmpty);
    });
  });

  group('reverseDebt', () {
    test('cancels out applyDebt for both directions', () {
      for (final direction in DebtDirection.values) {
        final applied = applyDebt(
          accountId: 'a',
          direction: direction,
          amountMinor: 9999,
        );
        final reversed = reverseDebt(
          accountId: 'a',
          direction: direction,
          amountMinor: 9999,
        );
        expect(mergeDeltas([applied, reversed]), isEmpty);
      }
    });
  });

  group('applyDebtSettlement', () {
    test('being repaid on money you lent increases the account', () {
      expect(
        applyDebtSettlement(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 200000,
        ),
        {'hand': 200000},
      );
    });

    test('repaying money you borrowed decreases the account', () {
      expect(
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: 200000,
        ),
        {'bank': -200000},
      );
    });
  });

  group('the core invariant', () {
    test('lend then fully settle returns the account to where it started', () {
      const amount = 500000;
      final net = mergeDeltas([
        applyDebt(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: amount,
        ),
        applyDebtSettlement(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: amount,
        ),
      ]);
      expect(net, isEmpty);
    });

    test('borrow then fully settle returns the account to where it started', () {
      const amount = 400000;
      final net = mergeDeltas([
        applyDebt(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: amount,
        ),
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.taken,
          amountMinor: amount,
        ),
      ]);
      expect(net, isEmpty);
    });

    test('settling in instalments nets out the same as settling at once', () {
      const amount = 500000;
      final inParts = mergeDeltas([
        applyDebt(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: amount,
        ),
        applyDebtSettlement(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 200000,
        ),
        applyDebtSettlement(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 300000,
        ),
      ]);
      expect(inParts, isEmpty);
    });

    test('a partial settlement leaves exactly the outstanding shortfall', () {
      final net = mergeDeltas([
        applyDebt(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 500000,
        ),
        applyDebtSettlement(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 200000,
        ),
      ]);
      // 300000 is still out with the borrower.
      expect(net, {'hand': -300000});
    });

    test('settling into a different account still nets to zero overall', () {
      // Lent from hand, repaid into the bank: hand stays down, bank goes up.
      final net = mergeDeltas([
        applyDebt(
          accountId: 'hand',
          direction: DebtDirection.given,
          amountMinor: 500000,
        ),
        applyDebtSettlement(
          accountId: 'bank',
          direction: DebtDirection.given,
          amountMinor: 500000,
        ),
      ]);
      expect(net, {'hand': -500000, 'bank': 500000});
      expect(net.values.reduce((a, b) => a + b), 0);
    });
  });

  group('editDebt', () {
    test('raising the amount lent takes the difference out again', () {
      final delta = editDebt(
        oldAccountId: 'hand',
        oldDirection: DebtDirection.given,
        oldAmountMinor: 500000,
        newAccountId: 'hand',
        newDirection: DebtDirection.given,
        newAmountMinor: 600000,
      );
      expect(delta, {'hand': -100000});
    });

    test('flipping lent to borrowed doubles the swing', () {
      final delta = editDebt(
        oldAccountId: 'hand',
        oldDirection: DebtDirection.given,
        oldAmountMinor: 500000,
        newAccountId: 'hand',
        newDirection: DebtDirection.taken,
        newAmountMinor: 500000,
      );
      // Undo -500000, then apply +500000.
      expect(delta, {'hand': 1000000});
    });

    test('moving to another account restores the old one', () {
      final delta = editDebt(
        oldAccountId: 'hand',
        oldDirection: DebtDirection.given,
        oldAmountMinor: 500000,
        newAccountId: 'bank',
        newDirection: DebtDirection.given,
        newAmountMinor: 500000,
      );
      expect(delta, {'hand': 500000, 'bank': -500000});
    });

    test('an unchanged edit produces no writes', () {
      final delta = editDebt(
        oldAccountId: 'hand',
        oldDirection: DebtDirection.taken,
        oldAmountMinor: 250000,
        newAccountId: 'hand',
        newDirection: DebtDirection.taken,
        newAmountMinor: 250000,
      );
      expect(delta, isEmpty);
    });
  });

  group('editDebtSettlement', () {
    test('raising a repayment credits the difference', () {
      final delta = editDebtSettlement(
        oldAccountId: 'hand',
        oldAmountMinor: 200000,
        newAccountId: 'hand',
        newAmountMinor: 300000,
        direction: DebtDirection.given,
      );
      expect(delta, {'hand': 100000});
    });

    test('changing the receiving account moves the whole amount', () {
      final delta = editDebtSettlement(
        oldAccountId: 'hand',
        oldAmountMinor: 200000,
        newAccountId: 'bank',
        newAmountMinor: 200000,
        direction: DebtDirection.given,
      );
      expect(delta, {'hand': -200000, 'bank': 200000});
    });

    test('reverseDebtSettlement cancels the settlement', () {
      for (final direction in DebtDirection.values) {
        final applied = applyDebtSettlement(
          accountId: 'a',
          direction: direction,
          amountMinor: 777,
        );
        final reversed = reverseDebtSettlement(
          accountId: 'a',
          direction: direction,
          amountMinor: 777,
        );
        expect(mergeDeltas([applied, reversed]), isEmpty);
      }
    });
  });
}
