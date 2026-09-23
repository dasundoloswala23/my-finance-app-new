import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../services/app_update_service.dart';
import '../../accounts/domain/account.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../debts/providers.dart';
import '../../transactions/domain/txn.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transfers/presentation/transfer_form_screen.dart';
import '../providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Silent Play Store update check, after the first frame so it never
    // competes with the initial build. No-ops off Android and on non-Play builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final displayName =
        ref.watch(authStateProvider).value?.displayName ?? 'there';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, $displayName', style: theme.textTheme.titleMedium),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(error: error),
        data: (accounts) => RefreshIndicator(
          // Firestore streams are already live; this is here so the familiar
          // pull-to-refresh gesture does not feel broken.
          onRefresh: () async => ref.invalidate(accountsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _TotalMoneyCard(),
              const SizedBox(height: 16),
              const _MonthSummaryRow(),
              const SizedBox(height: 16),
              const _DebtSummaryRow(),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Accounts',
                trailing: '${accounts.length}',
              ),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                const _InlineHint(
                  text: 'No accounts yet. Add one from the Accounts tab.',
                )
              else
                ...accounts.map((account) => _AccountTile(account: account)),
              const SizedBox(height: 24),
              const _QuickActions(),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Recent activity'),
              const SizedBox(height: 8),
              const _RecentTransactions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalMoneyCard extends ConsumerWidget {
  const _TotalMoneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalMoneyProvider);
    final hand = ref.watch(handMoneyProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.primary, BrandColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Money',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            Money.format(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.pan_tool_alt, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Hand Money',
                style: TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                Money.format(hand),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryRow extends ConsumerWidget {
  const _MonthSummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider);

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Income this month',
            amountMinor: summary.income,
            type: TxnType.income,
            icon: Icons.south_west,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Spent this month',
            amountMinor: summary.expense,
            type: TxnType.expense,
            icon: Icons.north_east,
          ),
        ),
      ],
    );
  }
}

/// Outstanding debts, kept deliberately separate from Total Money: that figure
/// means cash actually held, and folding debts into it would hide how much is
/// genuinely spendable today.
class _DebtSummaryRow extends ConsumerWidget {
  const _DebtSummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(debtSummaryProvider);

    // Nothing owed either way — don't take up space on the dashboard.
    if (summary.receivable == 0 && summary.payable == 0) {
      return const SizedBox.shrink();
    }

    void openDebts() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebtsScreen()),
    );

    return Row(
      children: [
        Expanded(
          child: _DebtTile(
            label: "You'll receive",
            amountMinor: summary.receivable,
            icon: Icons.call_made,
            color: BrandColors.income,
            onTap: openDebts,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DebtTile(
            label: "You'll pay",
            amountMinor: summary.payable,
            icon: Icons.call_received,
            color: BrandColors.expense,
            onTap: openDebts,
          ),
        ),
      ],
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.label,
    required this.amountMinor,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int amountMinor;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Money.format(amountMinor),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amountMinor,
    required this.type,
    required this.icon,
  });

  final String label;
  final int amountMinor;
  final TxnType type;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = type == TxnType.income
        ? BrandColors.income
        : BrandColors.expense;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoneyText(
              amountMinor: amountMinor,
              type: type,
              showSign: false,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(iconForAccountType(account.type))),
        title: Text(account.name),
        subtitle: Text(labelForAccountType(account.type)),
        trailing: MoneyText(amountMinor: account.balanceMinor),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.south_west,
            label: 'Income',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const TransactionFormScreen(initialType: TxnType.income),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.north_east,
            label: 'Expense',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const TransactionFormScreen(initialType: TxnType.expense),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.swap_horiz,
            label: 'Transfer',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransferFormScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentTransactionsProvider);
    final categories = ref.watch(categoryByIdProvider);
    final accounts = ref.watch(accountByIdProvider);

    return recentAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => ErrorState(error: error),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const _InlineHint(
            text: 'Nothing recorded yet. Tap + to add your first entry.',
          );
        }
        return Column(
          children: transactions
              .map(
                (txn) => TransactionTile(
                  txn: txn,
                  categoryName: categories[txn.categoryId]?.name,
                  accountName: accounts[txn.accountId]?.name,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

/// Row used on the dashboard and in the full activity list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.txn,
    this.categoryName,
    this.accountName,
    this.onTap,
  });

  final Txn txn;
  final String? categoryName;
  final String? accountName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == TxnType.income;
    final subtitle = [
      accountName,
      DateFormat('d MMM y').format(txn.date),
      if (txn.note.isNotEmpty) txn.note,
    ].whereType<String>().join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              (isIncome ? BrandColors.income : BrandColors.expense)
                  .withValues(alpha: 0.12),
          child: Icon(
            isIncome ? Icons.south_west : Icons.north_east,
            color: isIncome ? BrandColors.income : BrandColors.expense,
          ),
        ),
        title: Text(categoryName ?? (isIncome ? 'Income' : 'Expense')),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(amountMinor: txn.amountMinor, type: txn.type),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

IconData iconForAccountType(AccountType type) {
  switch (type) {
    case AccountType.bank:
      return Icons.account_balance;
    case AccountType.cash:
      return Icons.payments;
    case AccountType.wallet:
      return Icons.account_balance_wallet;
    case AccountType.hand:
      return Icons.pan_tool_alt;
  }
}

String labelForAccountType(AccountType type) {
  switch (type) {
    case AccountType.bank:
      return 'Bank account';
    case AccountType.cash:
      return 'Cash';
    case AccountType.wallet:
      return 'Wallet';
    case AccountType.hand:
      return 'Cash in hand';
  }
}
