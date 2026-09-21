import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../dashboard/providers.dart';
import '../domain/transfer.dart';

/// Move money between two of the user's own accounts.
///
/// Because Hand Money is just another account, "withdrew cash from the bank"
/// is an ordinary transfer rather than a special flow.
class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key, this.existing});

  final Transfer? existing;

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late DateTime _date;
  String? _fromAccountId;
  String? _toAccountId;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _date = existing?.date ?? DateTime.now();
    _fromAccountId = existing?.fromAccountId;
    _toAccountId = existing?.toAccountId;
    _amountController = TextEditingController(
      text: existing == null ? '' : Money.toEditingValue(existing.amountMinor),
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

    if (_fromAccountId == null || _toAccountId == null) {
      setState(() => _errorMessage = 'Choose both accounts.');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      setState(() => _errorMessage = 'Choose two different accounts.');
      return;
    }

    final amountMinor = Money.tryParse(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) {
      setState(() => _errorMessage = 'Enter an amount greater than zero.');
      return;
    }

    final repository = ref.read(transferRepositoryProvider);
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
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          amountMinor: amountMinor,
          date: _date,
          note: _noteController.text.trim(),
        );
      } else {
        await repository.create(
          fromAccountId: _fromAccountId!,
          toAccountId: _toAccountId!,
          amountMinor: amountMinor,
          date: _date,
          note: _noteController.text.trim(),
        );
      }
      if (mounted) navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _swapAccounts() {
    setState(() {
      final from = _fromAccountId;
      _fromAccountId = _toAccountId;
      _toAccountId = from;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transfer' : 'New transfer'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSubmitting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (accounts.length < 2)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'You need at least two accounts to make a transfer.',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: !_isEditing,
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
                initialValue: _fromAccountId,
                decoration: const InputDecoration(
                  labelText: 'From',
                  prefixIcon: Icon(Icons.logout),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _fromAccountId = value),
                validator: (value) =>
                    value == null ? 'Choose the source account.' : null,
              ),
              Center(
                child: IconButton(
                  tooltip: 'Swap accounts',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _swapAccounts,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(
                  labelText: 'To',
                  prefixIcon: Icon(Icons.login),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _toAccountId = value),
                validator: (value) {
                  if (value == null) return 'Choose the destination account.';
                  if (value == _fromAccountId) {
                    return 'Pick a different account.';
                  }
                  return null;
                },
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
                onPressed: _isSubmitting || accounts.length < 2
                    ? null
                    : _submit,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transfer?'),
        content: const Text('Both account balances will be restored.'),
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
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref.read(transferRepositoryProvider)?.delete(widget.existing!);
      if (mounted) navigator.pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = '$error';
          _isSubmitting = false;
        });
      }
    }
  }
}
