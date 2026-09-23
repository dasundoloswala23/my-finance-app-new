import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../dashboard/providers.dart';
import '../domain/debt.dart';
import '../domain/debt_settlement.dart';
import '../providers.dart';
import 'debt_form_screen.dart';
import 'settlement_form_screen.dart';

/// One debt: how much is left, and every repayment against it.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from the live list rather than holding a snapshot, so the screen
    // updates the moment a settlement lands.
    final debt = ref.watch(debtByIdProvider)[debtId];
    if (debt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Debt not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final settlementsAsync = ref.watch(settlementsForDebtProvider(debtId));
    final accounts = ref.watch(accountByIdProvider);
    final isGiven = debt.direction == DebtDirection.given;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.personName),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DebtFormScreen(existing: debt),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, debt),
          ),
        ],
      ),
      floatingActionButton: debt.isSettled
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettlementFormScreen(debt: debt),
                ),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Settle'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _SummaryCard(debt: debt, accountName: accounts[debt.accountId]?.name),
          const SizedBox(height: 24),
          Text(
            'Settlements',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          settlementsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => ErrorState(error: error),
            data: (settlements) {
              if (settlements.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    isGiven
                        ? 'Nothing repaid yet.'
                        : 'You have not repaid any of this yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: settlements
                    .map(
                      (settlement) => _SettlementTile(
                        debt: debt,
                        settlement: settlement,
                        accountName: accounts[settlement.accountId]?.name,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete this debt?'),
        content: Text(
          debt.settledMinor > 0
              ? 'Its settlements will be deleted too, and every affected '
                    'account balance will be restored.'
              : 'The account balance will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtRepositoryProvider)?.delete(debt);
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.debt, this.accountName});

  final Debt debt;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGiven = debt.direction == DebtDirection.given;
    final accent = isGiven ? BrandColors.income : BrandColors.expense;
    final overdue = debt.isOverdue(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGiven ? Icons.call_made : Icons.call_received,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isGiven ? 'They owe you' : 'You owe',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (debt.isSettled)
                  Chip(
                    label: const Text('Settled'),
                    avatar: const Icon(Icons.check, size: 16),
                    visualDensity: VisualDensity.compact,
                  )
                else if (overdue)
                  Chip(
                    label: const Text('Overdue'),
                    backgroundColor: theme.colorScheme.errorContainer,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Money.format(debt.outstandingMinor),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: debt.isSettled ? theme.colorScheme.onSurface : accent,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: debt.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              '${Money.format(debt.settledMinor)} settled '
              'of ${Money.format(debt.principalMinor)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Started',
              value: DateFormat('d MMMM y').format(debt.date),
            ),
            if (debt.dueDate != null)
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Due',
                value: DateFormat('d MMMM y').format(debt.dueDate!),
                emphasised: overdue,
              ),
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              label: isGiven ? 'Paid from' : 'Received into',
              value: accountName ?? 'Unknown account',
            ),
            if (debt.note.isNotEmpty)
              _DetailRow(
                icon: Icons.notes,
                label: 'Note',
                value: debt.note,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: emphasised ? theme.colorScheme.error : null,
                fontWeight: emphasised ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementTile extends ConsumerWidget {
  const _SettlementTile({
    required this.debt,
    required this.settlement,
    this.accountName,
  });

  final Debt debt;
  final DebtSettlement settlement;
  final String? accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      DateFormat('d MMM y').format(settlement.date),
      ?accountName,
      if (settlement.note.isNotEmpty) settlement.note,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: BrandColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.check, color: BrandColors.primary),
        ),
        title: Text(Money.format(settlement.amountMinor)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettlementFormScreen(
                    debt: debt,
                    existing: settlement,
                  ),
                ),
              );
            } else if (value == 'delete') {
              await _confirmDelete(context, ref);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this settlement?'),
        content: const Text(
          'The amount will be added back to what is outstanding, and the '
          'account balance will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtRepositoryProvider)?.deleteSettlement(debt, settlement);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
