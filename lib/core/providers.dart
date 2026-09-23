import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/accounts/data/account_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/categories/data/category_repository.dart';
import '../features/sms_import/data/pending_sms_repository.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/transfers/data/transfer_repository.dart';

/// Firebase singletons, exposed as providers so tests can override them.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

/// Drives the whole app: every data provider below is scoped to this user.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Current user id, or null when signed out.
///
/// Repository providers return null rather than throwing when signed out, so a
/// stray rebuild during sign-out cannot crash the app.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final accountRepositoryProvider = Provider<AccountRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return AccountRepository(ref.watch(firestoreProvider), uid);
});

final categoryRepositoryProvider = Provider<CategoryRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return CategoryRepository(ref.watch(firestoreProvider), uid);
});

final transactionRepositoryProvider = Provider<TransactionRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return TransactionRepository(ref.watch(firestoreProvider), uid);
});

final transferRepositoryProvider = Provider<TransferRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return TransferRepository(ref.watch(firestoreProvider), uid);
});

final pendingSmsRepositoryProvider = Provider<PendingSmsRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return PendingSmsRepository(ref.watch(firestoreProvider), uid);
});
