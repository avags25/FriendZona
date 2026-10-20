import 'package:dio/dio.dart';

enum ApiErrorKind {
  validation,
  unauthorized,
  conflict,
  network,
  server,
  unknown,
}

class ApiError implements Exception {
  const ApiError(this.kind, this.message, {this.statusCode, this.code});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;

  static ApiError fromDio(DioException exception) {
    final status = exception.response?.statusCode;
    final data = exception.response?.data;
    final body = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    final serverCode = body['code'] as String?;
    if (status == 400) {
      return ApiError(
        ApiErrorKind.validation,
        'Проверьте введённые данные',
        statusCode: status,
        code: serverCode,
      );
    }
    if (status == 401) {
      final message = serverCode == 'INVALID_CREDENTIALS'
          ? 'Неверный email или пароль'
          : 'Сессия завершена. Войдите снова.';
      return ApiError(
        ApiErrorKind.unauthorized,
        message,
        statusCode: status,
        code: serverCode,
      );
    }
    if (status == 409) {
      return ApiError(
        ApiErrorKind.conflict,
        'Аккаунт с таким email уже существует',
        statusCode: status,
        code: serverCode,
      );
    }
    if (exception.type == DioExceptionType.connectionError ||
        exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout) {
      return const ApiError(
        ApiErrorKind.network,
        'Не удалось связаться с сервером. Проверьте подключение.',
      );
    }
    if (status != null && status >= 500) {
      return ApiError(
        ApiErrorKind.server,
        'Сервер временно недоступен',
        statusCode: status,
      );
    }
    return ApiError(
      ApiErrorKind.unknown,
      'Не удалось выполнить запрос',
      statusCode: status,
    );
  }

  @override
  String toString() => message;
}
