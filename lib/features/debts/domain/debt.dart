import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';

/// Money lent to or borrowed from another person.
///
/// The cash moves through [accountId] the moment the debt is recorded, so an
/// account balance always reflects money actually handed over or received.
/// What remains owed lives in [outstandingMinor], which settlements chip away
/// at until the debt closes.
class Debt {
  const Debt({
    required this.id,
    required this.personName,
    required this.direction,
    required this.principalMinor,
    required this.accountId,
    required this.date,
    this.settledMinor = 0,
    this.dueDate,
    this.note = '',
  });

  final String id;
  final String personName;
  final DebtDirection direction;

  /// The original amount, always positive. Direction carries the sign.
  final int principalMinor;

  /// How much has been settled so far. Never exceeds [principalMinor].
  final int settledMinor;

  /// Account the original cash moved through.
  final String accountId;

  final DateTime date;
  final DateTime? dueDate;
  final String note;

  /// Still owed.
  int get outstandingMinor => principalMinor - settledMinor;

  /// Derived rather than stored, so it can never disagree with the amounts.
  bool get isSettled => outstandingMinor <= 0;

  bool get isPartlySettled => settledMinor > 0 && !isSettled;

  /// Fraction repaid, clamped for display use.
  double get progress {
    if (principalMinor <= 0) return 1;
    return (settledMinor / principalMinor).clamp(0.0, 1.0);
  }

  /// Money the user expects to get back.
  bool get isReceivable => direction == DebtDirection.given;

  /// Past its due date and still owed.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    if (due == null || isSettled) return false;
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  factory Debt.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Debt(
      id: doc.id,
      personName: (data['personName'] as String?) ?? 'Someone',
      direction: (data['direction'] as String?) == DebtDirection.taken.name
          ? DebtDirection.taken
          : DebtDirection.given,
      principalMinor: (data['principalMinor'] as num?)?.toInt() ?? 0,
      settledMinor: (data['settledMinor'] as num?)?.toInt() ?? 0,
      accountId: (data['accountId'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      note: (data['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'personName': personName,
    'direction': direction.name,
    'principalMinor': principalMinor,
    'settledMinor': settledMinor,
    'accountId': accountId,
    'date': Timestamp.fromDate(date),
    'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
    'note': note,
    // Mirrored into the document so the list can be filtered server-side
    // later without reading every debt.
    'isSettled': isSettled,
  };

  Debt copyWith({
    String? personName,
    DebtDirection? direction,
    int? principalMinor,
    int? settledMinor,
    String? accountId,
    DateTime? date,
    DateTime? dueDate,
    String? note,
  }) {
    return Debt(
      id: id,
      personName: personName ?? this.personName,
      direction: direction ?? this.direction,
      principalMinor: principalMinor ?? this.principalMinor,
      settledMinor: settledMinor ?? this.settledMinor,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
    );
  }
}
