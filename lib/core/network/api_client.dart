import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage.dart';
import '../config/app_config.dart';

Dio createDio({
  required String baseUrl,
  required SecureStorage storage,
  Future<void> Function()? onUnauthorized,
  bool enableNetworkDiagnostics = false,
  bool isDebugBuild = kDebugMode,
  void Function(String)? diagnosticSink,
  AppConfig? appConfig,
}) {
  final config = appConfig ?? AppConfig.parse(apiBaseUrl: baseUrl);
  if (Uri.parse(baseUrl).origin != config.gateway.origin) {
    throw const FormatException('Conflicting gateway configuration.');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      sendTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      followRedirects: false,
      maxRedirects: 0,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(_GatewayPolicy(config));
  dio.interceptors.add(
    AuthInterceptor(storage, onUnauthorized: onUnauthorized),
  );
  if (kDebugMode && isDebugBuild && enableNetworkDiagnostics) {
    dio.interceptors.add(_SafeDiagnostics(diagnosticSink ?? debugPrint));
  }

  return dio;
}

class _GatewayPolicy extends Interceptor {
  _GatewayPolicy(this.config);
  final AppConfig config;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final path = Uri.parse(options.path);
      if (options.path.contains('\\') ||
          (path.hasAuthority && !path.hasScheme)) {
        throw const GatewayPolicyException();
      }
      config.checkTarget(options.uri);
      options.followRedirects = false;
      options.maxRedirects = 0;
      options.connectTimeout = AppConfig.connectTimeout;
      final upload =
          options.data is FormData ||
          (options.method == 'POST' &&
              {
                '/ingest/v2/audio/upload',
                '/ingest/v2/audio/upload/anonymous',
              }.contains(options.uri.path));
      final download =
          options.responseType == ResponseType.bytes ||
          options.responseType == ResponseType.stream ||
          options.uri.path.contains('/documents/') ||
          options.uri.path.endsWith('/original');
      options.sendTimeout = upload
          ? AppConfig.uploadTimeout
          : AppConfig.requestTimeout;
      options.receiveTimeout = upload
          ? AppConfig.uploadTimeout
          : download
          ? AppConfig.downloadTimeout
          : AppConfig.requestTimeout;
      handler.next(options);
    } catch (_) {
      const error = GatewayPolicyException();
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: error.message,
        ),
      );
    }
  }
}

/// Logs only client-generated correlation IDs, known methods and HTTP statuses.
/// URLs, headers, bodies and exception strings are intentionally never inspected.
class _SafeDiagnostics extends Interceptor {
  _SafeDiagnostics(this._sink);

  final void Function(String) _sink;
  static const _idKey = 'dictai.diagnostic_id';
  static const _methods = {
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
  };
  int _nextId = 0;

  void _write(String message) {
    try {
      _sink('[HTTP] $message');
    } catch (_) {
      // Diagnostics must not change the outcome of a request.
    }
  }

  String _id(RequestOptions options) {
    final id = options.extra[_idKey];
    return id is int && id > 0 ? '$id' : 'unknown';
  }

  String _status(int? status) =>
      status != null && status >= 100 && status <= 599 ? '$status' : 'none';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_idKey] = ++_nextId;
    final method = _methods.contains(options.method) ? options.method : 'OTHER';
    _write('request id=${_id(options)} method=$method');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _write(
      'response id=${_id(response.requestOptions)} '
      'status=${_status(response.statusCode)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _write(
      'error id=${_id(err.requestOptions)} '
      'status=${_status(err.response?.statusCode)}',
    );
    handler.next(err);
  }
}
