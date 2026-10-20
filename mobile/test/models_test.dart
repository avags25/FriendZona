import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/models.dart';

void main() {
  group('API models', () {
    test(
      'parses the backend token response contract and serializes the secure session',
      () {
        final response = TokenResponse.fromJson({
          'accessToken': 'access-value',
          'tokenType': 'Bearer',
          'expiresIn': 900,
          'refreshToken': 'refresh-value',
          'refreshExpiresAt': '2026-11-19T10:00:00Z',
          'user': {
            'id': '8f68e9ad-f02f-4158-b87c-4d38fd0a68ab',
            'email': 'person@example.com',
            'displayName': 'Alex',
            'createdAt': '2026-10-20T10:00:00Z',
          },
        });

        expect(response.expiresIn, 900);
        expect(response.user.displayName, 'Alex');
        expect(
          TokenResponse.fromJson(response.toJson()).refreshToken,
          'refresh-value',
        );
      },
    );

    test('uses the exact request keys expected by the backend', () {
      expect(
        const RegisterRequest(
          email: 'a@b.co',
          password: 'long-password-123',
          displayName: 'Alex',
        ).toJson(),
        {
          'email': 'a@b.co',
          'password': 'long-password-123',
          'displayName': 'Alex',
        },
      );
      expect(const LoginRequest(email: 'a@b.co', password: 'secret').toJson(), {
        'email': 'a@b.co',
        'password': 'secret',
      });
      expect(const RefreshRequest(refreshToken: 'opaque').toJson(), {
        'refreshToken': 'opaque',
      });
      expect(const ProfilePatchRequest(displayName: 'Alex').toJson(), {
        'displayName': 'Alex',
      });
    });
  });
}
