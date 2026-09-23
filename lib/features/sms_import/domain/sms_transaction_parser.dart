import '../../../core/balance_math.dart';

/// A transaction candidate extracted from a raw SMS body.
class ParsedSms {
  const ParsedSms({
    required this.amountMinor,
    required this.type,
    required this.merchant,
  });

  final int amountMinor;
  final TxnType type;

  /// Best-effort merchant/payee name, empty when none could be found.
  final String merchant;
}

/// Generic, bank-agnostic parser for transaction alert SMS.
///
/// Looks for an amount preceded by a currency marker, then classifies the
/// message as a debit or credit from nearby keywords. This is intentionally
/// loose: bank SMS formats vary widely, so this favours catching most real
/// alerts over rejecting all malformed ones. Every result still goes through
/// manual review before it becomes a real transaction — see
/// [PendingSmsRepository] — so a wrong guess here costs a discard tap, not a
/// corrupted ledger.
class SmsTransactionParser {
  const SmsTransactionParser._();

  static final _amountPattern = RegExp(
    r'(?:LKR|RS|INR|USD|\$|₹)\.?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _creditKeywords = RegExp(
    r'\b(credited|credit|deposited|received|refund)\b',
    caseSensitive: false,
  );

  static final _debitKeywords = RegExp(
    r'\b(debited|debit|withdrawn|spent|purchase|paid|payment)\b',
    caseSensitive: false,
  );

  /// Trailing `at`/`to`/`from` followed by a merchant name.
  static final _merchantPattern = RegExp(
    r'\b(?:at|to|from)\s+([A-Z0-9][A-Za-z0-9 &\-\.]{2,30})',
  );

  /// Returns null when the message doesn't look like a transaction alert.
  static ParsedSms? tryParse(String body) {
    final amountMatch = _amountPattern.firstMatch(body);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    final isCredit = _creditKeywords.hasMatch(body);
    final isDebit = _debitKeywords.hasMatch(body);
    // Ambiguous or unrecognised wording: not confidently a transaction.
    if (isCredit == isDebit) return null;

    final merchantMatch = _merchantPattern.firstMatch(body);

    return ParsedSms(
      amountMinor: (amount * 100).round(),
      type: isCredit ? TxnType.income : TxnType.expense,
      merchant: merchantMatch?.group(1)?.trim() ?? '',
    );
  }
}
