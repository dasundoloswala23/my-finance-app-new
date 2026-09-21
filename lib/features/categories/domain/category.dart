import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/balance_math.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.iconCodePoint,
    this.isDefault = false,
  });

  final String id;
  final String name;

  /// Whether this category applies to income or expense transactions.
  final TxnType kind;

  /// Material icon code point, stored as an int so the icon survives a round
  /// trip through Firestore.
  final int? iconCodePoint;

  /// Seeded categories are marked so they can be recreated if the user wipes
  /// them, and so the UI can warn before deleting one that is in wide use.
  final bool isDefault;

  factory Category.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Category(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Untitled',
      kind: (data['kind'] as String?) == TxnType.income.name
          ? TxnType.income
          : TxnType.expense,
      iconCodePoint: (data['iconCodePoint'] as num?)?.toInt(),
      isDefault: (data['isDefault'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'kind': kind.name,
    'iconCodePoint': iconCodePoint,
    'isDefault': isDefault,
  };

  Category copyWith({String? name, TxnType? kind, int? iconCodePoint}) {
    return Category(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isDefault: isDefault,
    );
  }
}
