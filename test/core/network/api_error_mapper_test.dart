import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_error_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _private = 'synthetic-private-marker';
DioException failure({
  int? status,
  Object? body,
  DioExceptionType type = DioExceptionType.badResponse,
  Object? cause,
  String method = 'GET',
  String? retryAfter,
}) {
  final request = RequestOptions(path: '/$_private', method: method);
  return DioException(
    requestOptions: request,
    type: type,
    error: cause ?? _private,
    message: _private,
    response: status == null
        ? null
        : Response(
            requestOptions: request,
            statusCode: status,
            data: body,
            headers: Headers.fromMap({
              if (retryAfter != null) 'retry-after': [retryAfter],
            }),
          ),
  );
}

void main() {
  for (final entry in {
    400: ApiFailureKind.badRequest,
    401: ApiFailureKind.unauthorized,
    403: ApiFailureKind.forbidden,
    404: ApiFailureKind.notFound,
    409: ApiFailureKind.conflict,
    429: ApiFailureKind.rateLimited,
    500: ApiFailureKind.serverError,
    502: ApiFailureKind.badGateway,
    503: ApiFailureKind.serviceUnavailable,
  }.entries) {
    test('HTTP ${entry.key} has a distinct safe classification', () {
      final mapped = ApiErrorMapper.fromDio(
        failure(status: entry.key, body: {'error': _private}),
      )!;
      expect(mapped.kind, entry.value);
      expect(mapped.statusCode, entry.key);
      expect(mapped.message, isNot(contains(_private)));
      expect(mapped.toString(), isNot(contains(_private)));
      if (entry.key == 401) {
        expect(mapped.actions, {ApiRecoveryAction.signIn});
      }
    });
  }

  final bodies = <Object?>[
    null,
    {},
    {'error': _private},
    '<html>$_private</html>',
    jsonEncode({'error': _private}),
    Uint8List.fromList(utf8.encode(jsonEncode({'error': _private}))),
    Uint8List.fromList([255, 254]),
    [1, 'not bytes'],
    {'error': 42},
    42,
  ];
  for (var i = 0; i < bodies.length; i++) {
    test('untrusted body shape $i neither crashes nor leaks details', () {
      final mapped = ApiErrorMapper.fromDio(
        failure(status: 500, body: bodies[i]),
      )!;
      expect(mapped.kind, ApiFailureKind.serverError);
      expect(mapped.message, 'Внутренняя ошибка сервера.');
    });
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$type is timeout, not a confirmed failed job', () {
      final mapped = ApiErrorMapper.fromDio(failure(type: type))!;
      expect(mapped.kind, ApiFailureKind.timeout);
      expect(mapped.actions, {ApiRecoveryAction.retryRead});
      expect(mapped.message, isNot(contains(_private)));
    });
  }
  test(
    'connection, security, cancellation and unknown failures stay distinct',
    () {
      for (final entry in {
        DioExceptionType.connectionError: ApiFailureKind.networkUnavailable,
        DioExceptionType.badCertificate: ApiFailureKind.transportSecurity,
        DioExceptionType.cancel: ApiFailureKind.cancelled,
        DioExceptionType.unknown: ApiFailureKind.invalidResponse,
      }.entries) {
        final mapped = ApiErrorMapper.fromDio(failure(type: entry.key))!;
        expect(mapped.kind, entry.value);
        expect(mapped.message, isNot(contains(_private)));
        if (entry.key != DioExceptionType.connectionError) {
          expect(mapped.actions, isEmpty);
        }
      }
      expect(
        ApiErrorMapper.fromDio(
          failure(
            type: DioExceptionType.unknown,
            cause: const SocketException(_private),
          ),
        )!.kind,
        ApiFailureKind.networkUnavailable,
      );
    },
  );

  test('incomplete bytes cannot be treated as a complete 200 download', () {
    final mapped = ApiErrorMapper.fromDio(
      failure(status: 200, type: DioExceptionType.connectionError),
      context: const ApiErrorContext(incompleteTransfer: true),
    )!;
    expect(mapped.kind, ApiFailureKind.incompleteTransfer);
    expect(mapped.actions, {ApiRecoveryAction.retryRead});
    expect(mapped.message, contains('Сохранение недоступно'));
  });

  test('known document 404, artifact 503 and generic result 404 differ', () {
    final document = ApiErrorMapper.fromDio(
      failure(status: 404, body: {'error': 'document unavailable'}),
      context: const ApiErrorContext(resource: ApiResource.document),
    )!;
    final artifact = ApiErrorMapper.fromDio(
      failure(
        status: 503,
        body: utf8.encode('{"error":"artifact unavailable"}'),
      ),
      context: const ApiErrorContext(
        resource: ApiResource.structuredTranscript,
      ),
    )!;
    final missingResult = ApiErrorMapper.fromDio(
      failure(status: 404, body: {'error': 'result unavailable'}),
      context: const ApiErrorContext(resource: ApiResource.document),
    )!;
    expect(document.kind, ApiFailureKind.documentUnavailable);
    expect(artifact.kind, ApiFailureKind.artifactUnavailable);
    expect(missingResult.kind, ApiFailureKind.notFound);
    expect(document.actions, {ApiRecoveryAction.retryRead});
    expect(artifact.actions, {ApiRecoveryAction.retryRead});
    expect(missingResult.actions, isEmpty);
  });

  test(
    '202 carries status even for terminal jobs, not an HTTP error or retry',
    () async {
      final adapter = ScriptedAdapter()
        ..enqueue(202, {
          'job_status': 'failed',
          'transcript_status': 'failed',
          'summary_error': 'future-worker-code',
        });
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://fixture.invalid',
          validateStatus: (s) => s == 200,
        ),
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      try {
        await dio.get<Object>('/fixture/structured');
        fail('The fixture validator must surface 202 for mapper inspection');
      } on DioException catch (error) {
        expect(ApiErrorMapper.fromDio(error), isNull);
        expect((error.response!.data as Map)['job_status'], 'failed');
      }
      expect(adapter.requests, hasLength(1));
    },
  );

  test('summary error is open and no unknown code reaches the UI', () {
    expect(ApiErrorMapper.summaryFailureMessage(null), isNull);
    expect(
      ApiErrorMapper.summaryFailureMessage('not_configured'),
      contains('не настроен'),
    );
    for (final value in [_private, 42, {}, 'new-code']) {
      expect(
        ApiErrorMapper.summaryFailureMessage(value),
        'Краткое содержание недоступно.',
      );
    }
  });

  test(
    'Retry-After is optional, validated and supports seconds or HTTP date',
    () {
      final now = DateTime.utc(2026, 10, 27, 12);
      for (final value in <String?>[null, '', '-1', 'not a date', '9' * 40]) {
        expect(
          ApiErrorMapper.fromDio(
            failure(status: 429, retryAfter: value),
            now: now,
          )!.retryAfter,
          isNull,
        );
      }
      expect(
        ApiErrorMapper.fromDio(
          failure(status: 429, retryAfter: '5'),
        )!.retryAfter,
        const Duration(seconds: 5),
      );
      final date = HttpDate.format(now.add(const Duration(seconds: 30)));
      expect(
        ApiErrorMapper.fromDio(
          failure(status: 503, retryAfter: date),
          now: now,
        )!.retryAfter,
        const Duration(seconds: 30),
      );
      expect(
        ApiErrorMapper.fromDio(
          failure(status: 503, retryAfter: date),
          now: now.add(const Duration(minutes: 1)),
        )!.retryAfter,
        isNull,
      );
    },
  );

  test(
    'mutation replay requires the existing same-upload recovery context',
    () {
      for (final status in [429, 500, 502, 503]) {
        final error = failure(status: status, method: 'POST');
        expect(ApiErrorMapper.fromDio(error)!.actions, isEmpty);
        expect(
          ApiErrorMapper.fromDio(
            error,
            context: const ApiErrorContext(hasRecoverableUpload: true),
          )!.actions,
          {ApiRecoveryAction.replaySameUpload},
        );
      }
      for (final status in [400, 403, 404, 409]) {
        expect(
          ApiErrorMapper.fromDio(
            failure(status: status, method: 'POST'),
            context: const ApiErrorContext(hasRecoverableUpload: true),
          )!.actions,
          isEmpty,
        );
      }
      final noRetry = ApiErrorMapper.fromDio(
        failure(status: 503, method: 'DELETE'),
      )!;
      expect(noRetry.actions, isEmpty);
      expect(
        () => noRetry.actions.add(ApiRecoveryAction.retryRead),
        throwsUnsupportedError,
      );
    },
  );

  test('policy violations cannot suggest bypassing TLS or retrying target', () {
    final mapped = ApiErrorMapper.fromDio(
      failure(
        cause: const GatewayPolicyException(),
        type: DioExceptionType.unknown,
      ),
    )!;
    expect(mapped.kind, ApiFailureKind.requestPolicy);
    expect(mapped.actions, isEmpty);
  });

  test('standard IO TLS failures take priority over recovery context', () {
    for (final cause in [
      const HandshakeException(_private),
      const TlsException(_private),
    ]) {
      for (final method in ['GET', 'POST']) {
        final mapped = ApiErrorMapper.fromDio(
          failure(cause: cause, type: DioExceptionType.unknown, method: method),
          context: const ApiErrorContext(
            incompleteTransfer: true,
            hasRecoverableUpload: true,
          ),
        )!;
        expect(mapped.kind, ApiFailureKind.transportSecurity);
        expect(mapped.message, contains('защищённое соединение'));
        expect(mapped.message, isNot(contains(_private)));
        expect(mapped.actions, isEmpty);
      }
    }
    final customValidatorFailure = ApiErrorMapper.fromDio(
      failure(type: DioExceptionType.badCertificate, method: 'POST'),
      context: const ApiErrorContext(
        incompleteTransfer: true,
        hasRecoverableUpload: true,
      ),
    )!;
    expect(customValidatorFailure.kind, ApiFailureKind.transportSecurity);
    expect(customValidatorFailure.actions, isEmpty);
  });
}
