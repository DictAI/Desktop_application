import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../error/app_exception.dart';

enum ApiResource { general, document, structuredTranscript }

/// Facts known by the caller, not inferred from untrusted URLs or error bodies.
final class ApiErrorContext {
  const ApiErrorContext({
    this.resource = ApiResource.general,
    this.hasRecoverableUpload = false,
    this.incompleteTransfer = false,
  });
  final ApiResource resource;

  /// True only for an existing durable V2 upload with the SAME bytes, metadata
  /// and idempotency key. Never means create a job or reprocess a result.
  final bool hasRecoverableUpload;

  /// Set after a caller confirms truncation/incomplete local transfer.
  final bool incompleteTransfer;
}

abstract final class ApiErrorMapper {
  /// Null means a complete 2xx response, including 202: consume its DTO/status.
  /// 202 may contain a failed/cancelled job; it does not imply "keep waiting".
  /// Feature-client adoption is separate from this reusable foundation.
  static ApiFailure? fromDio(
    DioException error, {
    ApiErrorContext context = const ApiErrorContext(),
    DateTime? now,
  }) {
    final rawStatus = error.response?.statusCode;
    final status = rawStatus != null && rawStatus >= 100 && rawStatus <= 599
        ? rawStatus
        : null;
    ApiFailureKind kind;
    String message;
    if (error.error is GatewayPolicyException) {
      kind = ApiFailureKind.requestPolicy;
      message = 'Адрес запроса не соответствует настройкам сервера.';
    } else if (error.type == DioExceptionType.badCertificate ||
        error.error is TlsException) {
      // The standard IO adapter wraps PKI/handshake failures as unknown.
      // Security failures must never become replayable incomplete transfers.
      kind = ApiFailureKind.transportSecurity;
      message = 'Не удалось проверить защищённое соединение с сервером.';
    } else if (context.incompleteTransfer) {
      kind = ApiFailureKind.incompleteTransfer;
      message = 'Файл получен не полностью. Сохранение недоступно.';
    } else if ({
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    }.contains(error.type)) {
      kind = ApiFailureKind.timeout;
      message =
          'Сервер не ответил вовремя. Результат операции может быть неизвестен.';
    } else if (error.type == DioExceptionType.cancel) {
      kind = ApiFailureKind.cancelled;
      message =
          'Запрос приложения прерван. Серверная обработка могла продолжиться.';
    } else if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      kind = ApiFailureKind.networkUnavailable;
      message = 'Не удалось связаться с сервером. Проверьте подключение.';
    } else if (error.type == DioExceptionType.badResponse && status != null) {
      if (status >= 200 && status < 300) return null;
      final code = _errorCode(error.response?.data);
      (kind, message) = switch (status) {
        400 => (
          ApiFailureKind.badRequest,
          'Сервер отклонил параметры запроса.',
        ),
        401 => (
          ApiFailureKind.unauthorized,
          'Сессия недействительна. Войдите снова.',
        ),
        403 => (
          ApiFailureKind.forbidden,
          'Недостаточно прав для этого действия.',
        ),
        404
            when context.resource == ApiResource.document &&
                code == 'document unavailable' =>
          (
            ApiFailureKind.documentUnavailable,
            'Документ пока недоступен. Проверьте состояние записи.',
          ),
        404 => (
          ApiFailureKind.notFound,
          'Запрошенные данные не найдены или недоступны.',
        ),
        409 => (
          ApiFailureKind.conflict,
          'Запрос конфликтует с существующими данными.',
        ),
        429 => (
          ApiFailureKind.rateLimited,
          'Сервер ограничил частоту запросов.',
        ),
        500 => (ApiFailureKind.serverError, 'Внутренняя ошибка сервера.'),
        502 => (
          ApiFailureKind.badGateway,
          'Сервис за шлюзом временно недоступен.',
        ),
        503
            when context.resource == ApiResource.structuredTranscript &&
                code == 'artifact unavailable' =>
          (
            ApiFailureKind.artifactUnavailable,
            'Содержимое транскрипта временно недоступно.',
          ),
        503 => (
          ApiFailureKind.serviceUnavailable,
          'Сервис временно недоступен.',
        ),
        _ => (
          ApiFailureKind.invalidResponse,
          'Сервер вернул неожиданный ответ.',
        ),
      };
    } else {
      kind = ApiFailureKind.invalidResponse;
      message = 'Не удалось прочитать ответ сервера.';
    }

    final actions = <ApiRecoveryAction>{};
    if (kind == ApiFailureKind.unauthorized) {
      actions.add(ApiRecoveryAction.signIn);
    } else if (_retryable.contains(kind)) {
      final method = error.requestOptions.method.toUpperCase();
      if (method == 'GET' || method == 'HEAD') {
        actions.add(ApiRecoveryAction.retryRead);
      } else if (method == 'POST' && context.hasRecoverableUpload) {
        actions.add(ApiRecoveryAction.replaySameUpload);
      }
    }
    return ApiFailure(
      message,
      kind: kind,
      statusCode: status,
      actions: actions,
      retryAfter: (status == 429 || status == 503)
          ? _retryAfter(error.response?.headers, now ?? DateTime.now().toUtc())
          : null,
    );
  }

  static const _retryable = {
    ApiFailureKind.documentUnavailable,
    ApiFailureKind.artifactUnavailable,
    ApiFailureKind.rateLimited,
    ApiFailureKind.serverError,
    ApiFailureKind.badGateway,
    ApiFailureKind.serviceUnavailable,
    ApiFailureKind.timeout,
    ApiFailureKind.networkUnavailable,
    ApiFailureKind.incompleteTransfer,
  };

  /// summary_error stays an open string in the future DTO. Never echo its value.
  static String? summaryFailureMessage(Object? code) => switch (code) {
    null => null,
    'not_configured' => 'Сервис краткого содержания не настроен.',
    'input_limit' ||
    'output_limit' => 'Краткое содержание недоступно из-за ограничения модели.',
    'retry_exhausted' => 'Сервис не смог подготовить краткое содержание.',
    'document_failure' =>
      'Не удалось подготовить документ с кратким содержанием.',
    _ => 'Краткое содержание недоступно.',
  };

  // Recognize only exact documented markers, never render backend messages.
  // Error bodies may be empty, text/html, JSON, or bytes (download clients).
  static String? _errorCode(Object? body) {
    try {
      if (body is List<int>) {
        if (body.length > 16384) return null;
        body = utf8.decode(body);
      }
      if (body is String) {
        if (body.length > 16384) return null;
        body = jsonDecode(body);
      }
      if (body is! Map) return null;
      final code = body['error'];
      return code is String && code.length <= 128 ? code : null;
    } catch (_) {
      return null;
    }
  }

  static Duration? _retryAfter(Headers? headers, DateTime now) {
    final values = headers?['retry-after'];
    if (values == null || values.length != 1) return null;
    final value = values.single.trim();
    final seconds = int.tryParse(value);
    if (seconds != null) {
      if (seconds < 0 || seconds > 2147483647) return null;
      return Duration(seconds: seconds);
    }
    try {
      final duration = HttpDate.parse(value).difference(now.toUtc());
      return duration.isNegative ? null : duration;
    } catch (_) {
      return null;
    }
  }
}
