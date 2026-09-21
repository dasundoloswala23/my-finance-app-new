import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/features/auth/presentation/login_screen.dart';

void main() {
  group('validateEmail', () {
    test('accepts ordinary addresses', () {
      expect(validateEmail('someone@example.com'), isNull);
      expect(validateEmail('first.last@sub.example.co.uk'), isNull);
    });

    test('ignores surrounding whitespace', () {
      expect(validateEmail('  someone@example.com  '), isNull);
    });

    test('rejects empty input with a prompt', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
      expect(validateEmail('   '), isNotNull);
    });

    test('rejects addresses missing an @ or a domain dot', () {
      expect(validateEmail('someone'), isNotNull);
      expect(validateEmail('someone@'), isNotNull);
      expect(validateEmail('someone@example'), isNotNull);
      expect(validateEmail('@example.com'), isNotNull);
      expect(validateEmail('some one@example.com'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('accepts six characters or more', () {
      expect(validatePassword('secret'), isNull);
      expect(validatePassword('a much longer passphrase'), isNull);
    });

    test('rejects empty input', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });

    test('rejects anything shorter than the Firebase minimum', () {
      expect(validatePassword('12345'), isNotNull);
    });
  });
}
