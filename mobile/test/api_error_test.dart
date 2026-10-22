import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/api_error.dart';

void main() {
  group('ApiError', () {
    test('maps validation and duplicate-account Problem Details', () {
      final invalid = ApiError.fromDio(
        _responseError(400, {
          'detail': 'Invalid fields',
          'code': 'INVALID_REQUEST',
        }),
      );
      final conflict = ApiError.fromDio(
        _responseError(409, {
          'detail': 'Already registered',
          'code': 'EMAIL_ALREADY_REGISTERED',
        }),
      );
      expect(invalid.kind, ApiErrorKind.validation);
      expect(invalid.code, 'INVALID_REQUEST');
      expect(conflict.kind, ApiErrorKind.conflict);
      expect(conflict.code, 'EMAIL_ALREADY_REGISTERED');
    });

    test(
      'maps unauthorized responses and network failures without exposing request data',
      () {
        final unauthorized = ApiError.fromDio(
          _responseError(401, {'detail': 'Authentication is required'}),
        );
        final network = ApiError.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/api/v1/users/me'),
            type: DioExceptionType.connectionError,
          ),
        );
        expect(unauthorized.kind, ApiErrorKind.unauthorized);
        expect(network.kind, ApiErrorKind.network);
        expect(network.message, isNot(contains('Bearer')));
      },
    );

    test('maps friend lookup and request conflicts', () {
      final missingCode = ApiError.fromDio(
        _responseError(404, {'code': 'FRIEND_CODE_NOT_FOUND'}),
      );
      final pending = ApiError.fromDio(
        _responseError(409, {'code': 'FRIEND_REQUEST_PENDING'}),
      );
      expect(missingCode.message, 'Код друга не найден');
      expect(pending.message, 'Заявка уже отправлена или обработана');
    });
  });
}

DioException _responseError(int status, Map<String, dynamic> data) =>
    DioException(
      requestOptions: RequestOptions(path: '/api/v1/test'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/test'),
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
