import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/validation.dart';

void main() {
  group('FormValidation', () {
    test('accepts a valid email and rejects malformed or oversized values', () {
      expect(FormValidation.email(' alex@example.com '), isNull);
      expect(FormValidation.email('not-an-email'), isNotNull);
      expect(FormValidation.email('a' * 321 + '@example.com'), isNotNull);
    });

    test('matches backend password character and UTF-8 byte limits', () {
      expect(FormValidation.password('Correct Horse 42!'), isNull);
      expect(FormValidation.password('short'), isNotNull);
      expect(FormValidation.password('я' * 37), isNotNull);
    });

    test('validates the profile display name', () {
      expect(FormValidation.displayName('Alex'), isNull);
      expect(FormValidation.displayName('  '), isNotNull);
      expect(FormValidation.displayName('a' * 81), isNotNull);
    });
  });
}
