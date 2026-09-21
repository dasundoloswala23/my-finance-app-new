import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../balance_math.dart';
import '../money.dart';

/// Amount rendered with a sign and a direction colour.
///
/// Colour alone never carries the meaning — the sign is always present — so the
/// row stays readable for colour-blind users and in greyscale.
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amountMinor,
    this.type,
    this.style,
    this.showSign = true,
  });

  /// Positive magnitude when [type] is given, otherwise a signed balance.
  final int amountMinor;

  /// Income or expense. Null renders a neutral balance.
  final TxnType? type;

  final TextStyle? style;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color color;
    final String text;

    if (type != null) {
      final isIncome = type == TxnType.income;
      color = isIncome ? BrandColors.income : BrandColors.expense;
      text = showSign
          ? '${isIncome ? '+' : '-'}${Money.format(amountMinor.abs())}'
          : Money.format(amountMinor.abs());
    } else {
      // A neutral balance: red only when genuinely negative.
      color = amountMinor < 0
          ? BrandColors.expense
          : theme.colorScheme.onSurface;
      text = Money.format(amountMinor);
    }

    return Text(
      text,
      style: (style ?? theme.textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
