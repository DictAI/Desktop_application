import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// Добавляет JWT Bearer token к каждому запросу, кроме /auth/login и /auth/register.
final class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;

  AuthInterceptor(this._storage);

  static const _publicPaths = {'/auth/login', '/auth/register'};

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = _publicPaths.any((p) => options.path.endsWith(p));
    if (!isPublic) {
      final token = await _storage.getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}
