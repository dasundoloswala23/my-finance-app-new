import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/debt.dart';
import '../providers.dart';
import 'debt_detail_screen.dart';
import 'debt_form_screen.dart';

/// Debts split by direction, with settled ones kept out of the way.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final summary = ref.watch(debtSummaryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts'),
          actions: [
            IconButton(
              tooltip: 'Add debt',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DebtFormScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: "You'll receive"),
              Tab(text: "You'll pay"),
              const Tab(text: 'Settled'),
            ],
          ),
        ),
        body: debtsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(error: error),
          data: (debts) {
            final receivable = openDebtsOf(debts, DebtDirection.given);
            final payable = openDebtsOf(debts, DebtDirection.taken);
            final settled = settledDebtsOf(debts);

            return TabBarView(
              children: [
                _DebtList(
                  debts: receivable,
                  totalMinor: summary.receivable,
                  totalLabel: 'Owed to you',
                  emptyTitle: 'Nobody owes you',
                  emptyMessage:
                      'When you lend money, record it here so you do not '
                      'lose track of it.',
                ),
                _DebtList(
                  debts: payable,
                  totalMinor: summary.payable,
                  totalLabel: 'You owe',
                  emptyTitle: 'You owe nothing',
                  emptyMessage:
                      'Money you borrow will show here until you have paid '
                      'it back.',
                ),
                _DebtList(
                  debts: settled,
                  emptyTitle: 'Nothing settled yet',
                  emptyMessage:
                      'Debts move here once they have been paid off in full.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DebtList extends StatelessWidget {
  const _DebtList({
    required this.debts,
    required this.emptyTitle,
    required this.emptyMessage,
    this.totalMinor,
    this.totalLabel,
  });

  final List<Debt> debts;
  final String emptyTitle;
  final String emptyMessage;
  final int? totalMinor;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_outlined,
        title: emptyTitle,
        message: emptyMessage,
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DebtFormScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add debt'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        if (totalMinor != null && totalLabel != null) ...[
          Card(
            child: ListTile(
              title: Text(totalLabel!),
              subtitle: Text('${debts.length} open'),
              trailing: Text(
                Money.format(totalMinor!),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...debts.map((debt) => _DebtTile(debt: debt)),
      ],
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGiven = debt.direction == DebtDirection.given;
    final accent = isGiven ? BrandColors.income : BrandColors.expense;
    final overdue = debt.isOverdue(DateTime.now());

    final subtitle = [
      if (debt.isSettled)
        'Settled'
      else
        '${Money.format(debt.settledMinor)} of '
            '${Money.format(debt.principalMinor)}',
      if (debt.dueDate != null)
        'Due ${DateFormat('d MMM y').format(debt.dueDate!)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DebtDetailScreen(debtId: debt.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.12),
                    child: Icon(
                      isGiven ? Icons.call_made : Icons.call_received,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.personName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: overdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: overdue ? FontWeight.w600 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Money.format(
                      debt.isSettled
                          ? debt.principalMinor
                          : debt.outstandingMinor,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: debt.isSettled
                          ? theme.colorScheme.onSurfaceVariant
                          : accent,
                    ),
                  ),
                ],
              ),
              if (debt.isPartlySettled) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: debt.progress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
