import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';

/// A single income or expense entry.
///
/// Named `Txn` rather than `Transaction` to avoid colliding with Firestore's
/// own `Transaction` type, which the repositories use constantly.
class Txn {
  const Txn({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.accountId,
    required this.date,
    this.categoryId,
    this.note = '',
  });

  final String id;
  final TxnType type;

  /// Always positive. Direction comes from [type].
  final int amountMinor;
  final String accountId;
  final String? categoryId;
  final String note;
  final DateTime date;

  /// Signed value for display and for summing into a running total.
  int get signedAmountMinor =>
      type == TxnType.income ? amountMinor : -amountMinor;

  factory Txn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Txn(
      id: doc.id,
      type: (data['type'] as String?) == TxnType.income.name
          ? TxnType.income
          : TxnType.expense,
      amountMinor: (data['amountMinor'] as num?)?.toInt() ?? 0,
      accountId: (data['accountId'] as String?) ?? '',
      categoryId: data['categoryId'] as String?,
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'amountMinor': amountMinor,
    'accountId': accountId,
    'categoryId': categoryId,
    'note': note,
    'date': Timestamp.fromDate(date),
  };

  Txn copyWith({
    TxnType? type,
    int? amountMinor,
    String? accountId,
    String? categoryId,
    String? note,
    DateTime? date,
  }) {
    return Txn(
      id: id,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }
}
