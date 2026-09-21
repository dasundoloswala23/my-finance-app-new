import 'package:cloud_firestore/cloud_firestore.dart';

/// Kind of account. [hand] is the "Hand Money" cash-in-pocket account, which is
/// seeded automatically and cannot be deleted — modelling it as an ordinary
/// account means moving cash to or from it is just a transfer.
enum AccountType { bank, cash, wallet, hand }

AccountType _accountTypeFrom(String? raw) {
  return AccountType.values.firstWhere(
    (type) => type.name == raw,
    orElse: () => AccountType.bank,
  );
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balanceMinor,
    this.isArchived = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final AccountType type;
  final int balanceMinor;
  final bool isArchived;
  final DateTime? createdAt;

  /// Hand Money is protected from deletion and always sorts first.
  bool get isHandMoney => type == AccountType.hand;

  factory Account.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Account(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Untitled',
      type: _accountTypeFrom(data['type'] as String?),
      balanceMinor: (data['balanceMinor'] as num?)?.toInt() ?? 0,
      isArchived: (data['isArchived'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'balanceMinor': balanceMinor,
    'isArchived': isArchived,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
  };

  Account copyWith({
    String? name,
    AccountType? type,
    int? balanceMinor,
    bool? isArchived,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
    );
  }
}
