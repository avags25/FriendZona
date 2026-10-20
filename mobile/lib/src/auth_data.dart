import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_error.dart';
import 'models.dart';

abstract interface class AuthRemoteDataSource {
  Future<PublicUser> register(RegisterRequest request);
  Future<TokenResponse> login(LoginRequest request);
  Future<TokenResponse> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<PublicUser> me();
  Future<PublicUser> updateProfile(ProfilePatchRequest request);
}

abstract interface class SessionStore {
  Future<TokenResponse?> read();
  Future<void> write(TokenResponse session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'social_world.session.v1';

  @override
  Future<TokenResponse?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return TokenResponse.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(TokenResponse session) =>
      _storage.write(key: _key, value: _encode(session));

  @override
  Future<void> clear() => _storage.delete(key: _key);

  String _encode(TokenResponse session) {
    // The secure store is a single encrypted value; JSON keeps nested API models intact.
    return _jsonEncode(session.toJson());
  }

  String _jsonEncode(Map<String, dynamic> value) => jsonEncode(value);
}

class DioAuthDataSource implements AuthRemoteDataSource {
  DioAuthDataSource({
    required String baseUrl,
    required SessionStore sessions,
    required Future<void> Function() onSessionExpired,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(
      _SessionInterceptor(_dio, sessions, onSessionExpired),
    );
  }

  late final Dio _dio;

  @override
  Future<PublicUser> register(RegisterRequest request) async =>
      _guard(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/v1/auth/register',
          data: request.toJson(),
          options: Options(extra: {'skipAuth': true, 'skipRefresh': true}),
        );
        return PublicUser.fromJson(response.data!);
      });

  @override
  Future<TokenResponse> login(LoginRequest request) async => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: request.toJson(),
      options: Options(extra: {'skipAuth': true, 'skipRefresh': true}),
    );
    return TokenResponse.fromJson(response.data!);
  });

  @override
  Future<TokenResponse> refresh(String refreshToken) async => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/refresh',
      data: RefreshRequest(refreshToken: refreshToken).toJson(),
      options: Options(extra: {'skipAuth': true, 'skipRefresh': true}),
    );
    return TokenResponse.fromJson(response.data!);
  });

  @override
  Future<void> logout(String refreshToken) async => _guard(() async {
    final response = await _dio.post<void>(
      '/api/v1/auth/logout',
      data: {'refreshToken': refreshToken},
    );
    return response.data;
  });

  @override
  Future<PublicUser> me() async => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    return PublicUser.fromJson(response.data!);
  });

  @override
  Future<PublicUser> updateProfile(ProfilePatchRequest request) async =>
      _guard(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/users/me/profile',
          data: request.toJson(),
        );
        return PublicUser.fromJson(response.data!);
      });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (exception) {
      throw ApiError.fromDio(exception);
    }
  }
}

class _SessionInterceptor extends Interceptor {
  _SessionInterceptor(this._dio, this._sessions, this._onSessionExpired);

  final Dio _dio;
  final SessionStore _sessions;
  final Future<void> Function() _onSessionExpired;
  final _refresh = SingleFlight<TokenResponse>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final session = await _sessions.read();
      if (session != null) {
        options.headers['Authorization'] =
            '${session.tokenType} ${session.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final canRefresh =
        isUnauthorized &&
        options.extra['skipRefresh'] != true &&
        options.extra['retriedAfterRefresh'] != true &&
        options.extra['skipAuth'] != true;
    if (!canRefresh) {
      handler.next(err);
      return;
    }

    try {
      final tokens = await _refresh.run(_performRefresh);
      options.extra['retriedAfterRefresh'] = true;
      options.headers['Authorization'] =
          '${tokens.tokenType} ${tokens.accessToken}';
      if (options.uri.path.endsWith('/api/v1/auth/logout') &&
          options.data is Map<String, dynamic>) {
        options.data = {
          ...options.data as Map<String, dynamic>,
          'refreshToken': tokens.refreshToken,
        };
      }
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on Object catch (error) {
      handler.next(error is DioException ? error : err);
    }
  }

  Future<TokenResponse> _performRefresh() async {
    final current = await _sessions.read();
    if (current == null) {
      throw const ApiError(ApiErrorKind.unauthorized, 'Нет активной сессии');
    }
    try {
      final next = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: RefreshRequest(refreshToken: current.refreshToken).toJson(),
        options: Options(extra: {'skipAuth': true, 'skipRefresh': true}),
      );
      final tokens = TokenResponse.fromJson(next.data!);
      await _sessions.write(tokens);
      return tokens;
    } on DioException catch (exception) {
      if (exception.response?.statusCode == 401) {
        await _sessions.clear();
        await _onSessionExpired();
      }
      rethrow;
    }
  }
}

class SingleFlight<T> {
  Future<T>? _inProgress;

  Future<T> run(Future<T> Function() action) {
    final active = _inProgress;
    if (active != null) return active;
    final operation = action();
    _inProgress = operation;
    return operation.whenComplete(() {
      if (identical(_inProgress, operation)) _inProgress = null;
    });
  }
}
