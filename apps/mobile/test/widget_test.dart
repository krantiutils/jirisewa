import 'package:flutter_test/flutter_test.dart';

import 'package:jirisewa_mobile/core/phone_validation.dart';

void main() {
  group('Phone validation', () {
    test('valid Nepal numbers', () {
      expect(isValidNepalPhone('9812345678'), true);
      expect(isValidNepalPhone('9801234567'), true);
      expect(isValidNepalPhone('9712345678'), true);
      expect(isValidNepalPhone('9612345678'), true);
    });

    test('invalid numbers', () {
      expect(isValidNepalPhone('123456789'), false); // too short
      expect(isValidNepalPhone('12345678901'), false); // too long
      expect(isValidNepalPhone('1234567890'), false); // wrong prefix
      expect(isValidNepalPhone(''), false);
    });

    test('normalization strips country code', () {
      expect(normalizePhone('+9779812345678'), '9812345678');
      expect(normalizePhone('9779812345678'), '9812345678');
      expect(normalizePhone('09812345678'), '9812345678');
    });

    test('toE164 formats correctly', () {
      expect(toE164('9812345678'), '+9779812345678');
      expect(toE164('+9779812345678'), '+9779812345678');
    });

    test('normalization strips whitespace and dashes', () {
      expect(normalizePhone('981 234 5678'), '9812345678');
      expect(normalizePhone('981-234-5678'), '9812345678');
      expect(normalizePhone('(981) 234-5678'), '9812345678');
    });
  });
}
