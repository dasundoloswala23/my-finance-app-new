import 'package:intl/intl.dart';

/// Money is stored and calculated as an integer number of minor units (cents).
///
/// Never use `double` for balances: repeated addition of fractional values
/// drifts, and a finance app that is off by a cent after fifty transactions is
/// broken. Values are converted to a decimal string only for display and back
/// to minor units immediately on input.
class Money {
  const Money._();

  /// Minor units in one major unit. Fixed at 100 — the app is single-currency
  /// for now and every supported currency is 2-decimal.
  static const int minorPerMajor = 100;

  /// Parses user input ("1,234.56", "1234.5", "-20") into minor units.
  ///
  /// Returns null when the text is not a valid amount, so form validators can
  /// distinguish "not a number" from "zero".
  static int? tryParse(String input) {
    final cleaned = input.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;

    final value = double.tryParse(cleaned);
    if (value == null || value.isNaN || value.isInfinite) return null;

    // Round rather than truncate so 0.1 + 0.2 style input noise lands on the
    // cent the user actually typed.
    return (value * minorPerMajor).round();
  }

  /// Converts minor units to a plain decimal string suitable for a text field.
  static String toEditingValue(int minor) =>
      (minor / minorPerMajor).toStringAsFixed(2);

  /// Formats minor units for display, e.g. 123456 -> "Rs 1,234.56".
  static String format(int minor, {String symbol = 'Rs '}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(minor / minorPerMajor);
  }

  /// Formats with an explicit sign, for transaction rows where direction
  /// matters more than magnitude.
  static String formatSigned(int minor, {String symbol = 'Rs '}) {
    final sign = minor < 0 ? '-' : '+';
    return '$sign${format(minor.abs(), symbol: symbol)}';
  }
}
