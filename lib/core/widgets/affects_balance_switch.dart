import 'package:flutter/material.dart';

import '../money.dart';

/// Toggle deciding whether a record moves money in or out of the chosen
/// account.
///
/// Switched off, the entry is still saved and still shows in lists and totals
/// of what is owed — it simply leaves every account balance alone. That covers
/// money that moved outside the tracked accounts, or a debt that predates the
/// app and whose cash was never recorded here.
///
/// The subtitle spells out the exact effect, including the amount when one has
/// been entered, so the consequence is visible before saving rather than a
/// surprise in the balance afterwards.
class AffectsBalanceSwitch extends StatelessWidget {
  const AffectsBalanceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accountName,
    required this.increases,
    this.amountMinor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Name of the selected account, for a concrete message.
  final String? accountName;

  /// Whether turning this on would raise the balance rather than lower it.
  final bool increases;

  /// Current amount, when the form has a valid one.
  final int? amountMinor;

  String _describe() {
    if (!value) {
      return 'Saved as a record only. No account balance changes.';
    }

    final account = accountName ?? 'the account';
    final direction = increases ? 'Adds' : 'Takes';
    final preposition = increases ? 'to' : 'from';

    if (amountMinor == null || amountMinor! <= 0) {
      return '$direction this amount $preposition $account.';
    }
    return '$direction ${Money.format(amountMinor!)} $preposition $account.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: value
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: const Text('Update account balance'),
        subtitle: Text(_describe()),
        secondary: Icon(
          value ? Icons.account_balance_wallet : Icons.visibility_outlined,
          color: value
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
