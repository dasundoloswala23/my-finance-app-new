import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/balance_math.dart';
import '../../../core/firestore_refs.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(FirebaseFirestore db, String uid)
    : _refs = FirestoreRefs(db, uid);

  final FirestoreRefs _refs;

  /// Categories seeded on first sign-in so the app is usable immediately
  /// instead of forcing the user through a setup screen.
  static const List<({String name, TxnType kind, IconData icon})>
  defaultCategories = [
    (name: 'Salary', kind: TxnType.income, icon: Icons.payments),
    (name: 'Business', kind: TxnType.income, icon: Icons.storefront),
    (name: 'Gift', kind: TxnType.income, icon: Icons.card_giftcard),
    (name: 'Other Income', kind: TxnType.income, icon: Icons.attach_money),
    (name: 'Food', kind: TxnType.expense, icon: Icons.restaurant),
    (name: 'Transport', kind: TxnType.expense, icon: Icons.directions_bus),
    (name: 'Groceries', kind: TxnType.expense, icon: Icons.shopping_basket),
    (name: 'Bills', kind: TxnType.expense, icon: Icons.receipt_long),
    (name: 'Health', kind: TxnType.expense, icon: Icons.local_hospital),
    (name: 'Shopping', kind: TxnType.expense, icon: Icons.shopping_bag),
    (name: 'Entertainment', kind: TxnType.expense, icon: Icons.movie),
    (name: 'Other Expense', kind: TxnType.expense, icon: Icons.more_horiz),
  ];

  Stream<List<Category>> watchCategories() {
    return _refs.categories.snapshots().map((snapshot) {
      final categories = snapshot.docs.map(Category.fromDoc).toList();
      categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return categories;
    });
  }

  Future<void> create({
    required String name,
    required TxnType kind,
    int? iconCodePoint,
  }) async {
    await _refs.categories.add({
      'name': name,
      'kind': kind.name,
      'iconCodePoint': iconCodePoint,
      'isDefault': false,
    });
  }

  Future<void> update(
    String categoryId, {
    required String name,
    required TxnType kind,
  }) async {
    await _refs.categories.doc(categoryId).update({
      'name': name,
      'kind': kind.name,
    });
  }

  Future<void> delete(String categoryId) async {
    await _refs.categories.doc(categoryId).delete();
  }

  /// Seeds [defaultCategories] if the user has none. Safe to call repeatedly.
  Future<void> ensureDefaultCategories() async {
    final existing = await _refs.categories.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _refs.categories.firestore.batch();
    for (final category in defaultCategories) {
      batch.set(_refs.categories.doc(), {
        'name': category.name,
        'kind': category.kind.name,
        'iconCodePoint': category.icon.codePoint,
        'isDefault': true,
      });
    }
    await batch.commit();
  }
}
