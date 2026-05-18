import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/login_request.dart';
import 'dto/login_response.dart';
import 'dto/register_request.dart';

final class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
      );
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> register(RegisterRequest request) async {
    try {
      await _dio.post('/auth/register', data: request.toJson());
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<LoginResponse> refresh() async {
    try {
      final response = await _dio.post('/auth/refresh');
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> changePassword(String newPassword) async {
    try {
      await _dio.post('/auth/change-password', data: {'password': newPassword});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> changeEmail(String newEmail) async {
    try {
      await _dio.post('/auth/change-email', data: {'email': newEmail});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) {
    final msg = (e.response?.data as Map?)?['error'] as String?;
    return switch (e.response?.statusCode) {
      400 => ValidationException(msg ?? 'Invalid request'),
      401 => const UnauthorizedException(),
      409 => ValidationException(msg ?? 'Email already registered'),
      _ => ServerException(msg ?? 'Server error'),
    };
  }
}
