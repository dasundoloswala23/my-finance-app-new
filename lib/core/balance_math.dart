/// Pure balance arithmetic, kept free of Firestore so it can be unit tested.
///
/// Every mutation of an account balance in this app is expressed as a map of
/// `accountId -> delta in minor units`. Repositories apply those deltas inside
/// a Firestore transaction, so the same arithmetic that is tested here is the
/// arithmetic that runs in production.
library;

/// Whether a transaction adds to or subtracts from an account.
enum TxnType { income, expense }

/// Delta produced by recording a transaction.
///
/// Income increases the account, expense decreases it. [amountMinor] is always
/// positive; direction comes from [type].
Map<String, int> applyTransaction({
  required String accountId,
  required TxnType type,
  required int amountMinor,
}) {
  final signed = type == TxnType.income ? amountMinor : -amountMinor;
  return {accountId: signed};
}

/// Delta that undoes [applyTransaction] for the same inputs.
Map<String, int> reverseTransaction({
  required String accountId,
  required TxnType type,
  required int amountMinor,
}) {
  final applied = applyTransaction(
    accountId: accountId,
    type: type,
    amountMinor: amountMinor,
  );
  return applied.map((key, value) => MapEntry(key, -value));
}

/// Net delta for editing a transaction in place: reverse the old, apply the new.
///
/// When the account is unchanged the two entries merge into a single net delta,
/// which keeps the Firestore transaction to one write per account.
Map<String, int> editTransaction({
  required String oldAccountId,
  required TxnType oldType,
  required int oldAmountMinor,
  required String newAccountId,
  required TxnType newType,
  required int newAmountMinor,
}) {
  return mergeDeltas([
    reverseTransaction(
      accountId: oldAccountId,
      type: oldType,
      amountMinor: oldAmountMinor,
    ),
    applyTransaction(
      accountId: newAccountId,
      type: newType,
      amountMinor: newAmountMinor,
    ),
  ]);
}

/// Delta produced by a transfer: money leaves one account and enters another.
///
/// A transfer never changes net worth, so the deltas always sum to zero.
Map<String, int> applyTransfer({
  required String fromAccountId,
  required String toAccountId,
  required int amountMinor,
}) {
  return mergeDeltas([
    {fromAccountId: -amountMinor},
    {toAccountId: amountMinor},
  ]);
}

/// Delta that undoes [applyTransfer] for the same inputs.
Map<String, int> reverseTransfer({
  required String fromAccountId,
  required String toAccountId,
  required int amountMinor,
}) {
  final applied = applyTransfer(
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amountMinor: amountMinor,
  );
  return applied.map((key, value) => MapEntry(key, -value));
}

/// Net delta for editing a transfer in place.
Map<String, int> editTransfer({
  required String oldFromAccountId,
  required String oldToAccountId,
  required int oldAmountMinor,
  required String newFromAccountId,
  required String newToAccountId,
  required int newAmountMinor,
}) {
  return mergeDeltas([
    reverseTransfer(
      fromAccountId: oldFromAccountId,
      toAccountId: oldToAccountId,
      amountMinor: oldAmountMinor,
    ),
    applyTransfer(
      fromAccountId: newFromAccountId,
      toAccountId: newToAccountId,
      amountMinor: newAmountMinor,
    ),
  ]);
}

/// Sums several delta maps, dropping any account whose net change is zero so
/// callers never issue a pointless write.
Map<String, int> mergeDeltas(Iterable<Map<String, int>> deltas) {
  final merged = <String, int>{};
  for (final delta in deltas) {
    delta.forEach((accountId, value) {
      merged[accountId] = (merged[accountId] ?? 0) + value;
    });
  }
  merged.removeWhere((_, value) => value == 0);
  return merged;
}
