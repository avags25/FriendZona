import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_error.dart';
import 'auth_data.dart';
import 'models.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8081',
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(const FlutterSecureStorage()),
);

final authRemoteProvider = Provider<AuthRemoteDataSource>((ref) {
  return DioAuthDataSource(
    baseUrl: apiBaseUrl,
    sessions: ref.watch(sessionStoreProvider),
    onSessionExpired: () async {
      await ref.read(authControllerProvider.notifier).sessionExpired();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authRemoteProvider),
    ref.watch(sessionStoreProvider),
  ),
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, PublicUser?>(AuthController.new);

class AuthRepository {
  const AuthRepository(this._remote, this._sessions);

  final AuthRemoteDataSource _remote;
  final SessionStore _sessions;

  Future<PublicUser?> restore() async {
    if (await _sessions.read() == null) return null;
    try {
      return await _remote.me();
    } on ApiError catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        await _sessions.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<PublicUser> register(RegisterRequest request) async {
    await _remote.register(request);
    return signIn(
      LoginRequest(email: request.email, password: request.password),
    );
  }

  Future<PublicUser> signIn(LoginRequest request) async {
    final tokens = await _remote.login(request);
    await _sessions.write(tokens);
    try {
      return await _remote.me();
    } catch (_) {
      await _sessions.clear();
      rethrow;
    }
  }

  Future<PublicUser> updateDisplayName(String displayName) async {
    return _remote.updateProfile(ProfilePatchRequest(displayName: displayName));
  }

  Future<void> signOut() async {
    final current = await _sessions.read();
    try {
      if (current != null) await _remote.logout(current.refreshToken);
    } catch (_) {
      // Local sign-out must complete even when the backend is temporarily unreachable.
    } finally {
      await _sessions.clear();
    }
  }
}

class AuthController extends AsyncNotifier<PublicUser?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<PublicUser?> build() => _repository.restore();

  Future<void> register(RegisterRequest request) =>
      _run(() => _repository.register(request));

  Future<void> signIn(LoginRequest request) =>
      _run(() => _repository.signIn(request));

  Future<void> updateDisplayName(String value) =>
      _run(() => _repository.updateDisplayName(value));

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repository.signOut();
    } finally {
      state = const AsyncData(null);
    }
  }

  Future<void> sessionExpired() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> _run(Future<PublicUser> Function() action) async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await action());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
