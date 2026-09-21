import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/balance_math.dart';
import '../../core/providers.dart';
import '../accounts/domain/account.dart';
import '../categories/domain/category.dart';
import '../transactions/domain/txn.dart';
import '../transfers/domain/transfer.dart';

/// Live account list. Empty while signed out.
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchAccounts();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchCategories();
});

/// All transactions, newest first.
final transactionsProvider = StreamProvider<List<Txn>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTransactions();
});

/// Short list for the dashboard.
final recentTransactionsProvider = StreamProvider<List<Txn>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTransactions(limit: 5);
});

final transfersProvider = StreamProvider<List<Transfer>>((ref) {
  final repository = ref.watch(transferRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchTransfers();
});

/// Transactions in the current calendar month, for the income/expense summary.
final monthTransactionsProvider = StreamProvider<List<Txn>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  if (repository == null) return Stream.value(const []);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month);
  final end = DateTime(now.year, now.month + 1);
  return repository.watchRange(start, end);
});

/// Sum of every non-archived account balance — the headline "Total Money".
int totalMoneyOf(List<Account> accounts) {
  return accounts.fold(0, (sum, account) => sum + account.balanceMinor);
}

/// Balance of the Hand Money account, or 0 if it has not been seeded yet.
int handMoneyOf(List<Account> accounts) {
  for (final account in accounts) {
    if (account.isHandMoney) return account.balanceMinor;
  }
  return 0;
}

/// Total of a single direction over a list of transactions.
int sumByType(List<Txn> transactions, TxnType type) {
  return transactions
      .where((txn) => txn.type == type)
      .fold(0, (sum, txn) => sum + txn.amountMinor);
}

final totalMoneyProvider = Provider<int>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  return totalMoneyOf(accounts);
});

final handMoneyProvider = Provider<int>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  return handMoneyOf(accounts);
});

/// ({income, expense}) totals for the current month.
final monthSummaryProvider = Provider<({int income, int expense})>((ref) {
  final transactions =
      ref.watch(monthTransactionsProvider).value ?? const [];
  return (
    income: sumByType(transactions, TxnType.income),
    expense: sumByType(transactions, TxnType.expense),
  );
});

/// Category lookup by id, so transaction rows can resolve names without
/// re-querying per row.
final categoryByIdProvider = Provider<Map<String, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return {for (final category in categories) category.id: category};
});

/// Account lookup by id, used the same way.
final accountByIdProvider = Provider<Map<String, Account>>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  return {for (final account in accounts) account.id: account};
});
