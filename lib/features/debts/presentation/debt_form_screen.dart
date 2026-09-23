import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../dashboard/providers.dart';
import '../domain/debt.dart';

/// Add or edit a debt.
///
/// Passing [existing] switches to edit mode; the repository then reverses the
/// old balance effect and applies the new one atomically.
class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({
    super.key,
    this.initialDirection = DebtDirection.given,
    this.existing,
  });

  final DebtDirection initialDirection;
  final Debt? existing;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _personController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DebtDirection _direction;
  late DateTime _date;
  DateTime? _dueDate;
  String? _accountId;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _direction = existing?.direction ?? widget.initialDirection;
    _date = existing?.date ?? DateTime.now();
    _dueDate = existing?.dueDate;
    _accountId = existing?.accountId;
    _personController = TextEditingController(text: existing?.personName ?? '');
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : Money.toEditingValue(existing.principalMinor),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final initial = isDueDate ? (_dueDate ?? _date) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (isDueDate) {
        _dueDate = picked;
      } else {
        _date = picked;
      }
    });
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
        await repository.update(
          widget.existing!,
          personName: _personController.text.trim(),
          direction: _direction,
          principalMinor: amountMinor,
          accountId: _accountId!,
          date: _date,
          dueDate: _dueDate,
          note: _noteController.text.trim(),
        );
      } else {
        await repository.create(
          personName: _personController.text.trim(),
          direction: _direction,
          principalMinor: amountMinor,
          accountId: _accountId!,
          date: _date,
          dueDate: _dueDate,
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

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }

    final isGiven = _direction == DebtDirection.given;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit debt' : 'New debt'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<DebtDirection>(
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.given,
                    icon: Icon(Icons.call_made),
                    label: Text('I lent'),
                  ),
                  ButtonSegment(
                    value: DebtDirection.taken,
                    icon: Icon(Icons.call_received),
                    label: Text('I borrowed'),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (selection) =>
                    setState(() => _direction = selection.first),
              ),
              const SizedBox(height: 8),
              Text(
                isGiven
                    ? 'Money leaves the account now, and they owe it back.'
                    : 'Money arrives in the account now, and you owe it back.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _personController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: isGiven ? 'Who borrowed from you?' : 'Who lent to you?',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a name.' : null,
              ),
              const SizedBox(height: 16),
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
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: isGiven ? 'Paid from' : 'Received into',
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
              _DateTile(
                label: 'Date',
                value: DateFormat('d MMMM y').format(_date),
                onTap: () => _pickDate(isDueDate: false),
              ),
              const SizedBox(height: 12),
              _DateTile(
                label: 'Due date (optional)',
                value: _dueDate == null
                    ? 'Not set'
                    : DateFormat('d MMMM y').format(_dueDate!),
                onTap: () => _pickDate(isDueDate: true),
                onClear: _dueDate == null
                    ? null
                    : () => setState(() => _dueDate = null),
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
                    : Text(_isEditing ? 'Save changes' : 'Add debt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.4,
      ),
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(label),
      subtitle: Text(value),
      trailing: onClear == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}
