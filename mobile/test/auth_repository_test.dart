import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/api_error.dart';
import 'package:social_world_mobile/src/auth_data.dart';
import 'package:social_world_mobile/src/auth_repository.dart';
import 'package:social_world_mobile/src/models.dart';

void main() {
  group('AuthRepository', () {
    late _FakeRemote remote;
    late _FakeStore store;
    late AuthRepository repository;

    setUp(() {
      remote = _FakeRemote();
      store = _FakeStore();
      repository = AuthRepository(remote, store);
    });

    test(
      'clears the protected session when profile restore returns 401',
      () async {
        store.session = _session();
        remote.meError = const ApiError(ApiErrorKind.unauthorized, 'expired');

        expect(await repository.restore(), isNull);
        expect(store.session, isNull);
      },
    );

    test(
      'clears tokens when login cannot establish the protected profile session',
      () async {
        remote.meError = const ApiError(
          ApiErrorKind.unauthorized,
          'invalid session',
        );

        await expectLater(
          repository.signIn(
            const LoginRequest(
              email: 'person@example.com',
              password: 'correct-password',
            ),
          ),
          throwsA(isA<ApiError>()),
        );
        expect(store.session, isNull);
      },
    );

    test(
      'preserves an existing session on a transient network failure',
      () async {
        store.session = _session();
        remote.meError = const ApiError(ApiErrorKind.network, 'offline');

        await expectLater(repository.restore(), throwsA(isA<ApiError>()));
        expect(store.session, isNotNull);
      },
    );

    test('logs out remotely and clears the secure session', () async {
      store.session = _session();

      await repository.signOut();

      expect(remote.loggedOutRefreshToken, 'refresh-value');
      expect(store.session, isNull);
    });

    test('completes local logout when the server cannot be reached', () async {
      store.session = _session();
      remote.logoutError = const ApiError(ApiErrorKind.network, 'offline');

      await repository.signOut();
      expect(store.session, isNull);
    });
  });

  test(
    'coalesces simultaneous refresh attempts into a single operation',
    () async {
      final flight = SingleFlight<int>();
      final completion = Completer<int>();
      var calls = 0;
      Future<int> refresh() {
        calls++;
        return completion.future;
      }

      final first = flight.run(refresh);
      final second = flight.run(refresh);
      expect(calls, 1);
      completion.complete(42);
      expect(await Future.wait([first, second]), [42, 42]);
    },
  );
}

TokenResponse _session() => TokenResponse(
  accessToken: 'access-value',
  tokenType: 'Bearer',
  expiresIn: 900,
  refreshToken: 'refresh-value',
  refreshExpiresAt: DateTime.utc(2026, 11, 19),
  user: PublicUser(
    id: '8f68e9ad-f02f-4158-b87c-4d38fd0a68ab',
    email: 'person@example.com',
    displayName: 'Alex',
    friendCode: 'SW-ABCDEFGH23',
    createdAt: DateTime.utc(2026, 10, 20),
  ),
);

class _FakeStore implements SessionStore {
  TokenResponse? session;

  @override
  Future<TokenResponse?> read() async => session;

  @override
  Future<void> write(TokenResponse value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _FakeRemote implements AuthRemoteDataSource {
  Object? meError;
  Object? logoutError;
  String? loggedOutRefreshToken;
  TokenResponse? loginTokens;

  @override
  Future<PublicUser> me() async {
    if (meError != null) throw meError!;
    return _session().user;
  }

  @override
  Future<void> logout(String refreshToken) async {
    loggedOutRefreshToken = refreshToken;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<TokenResponse> login(LoginRequest request) async =>
      loginTokens ?? _session();

  @override
  Future<TokenResponse> refresh(String refreshToken) async => _session();

  @override
  Future<PublicUser> register(RegisterRequest request) async => _session().user;

  @override
  Future<PublicUser> updateProfile(ProfilePatchRequest request) async =>
      _session().user.withDisplayName(request.displayName);
}
