import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/balance_math.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../dashboard/providers.dart';
import '../domain/category.dart';
import '../domain/category_icons.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add),
            onPressed: () => _showEditor(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(error: error),
        data: (categories) {
          if (categories.isEmpty) {
            return const EmptyState(
              icon: Icons.label_outline,
              title: 'No categories',
              message: 'Add categories to group your income and spending.',
            );
          }

          final income = categories
              .where((c) => c.kind == TxnType.income)
              .toList();
          final expense = categories
              .where((c) => c.kind == TxnType.expense)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _CategorySection(
                title: 'Income',
                categories: income,
                onEdit: (category) => _showEditor(context, ref, category),
                onDelete: (category) => _confirmDelete(context, ref, category),
              ),
              const SizedBox(height: 16),
              _CategorySection(
                title: 'Expense',
                categories: expense,
                onEdit: (category) => _showEditor(context, ref, category),
                onDelete: (category) => _confirmDelete(context, ref, category),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, [
    Category? existing,
  ]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    var kind = existing?.kind ?? TxnType.expense;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TxnType>(
                segments: const [
                  ButtonSegment(
                    value: TxnType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment(value: TxnType.income, label: Text('Income')),
                ],
                selected: {kind},
                onSelectionChanged: (selection) =>
                    setDialogState(() => kind = selection.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (saved != true || name.isEmpty) return;

    final repository = ref.read(categoryRepositoryProvider);
    if (repository == null) return;

    if (existing == null) {
      await repository.create(name: name, kind: kind);
    } else {
      await repository.update(existing.id, name: name, kind: kind);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${category.name}?'),
        content: const Text(
          'Records already using this category are kept, but they will show '
          'no category name.',
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
    if (confirmed != true) return;

    await ref.read(categoryRepositoryProvider)?.delete(category.id);
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<Category> categories;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Text(
            'None yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...categories.map(
            (category) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(CategoryIcons.resolve(category.iconCodePoint)),
                ),
                title: Text(category.name),
                onTap: () => onEdit(category),
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(category),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
