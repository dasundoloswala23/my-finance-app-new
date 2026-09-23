import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/balance_math.dart';
import '../../core/providers.dart';
import 'domain/debt.dart';
import 'domain/debt_settlement.dart';

/// Live debt list. Empty while signed out.
final debtsProvider = StreamProvider<List<Debt>>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchDebts();
});

/// Every settlement, for the activity feed.
final allSettlementsProvider = StreamProvider<List<DebtSettlement>>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  if (repository == null) return Stream.value(const []);
  return repository.watchAllSettlements();
});

/// Settlements for a single debt.
final settlementsForDebtProvider =
    StreamProvider.family<List<DebtSettlement>, String>((ref, debtId) {
      final repository = ref.watch(debtRepositoryProvider);
      if (repository == null) return Stream.value(const []);
      return repository.watchSettlementsFor(debtId);
    });

/// Total still owed *to* the user across open lent-out debts.
int receivableOf(List<Debt> debts) {
  return debts
      .where((debt) => debt.isReceivable && !debt.isSettled)
      .fold(0, (sum, debt) => sum + debt.outstandingMinor);
}

/// Total the user still owes across open borrowed debts.
int payableOf(List<Debt> debts) {
  return debts
      .where((debt) => !debt.isReceivable && !debt.isSettled)
      .fold(0, (sum, debt) => sum + debt.outstandingMinor);
}

/// Open debts of one direction, soonest due first, then newest.
List<Debt> openDebtsOf(List<Debt> debts, DebtDirection direction) {
  final open =
      debts
          .where((debt) => debt.direction == direction && !debt.isSettled)
          .toList()
        ..sort((a, b) {
          final aDue = a.dueDate;
          final bDue = b.dueDate;
          if (aDue != null && bDue != null) return aDue.compareTo(bDue);
          // Debts with a due date surface above open-ended ones.
          if (aDue != null) return -1;
          if (bDue != null) return 1;
          return b.date.compareTo(a.date);
        });
  return open;
}

/// Closed debts, most recently dated first.
List<Debt> settledDebtsOf(List<Debt> debts) {
  final settled = debts.where((debt) => debt.isSettled).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return settled;
}

/// Outstanding totals for the dashboard card.
final debtSummaryProvider = Provider<({int receivable, int payable})>((ref) {
  final debts = ref.watch(debtsProvider).value ?? const [];
  return (receivable: receivableOf(debts), payable: payableOf(debts));
});

/// Debt lookup by id, so settlement rows can resolve a person's name without
/// re-querying per row.
final debtByIdProvider = Provider<Map<String, Debt>>((ref) {
  final debts = ref.watch(debtsProvider).value ?? const [];
  return {for (final debt in debts) debt.id: debt};
});
