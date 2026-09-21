import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over FirebaseAuth that converts provider exceptions into
/// messages a user can act on.
///
/// Screens catch [AuthFailure] and show `message` directly, so no UI code has
/// to know Firebase error codes.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmed);
    }
    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  String _messageFor(FirebaseAuthException error) {
    // Firebase reports "email sign-in is switched off for this project" as a
    // generic internal-error carrying CONFIGURATION_NOT_FOUND, which would
    // otherwise surface to the user as an unhelpful "internal error".
    final details = error.message ?? '';
    if (details.contains('CONFIGURATION_NOT_FOUND') ||
        details.contains('IDENTITY_TOOLKIT_API')) {
      return 'Email sign-in is not enabled for this Firebase project yet. '
          'Enable Email/Password under Authentication in the Firebase console.';
    }

    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a password of at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a moment.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        // The most likely first-run failure: the provider is off in the console.
        return 'Email sign-in is not enabled for this project.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}

/// A sign-in or registration error with a message safe to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
