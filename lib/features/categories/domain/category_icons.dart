import 'package:flutter/material.dart';

/// Fixed catalogue of icons a category may use.
///
/// Constructing `IconData` from a stored integer at runtime defeats Flutter's
/// icon tree-shaking and fails the release build, so code points are resolved
/// against this const table instead. An unknown code point falls back to a
/// generic label rather than rendering a missing glyph.
class CategoryIcons {
  const CategoryIcons._();

  static const List<IconData> catalog = [
    Icons.payments,
    Icons.storefront,
    Icons.card_giftcard,
    Icons.attach_money,
    Icons.restaurant,
    Icons.directions_bus,
    Icons.shopping_basket,
    Icons.receipt_long,
    Icons.local_hospital,
    Icons.shopping_bag,
    Icons.movie,
    Icons.more_horiz,
    Icons.home,
    Icons.school,
    Icons.flight,
    Icons.pets,
    Icons.fitness_center,
    Icons.phone_android,
    Icons.local_gas_station,
    Icons.savings,
  ];

  static const IconData fallback = Icons.label_outline;

  /// Resolves a stored code point to one of the catalogue icons.
  static IconData resolve(int? codePoint) {
    if (codePoint == null) return fallback;
    for (final icon in catalog) {
      if (icon.codePoint == codePoint) return icon;
    }
    return fallback;
  }
}
