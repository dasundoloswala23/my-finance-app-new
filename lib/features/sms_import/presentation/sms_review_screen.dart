import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/balance_math.dart';
import '../../../core/money.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../domain/pending_sms_txn.dart';

/// Lets the user confirm or discard transactions detected from incoming SMS.
///
/// Nothing here is ever written to the real ledger automatically — every
/// candidate needs an explicit account choice and a tap on "Add" first, since
/// the parser is a best-effort guess and bank SMS formats vary widely.
class SmsReviewScreen extends ConsumerWidget {
  const SmsReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRepo = ref.watch(pendingSmsRepositoryProvider);
    if (pendingRepo == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detected from SMS')),
      body: StreamBuilder<List<PendingSmsTxn>>(
        stream: pendingRepo.watchAll(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.sms_outlined,
              title: 'Nothing detected yet',
              message:
                  'Transaction alerts from your bank will show up here for '
                  'review before they are added.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _PendingSmsCard(candidate: items[index]),
          );
        },
      ),
    );
  }
}

class _PendingSmsCard extends ConsumerStatefulWidget {
  const _PendingSmsCard({required this.candidate});

  final PendingSmsTxn candidate;

  @override
  ConsumerState<_PendingSmsCard> createState() => _PendingSmsCardState();
}

class _PendingSmsCardState extends ConsumerState<_PendingSmsCard> {
  String? _accountId;
  String? _categoryId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final accounts = ref.watch(accountRepositoryProvider);
    final categories = ref.watch(categoryRepositoryProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  candidate.type == TxnType.income
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: candidate.type == TxnType.income
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  Money.format(candidate.amountMinor),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (candidate.merchant.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      candidate.merchant,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              candidate.rawBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (accounts != null)
              StreamBuilder<List<Account>>(
                stream: accounts.watchAccounts(),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const [];
                  return DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: items
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _accountId = value),
                  );
                },
              ),
            const SizedBox(height: 8),
            if (categories != null)
              StreamBuilder<List<Category>>(
                stream: categories.watchCategories(),
                builder: (context, snapshot) {
                  final items = (snapshot.data ?? const [])
                      .where((c) => c.kind == candidate.type)
                      .toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                    items: items
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  );
                },
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => _discard(candidate),
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving || _accountId == null
                      ? null
                      : () => _confirm(candidate),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(PendingSmsTxn candidate) async {
    final repo = ref.read(pendingSmsRepositoryProvider);
    await repo?.discard(candidate.id);
  }

  Future<void> _confirm(PendingSmsTxn candidate) async {
    final accountId = _accountId;
    if (accountId == null) return;
    setState(() => _saving = true);

    final transactions = ref.read(transactionRepositoryProvider);
    final pending = ref.read(pendingSmsRepositoryProvider);
    try {
      await transactions?.create(
        type: candidate.type,
        amountMinor: candidate.amountMinor,
        accountId: accountId,
        date: candidate.receivedAt,
        categoryId: _categoryId,
        note: candidate.merchant.isEmpty
            ? 'From SMS'
            : 'From SMS • ${candidate.merchant}',
      );
      await pending?.discard(candidate.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
