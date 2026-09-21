import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/money.dart';

void main() {
  group('Money.tryParse', () {
    test('parses whole and decimal amounts into minor units', () {
      expect(Money.tryParse('10'), 1000);
      expect(Money.tryParse('10.5'), 1050);
      expect(Money.tryParse('10.55'), 1055);
      expect(Money.tryParse('0.01'), 1);
    });

    test('tolerates thousands separators and surrounding spaces', () {
      expect(Money.tryParse('1,234.56'), 123456);
      expect(Money.tryParse('  99.99  '), 9999);
    });

    test('handles negative amounts', () {
      expect(Money.tryParse('-20'), -2000);
      expect(Money.tryParse('-0.75'), -75);
    });

    test('rounds to the nearest cent rather than truncating', () {
      // 19.999 must not silently become 19.99.
      expect(Money.tryParse('19.999'), 2000);
      expect(Money.tryParse('0.005'), 1);
    });

    test('returns null for input that is not a number', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('   '), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('12.34.56'), isNull);
    });

    test('distinguishes an invalid amount from a zero amount', () {
      expect(Money.tryParse('0'), 0);
      expect(Money.tryParse('nope'), isNull);
    });
  });

  group('Money.toEditingValue', () {
    test('always renders two decimal places', () {
      expect(Money.toEditingValue(1000), '10.00');
      expect(Money.toEditingValue(1055), '10.55');
      expect(Money.toEditingValue(1), '0.01');
      expect(Money.toEditingValue(0), '0.00');
    });

    test('round-trips through tryParse without drift', () {
      for (final minor in [0, 1, 99, 100, 123456, -4550]) {
        expect(Money.tryParse(Money.toEditingValue(minor)), minor);
      }
    });
  });

  group('Money.format', () {
    test('groups thousands and keeps two decimals', () {
      expect(Money.format(123456), contains('1,234.56'));
      expect(Money.format(0), contains('0.00'));
    });
  });

  group('Money.formatSigned', () {
    test('prefixes the direction and drops the inner sign', () {
      expect(Money.formatSigned(1000), startsWith('+'));
      expect(Money.formatSigned(-1000), startsWith('-'));
      // The magnitude is formatted from the absolute value, so no double sign.
      expect(Money.formatSigned(-1000), isNot(contains('--')));
    });
  });
}
