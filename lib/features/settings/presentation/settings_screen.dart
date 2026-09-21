import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/app_review_service.dart';
import '../../../services/app_update_service.dart';
import '../../categories/presentation/categories_screen.dart';

/// App version shown in About.
///
/// Kept as a constant rather than pulling in package_info_plus for one string;
/// it must be bumped alongside `version:` in pubspec.yaml.
const String kAppVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  (user.displayName?.isNotEmpty ?? false)
                      ? user.displayName!.characters.first.toUpperCase()
                      : '?',
                ),
              ),
              title: Text(user.displayName ?? 'My Finance user'),
              subtitle: Text(user.email ?? ''),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categories'),
            subtitle: const Text('Organise your income and spending'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CategoriesScreen(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Rate this app'),
            subtitle: const Text('Let others know what you think'),
            onTap: () => AppReviewService.rateApp(),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Check for updates'),
            onTap: () => _checkForUpdate(context),
          ),
          const Divider(),
          const AboutTile(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final started = await AppUpdateService.checkForUpdate();
    if (started) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('You are on the latest version.')),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your data stays safe in the cloud and will be here when you sign '
          'back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // AuthGate reacts to the auth stream and swaps in the login screen.
    await ref.read(authRepositoryProvider).signOut();
  }
}

class AboutTile extends StatelessWidget {
  const AboutTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Image.asset('assets/logo.png', width: 56, height: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Finance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Version $kAppVersion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your accounts, spending and cash in hand.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
