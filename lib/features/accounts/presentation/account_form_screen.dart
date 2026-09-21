import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/account.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;

  late AccountType _type;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _openingBalanceController = TextEditingController(text: '0.00');
    _type = widget.existing?.type ?? AccountType.bank;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(accountRepositoryProvider);
    if (repository == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    try {
      if (_isEditing) {
        await repository.update(
          widget.existing!.id,
          name: _nameController.text.trim(),
          type: _type,
        );
      } else {
        await repository.create(
          name: _nameController.text.trim(),
          type: _type,
          openingBalanceMinor:
              Money.tryParse(_openingBalanceController.text) ?? 0,
        );
      }
      if (mounted) navigator.pop();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hand Money keeps its type: it is identified by type, not by name.
    final availableTypes = _isEditing && widget.existing!.isHandMoney
        ? [AccountType.hand]
        : AccountType.values.where((t) => t != AccountType.hand).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit account' : 'New account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Account name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Give the account a name.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: availableTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(iconForAccountType(type), size: 18),
                            const SizedBox(width: 8),
                            Text(labelForAccountType(type)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _type = value ?? AccountType.bank),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _openingBalanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Opening balance',
                    prefixIcon: Icon(Icons.numbers),
                    helperText: 'How much is in this account right now.',
                  ),
                  validator: (value) => Money.tryParse(value ?? '') == null
                      ? 'Enter a valid amount.'
                      : null,
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'The balance is calculated from your records and cannot be '
                  'edited directly. Add an income or expense to correct it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                    : Text(_isEditing ? 'Save changes' : 'Add account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
