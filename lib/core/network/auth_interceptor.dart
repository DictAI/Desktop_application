import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

final class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Future<void> Function()? onUnauthorized;

  AuthInterceptor(this._storage, {this.onUnauthorized});

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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _storage.deleteToken();
      await onUnauthorized?.call();
    }
    handler.next(err);
  }
}
