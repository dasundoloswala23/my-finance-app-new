import 'package:cloud_firestore/cloud_firestore.dart';

/// A single repayment against a [Debt].
///
/// Stored in a top-level collection keyed by [debtId] rather than as a
/// subcollection, so the activity feed can read every settlement in one query
/// without needing a collection-group index.
class DebtSettlement {
  const DebtSettlement({
    required this.id,
    required this.debtId,
    required this.amountMinor,
    required this.accountId,
    required this.date,
    this.note = '',
    this.affectsBalance = true,
  });

  final String id;
  final String debtId;

  /// Always positive; the direction of the parent debt decides which way the
  /// cash actually moves.
  final int amountMinor;

  /// Account the repayment moved through — not necessarily the one the debt
  /// was created against.
  final String accountId;

  final DateTime date;
  final String note;

  /// Whether this repayment moved cash through [accountId]. Independent of
  /// the parent debt's flag: a debt recorded without moving cash can still
  /// be repaid into a tracked account today.
  final bool affectsBalance;

  factory DebtSettlement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return DebtSettlement(
      id: doc.id,
      debtId: (data['debtId'] as String?) ?? '',
      amountMinor: (data['amountMinor'] as num?)?.toInt() ?? 0,
      accountId: (data['accountId'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: (data['note'] as String?) ?? '',
      affectsBalance: (data['affectsBalance'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'debtId': debtId,
    'amountMinor': amountMinor,
    'accountId': accountId,
    'date': Timestamp.fromDate(date),
    'note': note,
    'affectsBalance': affectsBalance,
  };

  DebtSettlement copyWith({
    int? amountMinor,
    String? accountId,
    DateTime? date,
    String? note,
    bool? affectsBalance,
  }) {
    return DebtSettlement(
      id: id,
      debtId: debtId,
      amountMinor: amountMinor ?? this.amountMinor,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      note: note ?? this.note,
      affectsBalance: affectsBalance ?? this.affectsBalance,
    );
  }
}
