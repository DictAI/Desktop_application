import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import '../error/app_exception.dart';

final class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Future<void> Function()? onUnauthorized;

  AuthInterceptor(this._storage, {this.onUnauthorized});

  static const _publicPaths = {'/auth/login', '/auth/register'};
  static const _revisionKey = 'dictai.credentialRevision';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final isPublic = _publicPaths.contains(options.uri.path);
      options.headers.removeWhere(
        (name, _) => name.toLowerCase() == 'authorization',
      );
      options.extra.remove(_revisionKey);
      if (!isPublic) {
        final credential = await _storage.readCredential();
        if (credential != null) {
          options.headers['Authorization'] = 'Bearer ${credential.token}';
          options.extra[_revisionKey] = credential.revision;
        }
      }
      handler.next(options);
    } on AppException catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: error.message,
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    var matched = false;
    AppException? failure;
    try {
      final revision = err.requestOptions.extra[_revisionKey];
      final header = err.requestOptions.headers['Authorization'];
      if (err.response?.statusCode == 401 &&
          revision is int &&
          header is String &&
          header.startsWith('Bearer ')) {
        final credential = (token: header.substring(7), revision: revision);
        await _storage.deleteCredentialIfCurrent(
          credential,
          onMatch: () => matched = true,
        );
      }
    } on AppException catch (error) {
      failure = error;
    }
    if (matched) {
      try {
        await onUnauthorized?.call();
      } catch (_) {
        failure ??= const ServerException('Сессия завершена. Войдите снова.');
      }
    }
    handler.next(
      failure == null
          ? err
          : err.copyWith(error: failure, message: failure.message),
    );
  }
}
