import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/balance_math.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../dashboard/providers.dart';
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

enum _ActivityFilter { all, income, expense, transfers }

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final transfersAsync = ref.watch(transfersProvider);
    final accounts = ref.watch(accountByIdProvider);
    final categories = ref.watch(categoryByIdProvider);

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
          final entries = _buildEntries(transactions, transfers);

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
                    (entry) => entry.txn != null
                        ? TransactionTile(
                            txn: entry.txn!,
                            categoryName: categories[entry.txn!.categoryId]?.name,
                            accountName: accounts[entry.txn!.accountId]?.name,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TransactionFormScreen(
                                  existing: entry.txn,
                                ),
                              ),
                            ),
                          )
                        : _TransferTile(
                            transfer: entry.transfer!,
                            fromName:
                                accounts[entry.transfer!.fromAccountId]?.name,
                            toName: accounts[entry.transfer!.toAccountId]?.name,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TransferFormScreen(
                                  existing: entry.transfer,
                                ),
                              ),
                            ),
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
    }
  }

  /// Merges the two sources into one feed honouring the active filter.
  List<_Entry> _buildEntries(List<Txn> transactions, List<Transfer> transfers) {
    final entries = <_Entry>[];

    if (_filter != _ActivityFilter.transfers) {
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

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
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

class _Entry {
  _Entry({required this.date, this.txn, this.transfer});

  final DateTime date;
  final Txn? txn;
  final Transfer? transfer;
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
