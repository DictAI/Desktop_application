import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import 'dto/login_request.dart';
import 'dto/login_response.dart';
import 'dto/register_request.dart';

/// A01–A05 through shared authenticated Dio. No token storage or auto-login.
final class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<LoginResponse> login(LoginRequest request) => _perform(() async {
    final data = await _post('/auth/login', request.toJson(), status: 200);
    return LoginResponse.fromJson(data);
  });

  Future<void> register(RegisterRequest request) =>
      _message('/auth/register', request.toJson(), status: 200);

  /// Requires a valid JWT; empty HTTP body is NOT an empty JSON object.
  Future<LoginResponse> refresh() => _perform(() async {
    final data = await _post('/auth/refresh', <String, dynamic>{}, status: 200);
    return LoginResponse.fromJson(data);
  });

  Future<void> changePassword(String newPassword) => _message(
    '/auth/change-password',
    {'new_password': newPassword},
    status: 201,
  );

  Future<void> changeEmail(String newEmail) =>
      _message('/auth/change-email', {'new_email': newEmail}, status: 201);

  Future<void> _message(
    String path,
    Map<String, dynamic> body, {
    required int status,
  }) => _perform(() async {
    final data = await _post(path, body, status: status);
    if (data['message'] is! String || (data['message'] as String).isEmpty) {
      throw const FormatException('Invalid auth message');
    }
  });

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    required int status,
  }) async {
    final response = await _dio.post<Object?>(path, data: body);
    if (response.statusCode != status ||
        response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth response');
    }
    return response.data! as Map<String, dynamic>;
  }

  Future<T> _perform<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      if (error.error is AppException) throw error.error! as AppException;
      throw ApiErrorMapper.fromDio(error) ?? _invalid;
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }

  static final _invalid = ApiFailure(
    'Не удалось прочитать ответ сервера.',
    kind: ApiFailureKind.invalidResponse,
  );
}
