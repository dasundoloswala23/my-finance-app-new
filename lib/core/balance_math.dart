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

/// Which way a debt runs.
///
/// [given] is money lent out — it leaves the account and the other person owes
/// it back. [taken] is money borrowed — it arrives in the account and is owed
/// to someone else.
enum DebtDirection { given, taken }

/// Delta produced by recording a debt.
///
/// Lending hands cash over, so the account falls; borrowing receives cash, so
/// it rises. [amountMinor] is always positive — direction carries the sign.
Map<String, int> applyDebt({
  required String accountId,
  required DebtDirection direction,
  required int amountMinor,
}) {
  final signed = direction == DebtDirection.given ? -amountMinor : amountMinor;
  return {accountId: signed};
}

/// Delta that undoes [applyDebt] for the same inputs.
Map<String, int> reverseDebt({
  required String accountId,
  required DebtDirection direction,
  required int amountMinor,
}) {
  final applied = applyDebt(
    accountId: accountId,
    direction: direction,
    amountMinor: amountMinor,
  );
  return applied.map((key, value) => MapEntry(key, -value));
}

/// Net delta for editing a debt in place: reverse the old, apply the new.
Map<String, int> editDebt({
  required String oldAccountId,
  required DebtDirection oldDirection,
  required int oldAmountMinor,
  required String newAccountId,
  required DebtDirection newDirection,
  required int newAmountMinor,
}) {
  return mergeDeltas([
    reverseDebt(
      accountId: oldAccountId,
      direction: oldDirection,
      amountMinor: oldAmountMinor,
    ),
    applyDebt(
      accountId: newAccountId,
      direction: newDirection,
      amountMinor: newAmountMinor,
    ),
  ]);
}

/// Delta produced by settling part or all of a debt.
///
/// Cash flows the opposite way to the original debt: being repaid on money you
/// lent increases the account, repaying money you borrowed decreases it. So
/// creating a debt and then settling it in full leaves the account exactly
/// where it started.
Map<String, int> applyDebtSettlement({
  required String accountId,
  required DebtDirection direction,
  required int amountMinor,
}) {
  final signed = direction == DebtDirection.given ? amountMinor : -amountMinor;
  return {accountId: signed};
}

/// Delta that undoes [applyDebtSettlement] for the same inputs.
Map<String, int> reverseDebtSettlement({
  required String accountId,
  required DebtDirection direction,
  required int amountMinor,
}) {
  final applied = applyDebtSettlement(
    accountId: accountId,
    direction: direction,
    amountMinor: amountMinor,
  );
  return applied.map((key, value) => MapEntry(key, -value));
}

/// Net delta for editing a settlement in place.
Map<String, int> editDebtSettlement({
  required String oldAccountId,
  required int oldAmountMinor,
  required String newAccountId,
  required int newAmountMinor,
  required DebtDirection direction,
}) {
  return mergeDeltas([
    reverseDebtSettlement(
      accountId: oldAccountId,
      direction: direction,
      amountMinor: oldAmountMinor,
    ),
    applyDebtSettlement(
      accountId: newAccountId,
      direction: direction,
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
