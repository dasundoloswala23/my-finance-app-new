import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/balance_math.dart';
import 'package:myfinance/features/accounts/domain/account.dart';
import 'package:myfinance/features/dashboard/providers.dart';
import 'package:myfinance/features/transactions/domain/txn.dart';

Account _account(String id, AccountType type, int balanceMinor) {
  return Account(
    id: id,
    name: id,
    type: type,
    balanceMinor: balanceMinor,
  );
}

Txn _txn(TxnType type, int amountMinor) {
  return Txn(
    id: 't',
    type: type,
    amountMinor: amountMinor,
    accountId: 'a',
    date: DateTime(2026, 1, 1),
  );
}

void main() {
  group('totalMoneyOf', () {
    test('sums every account including Hand Money', () {
      final accounts = [
        _account('bank', AccountType.bank, 100000),
        _account('wallet', AccountType.wallet, 2550),
        _account('hand', AccountType.hand, 5000),
      ];
      expect(totalMoneyOf(accounts), 107550);
    });

    test('handles negative balances (an overdrawn account)', () {
      final accounts = [
        _account('bank', AccountType.bank, 10000),
        _account('card', AccountType.bank, -3000),
      ];
      expect(totalMoneyOf(accounts), 7000);
    });

    test('is zero with no accounts', () {
      expect(totalMoneyOf(const []), 0);
    });
  });

  group('handMoneyOf', () {
    test('returns the balance of the hand account', () {
      final accounts = [
        _account('bank', AccountType.bank, 100000),
        _account('hand', AccountType.hand, 7525),
      ];
      expect(handMoneyOf(accounts), 7525);
    });

    test('returns zero when Hand Money has not been seeded', () {
      final accounts = [_account('bank', AccountType.bank, 100000)];
      expect(handMoneyOf(accounts), 0);
    });
  });

  group('sumByType', () {
    test('totals only the requested direction', () {
      final transactions = [
        _txn(TxnType.income, 5000),
        _txn(TxnType.income, 2500),
        _txn(TxnType.expense, 1000),
      ];
      expect(sumByType(transactions, TxnType.income), 7500);
      expect(sumByType(transactions, TxnType.expense), 1000);
    });

    test('is zero for an empty list', () {
      expect(sumByType(const [], TxnType.income), 0);
    });
  });

  group('Txn.signedAmountMinor', () {
    test('income is positive and expense is negative', () {
      expect(_txn(TxnType.income, 500).signedAmountMinor, 500);
      expect(_txn(TxnType.expense, 500).signedAmountMinor, -500);
    });
  });
}
