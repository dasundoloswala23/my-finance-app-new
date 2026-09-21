import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../home/presentation/home_shell.dart';
import 'login_screen.dart';

/// Routes between the sign-in screen and the app based on auth state.
///
/// Also seeds the Hand Money account and default categories the first time a
/// user reaches the app, so a new account is immediately usable.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _seededUid;

  Future<void> _seedFor(String uid) async {
    // Guard against re-seeding on every rebuild of the same session.
    if (_seededUid == uid) return;
    _seededUid = uid;

    try {
      await ref.read(accountRepositoryProvider)?.ensureHandMoneyAccount();
      await ref.read(categoryRepositoryProvider)?.ensureDefaultCategories();
    } catch (error) {
      // Seeding failing (offline, rules not deployed) must not block sign-in.
      // The user still reaches the app; the lists simply start empty.
      debugPrint('Seeding defaults failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _SplashScaffold(),
      error: (error, _) => _StartupErrorScaffold(message: '$error'),
      data: (user) {
        if (user == null) return const LoginScreen();
        _seedFor(user.uid);
        return const HomeShell();
      },
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 140, height: 140),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScaffold extends StatelessWidget {
  const _StartupErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not start My Finance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
