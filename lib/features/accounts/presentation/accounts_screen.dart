import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../dashboard/providers.dart';
import '../domain/account.dart';
import 'account_form_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final total = ref.watch(totalMoneyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountFormScreen(),
              ),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(error: error),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message:
                  'Add a bank account, wallet or cash account to start '
                  'tracking your money.',
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountFormScreen(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add account'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Total Money'),
                  subtitle: Text('${accounts.length} accounts'),
                  trailing: Text(
                    Money.format(total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...accounts.map(
                (account) => _AccountCard(account: account),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(iconForAccountType(account.type))),
        title: Text(account.name),
        subtitle: Text(labelForAccountType(account.type)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(amountMinor: account.balanceMinor),
            PopupMenuButton<String>(
              onSelected: (value) => _onAction(context, ref, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(account.isArchived ? 'Unarchive' : 'Archive'),
                ),
                // Hand Money is structural — deleting it would orphan every
                // cash transfer, so the option is simply not offered.
                if (!account.isHandMoney)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountFormScreen(existing: account),
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repository = ref.read(accountRepositoryProvider);
    if (repository == null) return;

    switch (action) {
      case 'edit':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AccountFormScreen(existing: account),
          ),
        );
      case 'archive':
        await repository.setArchived(account.id, !account.isArchived);
      case 'delete':
        await _confirmDelete(context, repository);
    }
  }

  Future<void> _confirmDelete(BuildContext context, dynamic repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: const Text(
          'Records already linked to this account are kept, but they will no '
          'longer show an account name. Consider archiving instead.',
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
    if (confirmed == true) await repository.delete(account.id);
  }
}
