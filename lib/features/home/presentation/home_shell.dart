import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/balance_math.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../debts/presentation/debt_form_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../transactions/presentation/transaction_form_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../transfers/presentation/transfer_form_screen.dart';

/// Bottom-navigation shell holding the four main destinations.
///
/// Uses an [IndexedStack] so each tab keeps its scroll position and its
/// Firestore stream subscriptions while the user moves between tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Activity',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Accounts',
    ),
    NavigationDestination(
      icon: Icon(Icons.handshake_outlined),
      selectedIcon: Icon(Icons.handshake),
      label: 'Debts',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.south_west)),
              title: const Text('Add income'),
              subtitle: const Text('Money coming in'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openTransactionForm(TxnType.income);
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.north_east)),
              title: const Text('Add expense'),
              subtitle: const Text('Money going out'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openTransactionForm(TxnType.expense);
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
              title: const Text('Transfer'),
              subtitle: const Text('Move money between your accounts'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TransferFormScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.call_made)),
              title: const Text('Lend money'),
              subtitle: const Text('Someone will owe you'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDebtForm(DebtDirection.given);
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.call_received)),
              title: const Text('Borrow money'),
              subtitle: const Text('You will owe someone'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openDebtForm(DebtDirection.taken);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDebtForm(DebtDirection direction) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebtFormScreen(initialDirection: direction),
      ),
    );
  }

  void _openTransactionForm(TxnType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionFormScreen(initialType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TransactionsScreen(),
          AccountsScreen(),
          DebtsScreen(),
          SettingsScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        tooltip: 'Add a record',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: _destinations,
      ),
    );
  }
}
