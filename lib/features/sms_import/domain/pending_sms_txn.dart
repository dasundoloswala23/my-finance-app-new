import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';

/// An SMS-detected transaction candidate awaiting manual review.
///
/// Never written directly to the real ledger: [PendingSmsRepository] stores
/// these separately, and a real [Txn] is only created once the user confirms
/// an account (and optionally a category) on the review screen.
class PendingSmsTxn {
  const PendingSmsTxn({
    required this.id,
    required this.rawBody,
    required this.amountMinor,
    required this.type,
    required this.merchant,
    required this.receivedAt,
  });

  final String id;
  final String rawBody;
  final int amountMinor;
  final TxnType type;
  final String merchant;
  final DateTime receivedAt;

  factory PendingSmsTxn.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return PendingSmsTxn(
      id: doc.id,
      rawBody: (data['rawBody'] as String?) ?? '',
      amountMinor: (data['amountMinor'] as num?)?.toInt() ?? 0,
      type: (data['type'] as String?) == TxnType.income.name
          ? TxnType.income
          : TxnType.expense,
      merchant: (data['merchant'] as String?) ?? '',
      receivedAt:
          (data['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'rawBody': rawBody,
    'amountMinor': amountMinor,
    'type': type.name,
    'merchant': merchant,
    'receivedAt': Timestamp.fromDate(receivedAt),
  };
}
