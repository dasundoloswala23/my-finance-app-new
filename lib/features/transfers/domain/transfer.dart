import 'package:cloud_firestore/cloud_firestore.dart';

/// Movement of money between two of the user's own accounts.
///
/// A transfer never changes net worth — it only moves value — so it is kept
/// separate from income/expense transactions and is excluded from the monthly
/// income and spending figures on the dashboard.
class Transfer {
  const Transfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountMinor,
    required this.date,
    this.note = '',
  });

  final String id;
  final String fromAccountId;
  final String toAccountId;
  final int amountMinor;
  final String note;
  final DateTime date;

  factory Transfer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Transfer(
      id: doc.id,
      fromAccountId: (data['fromAccountId'] as String?) ?? '',
      toAccountId: (data['toAccountId'] as String?) ?? '',
      amountMinor: (data['amountMinor'] as num?)?.toInt() ?? 0,
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromAccountId': fromAccountId,
    'toAccountId': toAccountId,
    'amountMinor': amountMinor,
    'note': note,
    'date': Timestamp.fromDate(date),
  };

  Transfer copyWith({
    String? fromAccountId,
    String? toAccountId,
    int? amountMinor,
    String? note,
    DateTime? date,
  }) {
    return Transfer(
      id: id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amountMinor: amountMinor ?? this.amountMinor,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }
}
