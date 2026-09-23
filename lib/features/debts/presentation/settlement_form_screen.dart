import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../dashboard/providers.dart';
import '../domain/debt.dart';
import '../domain/debt_settlement.dart';

/// Record or edit a repayment against a debt.
///
/// The amount defaults to the full outstanding balance, since settling in full
/// is the common case.
class SettlementFormScreen extends ConsumerStatefulWidget {
  const SettlementFormScreen({
    super.key,
    required this.debt,
    this.existing,
  });

  final Debt debt;
  final DebtSettlement? existing;

  @override
  ConsumerState<SettlementFormScreen> createState() =>
      _SettlementFormScreenState();
}

class _SettlementFormScreenState extends ConsumerState<SettlementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DateTime _date;
  String? _accountId;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  /// What may still be settled: the outstanding amount, plus this settlement's
  /// own contribution when editing, since that is about to be replaced.
  int get _maxAmountMinor {
    final existing = widget.existing;
    if (existing == null) return widget.debt.outstandingMinor;
    return widget.debt.outstandingMinor + existing.amountMinor;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _date = existing?.date ?? DateTime.now();
    _accountId = existing?.accountId ?? widget.debt.accountId;
    _amountController = TextEditingController(
      text: Money.toEditingValue(existing?.amountMinor ?? _maxAmountMinor),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      setState(() => _errorMessage = 'Choose an account.');
      return;
    }

    final amountMinor = Money.tryParse(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorMessage = 'Enter an amount greater than zero.');
      return;
    }

    final repository = ref.read(debtRepositoryProvider);
    if (repository == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    try {
      if (_isEditing) {
        await repository.updateSettlement(
          widget.debt,
          widget.existing!,
          amountMinor: amountMinor,
          accountId: _accountId!,
          date: _date,
          note: _noteController.text.trim(),
        );
      } else {
        await repository.addSettlement(
          widget.debt,
          amountMinor: amountMinor,
          accountId: _accountId!,
          date: _date,
          note: _noteController.text.trim(),
        );
      }
      if (mounted) navigator.pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = error is ArgumentError
              ? '${error.message}'
              : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final isGiven = widget.debt.direction == DebtDirection.given;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit settlement' : 'Record settlement'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.debt.personName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isGiven
                            ? 'Owes you ${Money.format(_maxAmountMinor)}'
                            : 'You owe ${Money.format(_maxAmountMinor)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  final parsed = Money.tryParse(value ?? '');
                  if (parsed == null) return 'Enter a valid amount.';
                  if (parsed <= 0) return 'Amount must be greater than zero.';
                  if (parsed > _maxAmountMinor) {
                    return 'That is more than the ${Money.format(_maxAmountMinor)} '
                        'still outstanding.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: isGiven ? 'Received into' : 'Paid from',
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) =>
                    value == null ? 'Choose an account.' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(DateFormat('d MMMM y').format(_date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Record settlement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
