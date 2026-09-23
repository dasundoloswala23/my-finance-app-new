import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../dashboard/providers.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../debts/domain/debt.dart';
import '../../debts/domain/debt_settlement.dart';
import '../../debts/presentation/debt_detail_screen.dart';
import '../../debts/providers.dart';
import '../../transfers/domain/transfer.dart';
import '../../transfers/presentation/transfer_form_screen.dart';
import '../domain/txn.dart';
import 'transaction_form_screen.dart';

/// Full activity list: income, expenses and transfers merged into one
/// chronological feed, grouped by day.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _ActivityFilter { all, income, expense, transfers, debts }

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final transfersAsync = ref.watch(transfersProvider);
    final debtsAsync = ref.watch(debtsProvider);
    final settlementsAsync = ref.watch(allSettlementsProvider);
    final accounts = ref.watch(accountByIdProvider);
    final categories = ref.watch(categoryByIdProvider);
    final debtsById = ref.watch(debtByIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final filter in _ActivityFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_labelFor(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(error: error),
        data: (transactions) {
          final transfers = transfersAsync.value ?? const <Transfer>[];
          final debts = debtsAsync.value ?? const <Debt>[];
          final settlements =
              settlementsAsync.value ?? const <DebtSettlement>[];
          final entries = _buildEntries(
            transactions,
            transfers,
            debts,
            settlements,
          );

          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nothing here yet',
              message:
                  'Records you add will appear here, newest first. '
                  'Tap + to get started.',
            );
          }

          final grouped = _groupByDay(entries);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      _dayLabel(group.day),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ...group.entries.map(
                    (entry) => _rowFor(
                      context,
                      entry,
                      accounts: accounts,
                      categories: categories,
                      debtsById: debtsById,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _labelFor(_ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return 'All';
      case _ActivityFilter.income:
        return 'Income';
      case _ActivityFilter.expense:
        return 'Expense';
      case _ActivityFilter.transfers:
        return 'Transfers';
      case _ActivityFilter.debts:
        return 'Debts';
    }
  }

  /// Merges every source into one feed honouring the active filter.
  List<_Entry> _buildEntries(
    List<Txn> transactions,
    List<Transfer> transfers,
    List<Debt> debts,
    List<DebtSettlement> settlements,
  ) {
    final entries = <_Entry>[];

    if (_filter != _ActivityFilter.transfers &&
        _filter != _ActivityFilter.debts) {
      for (final txn in transactions) {
        final matches =
            _filter == _ActivityFilter.all ||
            (_filter == _ActivityFilter.income &&
                txn.type == TxnType.income) ||
            (_filter == _ActivityFilter.expense &&
                txn.type == TxnType.expense);
        if (matches) entries.add(_Entry(date: txn.date, txn: txn));
      }
    }

    if (_filter == _ActivityFilter.all ||
        _filter == _ActivityFilter.transfers) {
      for (final transfer in transfers) {
        entries.add(_Entry(date: transfer.date, transfer: transfer));
      }
    }

    if (_filter == _ActivityFilter.all || _filter == _ActivityFilter.debts) {
      for (final debt in debts) {
        entries.add(_Entry(date: debt.date, debt: debt));
      }
      for (final settlement in settlements) {
        entries.add(_Entry(date: settlement.date, settlement: settlement));
      }
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  /// Renders whichever payload the entry carries.
  Widget _rowFor(
    BuildContext context,
    _Entry entry, {
    required Map<String, Account> accounts,
    required Map<String, Category> categories,
    required Map<String, Debt> debtsById,
  }) {
    final txn = entry.txn;
    if (txn != null) {
      return TransactionTile(
        txn: txn,
        categoryName: categories[txn.categoryId]?.name,
        accountName: accounts[txn.accountId]?.name,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionFormScreen(existing: txn),
          ),
        ),
      );
    }

    final transfer = entry.transfer;
    if (transfer != null) {
      return _TransferTile(
        transfer: transfer,
        fromName: accounts[transfer.fromAccountId]?.name,
        toName: accounts[transfer.toAccountId]?.name,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TransferFormScreen(existing: transfer),
          ),
        ),
      );
    }

    final debt = entry.debt;
    if (debt != null) {
      return _DebtActivityTile(
        debt: debt,
        accountName: accounts[debt.accountId]?.name,
      );
    }

    final settlement = entry.settlement!;
    return _SettlementActivityTile(
      settlement: settlement,
      // The parent debt gives the row its direction and the person's name.
      debt: debtsById[settlement.debtId],
      accountName: accounts[settlement.accountId]?.name,
    );
  }

  List<_DayGroup> _groupByDay(List<_Entry> entries) {
    final groups = <_DayGroup>[];
    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (groups.isNotEmpty && groups.last.day == day) {
        groups.last.entries.add(entry);
      } else {
        groups.add(_DayGroup(day: day, entries: [entry]));
      }
    }
    return groups;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMMM y').format(day);
  }
}

/// One row in the merged feed. Exactly one of the payloads is non-null.
class _Entry {
  _Entry({
    required this.date,
    this.txn,
    this.transfer,
    this.debt,
    this.settlement,
  });

  final DateTime date;
  final Txn? txn;
  final Transfer? transfer;
  final Debt? debt;
  final DebtSettlement? settlement;
}

class _DayGroup {
  _DayGroup({required this.day, required this.entries});

  final DateTime day;
  final List<_Entry> entries;
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({
    required this.transfer,
    this.fromName,
    this.toName,
    this.onTap,
  });

  final Transfer transfer;
  final String? fromName;
  final String? toName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      '${fromName ?? 'Account'} → ${toName ?? 'Account'}',
      if (transfer.note.isNotEmpty) transfer.note,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: BrandColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.swap_horiz, color: BrandColors.primary),
        ),
        title: const Text('Transfer'),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        // Neutral styling: a transfer moves money without changing net worth.
        trailing: MoneyText(amountMinor: transfer.amountMinor),
      ),
    );
  }
}

/// A debt being created, shown in the activity feed.
class _DebtActivityTile extends StatelessWidget {
  const _DebtActivityTile({required this.debt, this.accountName});

  final Debt debt;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final isGiven = debt.direction == DebtDirection.given;
    // Lending money out leaves the account, so it reads like an expense;
    // borrowing arrives, so it reads like income.
    final accent = isGiven ? BrandColors.expense : BrandColors.income;

    final subtitle = [
      isGiven ? 'Lent to ${debt.personName}' : 'Borrowed from ${debt.personName}',
      ?accountName,
      if (debt.note.isNotEmpty) debt.note,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DebtDetailScreen(debtId: debt.id),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Icon(
            isGiven ? Icons.call_made : Icons.call_received,
            color: accent,
          ),
        ),
        title: Text(isGiven ? 'Money lent' : 'Money borrowed'),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${isGiven ? '-' : '+'}${Money.format(debt.principalMinor)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A repayment against a debt, shown in the activity feed.
class _SettlementActivityTile extends StatelessWidget {
  const _SettlementActivityTile({
    required this.settlement,
    this.debt,
    this.accountName,
  });

  final DebtSettlement settlement;

  /// Null only if the parent debt was deleted out from under the feed.
  final Debt? debt;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final isGiven = debt?.direction == DebtDirection.given;
    // Settling reverses the original flow: being repaid is money in.
    final accent = isGiven ? BrandColors.income : BrandColors.expense;
    final person = debt?.personName;

    final subtitle = [
      if (person != null)
        isGiven ? 'Repaid by $person' : 'Repaid to $person'
      else
        'Settlement',
      ?accountName,
      if (settlement.note.isNotEmpty) settlement.note,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: debt == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DebtDetailScreen(debtId: settlement.debtId),
                ),
              ),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Icon(Icons.check, color: accent),
        ),
        title: const Text('Debt settled'),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${isGiven ? '+' : '-'}${Money.format(settlement.amountMinor)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
