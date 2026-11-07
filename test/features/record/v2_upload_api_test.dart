import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/record/data/dto/upload_accepted_dto.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/v2_upload_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _audioId = '44444444-4444-4444-8444-444444444444';
const _sessionId = '33333333-3333-4333-8333-333333333333';
const _jobId = '55555555-5555-4555-8555-555555555555';
const _workspaceId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _accepted({bool anonymous = false}) => {
  'audio_id': _audioId,
  'session_id': anonymous ? _sessionId : null,
  'job_id': _jobId,
  'processing_version': 'synthetic-processing-v1',
  'status_url': '/meetings/results/$_audioId/speech-status',
};

UploadOptions _options({
  bool anonymous = false,
  bool mixed = false,
  String key = 'synthetic-fixed-upload-key',
}) => UploadOptions(
  anonymous: anonymous,
  workspaceId: anonymous ? null : _workspaceId,
  idempotencyKey: key,
  source: const ImportedWavUploadSource(),
  language: mixed ? UploadLanguage.auto : UploadLanguage.ru,
  mixed: mixed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SecureStorage();
  late Directory dir;
  late File file;
  late Dio dio;
  late _UploadAdapter adapter;
  late V2UploadApi api;
  late int unauthorizedCalls;

  setUp(() async {
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'synthetic-upload-token',
    });
    unauthorizedCalls = 0;
    adapter = _UploadAdapter();
    dio = createDio(
      baseUrl: 'https://example.invalid',
      storage: storage,
      onUnauthorized: () async {
        unauthorizedCalls++;
      },
    )..httpClientAdapter = adapter;
    api = V2UploadApi(dio);
    dir = await Directory.systemTemp.createTemp('dictai-upload-test-');
    file = File('${dir.path}/speaker sample "é".wav');
    await file.writeAsBytes(_wav());
  });

  tearDown(() async {
    dio.close(force: true);
    await dir.delete(recursive: true);
    resetStorageFakes();
  });

  test(
    'workspace POST overrides JSON and sends JWT/key/exact multipart',
    () async {
      adapter.reply(202, _accepted());
      final result = await api.upload(audioFile: file, options: _options());
      expect(result.audioId, _audioId);
      expect(result.jobId, _jobId);
      expect(result.sessionId, isNull);
      expect(result.processingVersion, 'synthetic-processing-v1');
      expect(result.statusUrl, '/meetings/results/$_audioId/speech-status');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/ingest/v2/audio/upload');
      expect(request.headers['Authorization'], 'Bearer synthetic-upload-token');
      expect(request.headers['Idempotency-Key'], 'synthetic-fixed-upload-key');
      expect(request.contentType, startsWith('multipart/form-data; boundary='));
      expect(request.sendTimeout, AppConfig.uploadTimeout);
      expect(request.receiveTimeout, AppConfig.uploadTimeout);
      expect(request.followRedirects, isFalse);
      expect(dio.options.contentType, Headers.jsonContentType);
      final form = request.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'workspace_id': _workspaceId,
        'language': 'ru',
        'mixed': 'false',
      });
      final part = form.files.single;
      expect(part.key, 'audio');
      expect(part.value.filename, 'speaker sample "é".wav');
      expect(part.value.contentType.toString(), 'audio/wav');
      expect(part.value.length, await file.length());
      final body = latin1.decode(adapter.bodies.single);
      expect(body, contains('name="audio"; filename="speaker sample %22'));
      expect(body, contains('content-type: audio/wav'));
      expect(body, isNot(contains(dir.path)));
      expect(body, isNot(contains('Idempotency-Key')));
      expect(body, contains('RIFF'));
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'anonymous authenticated POST omits workspace and supports mixed auto',
    () async {
      adapter.reply(202, _accepted(anonymous: true));
      final result = await api.upload(
        audioFile: file,
        options: _options(anonymous: true, mixed: true),
      );
      expect(result.sessionId, _sessionId);
      final request = adapter.requests.single;
      expect(request.path, '/ingest/v2/audio/upload/anonymous');
      expect(request.headers['Authorization'], 'Bearer synthetic-upload-token');
      expect(Map.fromEntries((request.data as FormData).fields), {
        'language': '',
        'mixed': 'true',
      });
    },
  );

  test(
    'invalid and unavailable WAV are rejected safely before any POST',
    () async {
      await file.writeAsString('not-a-wav');
      await expectLater(
        api.upload(audioFile: file, options: _options()),
        throwsA(isA<ValidationException>()),
      );
      await file.delete();
      await expectLater(
        api.upload(audioFile: file, options: _options()),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            isNot(contains(dir.path)),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'file data streams in chunks instead of a whole audio byte buffer',
    () async {
      // 1 MiB is a small deterministic IO fixture, not a 1 GiB resource smoke.
      await file.writeAsBytes(_wav(dataBytes: 1024 * 1024));
      adapter.reply(202, _accepted());
      await api.upload(audioFile: file, options: _options());
      final length = await file.length();
      expect(adapter.chunkSizes.length, greaterThan(3));
      expect(adapter.chunkSizes, everyElement(lessThan(length)));
      expect(adapter.bodies.single.length, greaterThan(length));
    },
  );

  test(
    'progress is monotonic sent multipart bytes; acceptance has no progress',
    () async {
      final progress = <(int, int)>[];
      adapter.reply(202, _accepted());
      await api.upload(
        audioFile: file,
        options: _options(),
        onSendProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(progress, isNotEmpty);
      final request = adapter.requests.single;
      final total = (request.data as FormData).length;
      expect(progress.last, (total, total));
      expect(total, greaterThan(await file.length()));
      for (var i = 0; i < progress.length; i++) {
        expect(progress[i].$2, total);
        expect(progress[i].$1, inInclusiveRange(1, total));
        if (i > 0) {
          expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
        }
      }
    },
  );

  test('pre-cancelled upload opens no HTTP request', () async {
    final cancel = CancelToken()..cancel('private cancellation detail');
    await expectLater(
      api.upload(audioFile: file, options: _options(), cancelToken: cancel),
      throwsA(_failure(ApiFailureKind.cancelled)),
    );
    expect(adapter.requests, isEmpty);
  });

  test('cancellation interrupts the multipart send without replay', () async {
    final cancel = CancelToken();
    adapter.reply(202, _accepted());
    await expectLater(
      api.upload(
        audioFile: file,
        options: _options(),
        cancelToken: cancel,
        hasRecoverableUpload: true,
        onSendProgress: (_, _) => cancel.cancel('private cancellation detail'),
      ),
      throwsA(
        _failure(
          ApiFailureKind.cancelled,
        ).having((e) => e.actions, 'actions', isEmpty),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test(
    'cancel after bytes sent does not claim a server job was cancelled',
    () async {
      final deferred = adapter.defer();
      final cancel = CancelToken();
      final future = api.upload(
        audioFile: file,
        options: _options(),
        cancelToken: cancel,
      );
      final assertion = expectLater(
        future,
        throwsA(_failure(ApiFailureKind.cancelled)),
      );
      await adapter.bodyRead.future;
      cancel.cancel();
      await assertion;
      // The server may still have accepted; the API does not issue a cancel API.
      deferred.complete(_reply(202, _accepted()));
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    '409 never replaces key; explicit replay builds a fresh multipart',
    () async {
      final options = _options();
      adapter.reply(409, {'error': 'idempotency_conflict'});
      await expectLater(
        api.upload(
          audioFile: file,
          options: options,
          hasRecoverableUpload: true,
        ),
        throwsA(
          _failure(
            ApiFailureKind.conflict,
          ).having((e) => e.actions, 'actions', isEmpty),
        ),
      );
      expect(adapter.requests, hasLength(1));
      adapter.reply(202, _accepted());
      await api.upload(
        audioFile: file,
        options: options,
        hasRecoverableUpload: true,
      );
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.map((r) => r.headers['Idempotency-Key']),
        everyElement(options.idempotencyKey),
      );
      expect(
        identical(adapter.requests[0].data, adapter.requests[1].data),
        isFalse,
      );
      expect(
        Map.fromEntries((adapter.requests[0].data as FormData).fields),
        Map.fromEntries((adapter.requests[1].data as FormData).fields),
      );
    },
  );

  for (final (status, kind) in [
    (400, ApiFailureKind.badRequest),
    (401, ApiFailureKind.unauthorized),
    (403, ApiFailureKind.forbidden),
    (409, ApiFailureKind.conflict),
    (429, ApiFailureKind.rateLimited),
    (502, ApiFailureKind.badGateway),
    (503, ApiFailureKind.serviceUnavailable),
  ]) {
    test('HTTP $status maps safely even with non-JSON body', () async {
      adapter.reply(
        status,
        '<html>private backend details</html>',
        contentType: 'text/html',
        headers: {
          'retry-after': ['5'],
        },
      );
      await expectLater(
        api.upload(
          audioFile: file,
          options: _options(),
          hasRecoverableUpload: true,
        ),
        throwsA(
          _failure(kind)
              .having((e) => e.statusCode, 'status', status)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('private')),
              )
              .having(
                (e) => e.retryAfter,
                'retry after',
                status == 429 || status == 503
                    ? const Duration(seconds: 5)
                    : isNull,
              ),
        ),
      );
      expect(adapter.requests, hasLength(1));
      if (status == 401) {
        expect(await storage.getToken(), isNull);
        expect(unauthorizedCalls, 1);
      }
    });
  }

  test(
    '429 honors valid Retry-After but never schedules its own retry',
    () async {
      adapter.reply(
        429,
        {'error': 'upload_busy'},
        headers: {
          'retry-after': ['5'],
        },
      );
      await expectLater(
        api.upload(
          audioFile: file,
          options: _options(),
          hasRecoverableUpload: true,
        ),
        throwsA(
          _failure(ApiFailureKind.rateLimited)
              .having(
                (e) => e.retryAfter,
                'retry after',
                const Duration(seconds: 5),
              )
              .having((e) => e.actions, 'actions', {
                ApiRecoveryAction.replaySameUpload,
              }),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'malformed JSON error bodies preserve the real HTTP failure status',
    () async {
      for (final (status, kind) in [
        (400, ApiFailureKind.badRequest),
        (502, ApiFailureKind.badGateway),
        (503, ApiFailureKind.serviceUnavailable),
      ]) {
        adapter.reply(status, '<html>private non-JSON error</html>');
        await expectLater(
          api.upload(audioFile: file, options: _options()),
          throwsA(_failure(kind).having((e) => e.statusCode, 'status', status)),
        );
      }
    },
  );

  test(
    'rejects keys incompatible with a native HTTP header before POST',
    () async {
      for (final key in ['clé', 'ключ', 'upload\u000bkey', 'upload\u007fkey']) {
        await expectLater(
          api.upload(
            audioFile: file,
            options: _options(key: key),
          ),
          throwsA(
            isA<ValidationException>().having(
              (error) => error.message,
              'safe message',
              isNot(contains(key)),
            ),
          ),
        );
      }
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'sends the exact compatible key including interior spaces and TAB',
    () async {
      const key = 'upload\tkey ~';
      adapter.reply(202, _accepted());
      await api.upload(
        audioFile: file,
        options: _options(key: key),
      );
      expect(adapter.requests.single.headers['Idempotency-Key'], key);
    },
  );

  test(
    'rejects malformed UTF-8 in 202 but preserves valid Unicode versions',
    () async {
      final payload = jsonEncode(_accepted());
      final malformed = Uint8List.fromList(utf8.encode(payload))
        ..[payload.indexOf('synthetic-processing-v1')] = 0xff;
      adapter.reply(202, malformed);
      await expectLater(
        api.upload(audioFile: file, options: _options()),
        throwsA(
          _failure(
            ApiFailureKind.invalidResponse,
          ).having((error) => error.statusCode, 'status', 202),
        ),
      );

      const version = 'синтетическая-версия-\ufffd';
      adapter.reply(202, _accepted()..['processing_version'] = version);
      final accepted = await api.upload(audioFile: file, options: _options());
      expect(accepted.processingVersion, version);
    },
  );

  test(
    'invalid UTF-8 in an HTTP error preserves status and Retry-After',
    () async {
      adapter.reply(
        429,
        Uint8List.fromList([0xff, 0xfe]),
        headers: {
          'retry-after': ['5'],
        },
      );
      await expectLater(
        api.upload(audioFile: file, options: _options()),
        throwsA(
          _failure(ApiFailureKind.rateLimited)
              .having((error) => error.statusCode, 'status', 429)
              .having(
                (error) => error.retryAfter,
                'retry after',
                const Duration(seconds: 5),
              ),
        ),
      );
    },
  );

  for (final (type, kind) in [
    (DioExceptionType.receiveTimeout, ApiFailureKind.timeout),
    (DioExceptionType.sendTimeout, ApiFailureKind.timeout),
    (DioExceptionType.connectionError, ApiFailureKind.networkUnavailable),
    (DioExceptionType.badCertificate, ApiFailureKind.transportSecurity),
  ]) {
    test(
      'lost/failed transport $type stays distinct and only hints durable replay',
      () async {
        for (final durable in [false, true]) {
          adapter.fail(type);
          await expectLater(
            api.upload(
              audioFile: file,
              options: _options(),
              hasRecoverableUpload: durable,
            ),
            throwsA(
              _failure(kind).having(
                (e) => e.actions,
                'actions',
                durable && kind != ApiFailureKind.transportSecurity
                    ? {ApiRecoveryAction.replaySameUpload}
                    : isEmpty,
              ),
            ),
          );
        }
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests.map((r) => r.headers['Idempotency-Key']),
          everyElement('synthetic-fixed-upload-key'),
        );
      },
    );
  }

  test(
    'unexpected successful status and malformed 202 body are not accepted',
    () async {
      for (final status in [200, 201, 204]) {
        adapter.reply(status, _accepted());
        await expectLater(
          api.upload(audioFile: file, options: _options()),
          throwsA(_failure(ApiFailureKind.invalidResponse)),
        );
      }
      for (final value in [
        null,
        [],
        'not JSON',
        '<html>private response</html>',
      ]) {
        adapter.reply(202, value);
        await expectLater(
          api.upload(audioFile: file, options: _options()),
          throwsA(_failure(ApiFailureKind.invalidResponse)),
        );
      }
    },
  );

  test(
    'session nullability matches the endpoint rather than inventing a session',
    () async {
      adapter.reply(202, _accepted(anonymous: true));
      await expectLater(
        api.upload(audioFile: file, options: _options()),
        throwsA(_failure(ApiFailureKind.invalidResponse)),
      );
      adapter.reply(202, _accepted());
      await expectLater(
        api.upload(audioFile: file, options: _options(anonymous: true)),
        throwsA(_failure(ApiFailureKind.invalidResponse)),
      );
    },
  );

  group('accepted DTO required fields', () {
    final malformed = <String, Map<String, dynamic>>{
      'missing session': _accepted()..remove('session_id'),
      'missing audio': _accepted()..remove('audio_id'),
      'missing job': _accepted()..remove('job_id'),
      'missing version': _accepted()..remove('processing_version'),
      'missing status URL': _accepted()..remove('status_url'),
      'wrong audio type': _accepted()..['audio_id'] = 12,
      'invalid audio UUID': _accepted()..['audio_id'] = 'audio',
      'invalid job UUID': _accepted()..['job_id'] = 'job',
      'wrong session type': _accepted()..['session_id'] = false,
      'empty session': _accepted()..['session_id'] = '',
      'empty version': _accepted()..['processing_version'] = '',
      'newline version': _accepted()..['processing_version'] = 'v1\nprivate',
      'oversized UTF8 version': _accepted()..['processing_version'] = 'я' * 65,
      'foreign status URL': _accepted()
        ..['status_url'] = 'https://foreign.invalid/private',
      'mismatched audio URL': _accepted()
        ..['status_url'] = '/meetings/results/$_jobId/speech-status',
      'injected status query': _accepted()
        ..['status_url'] =
            '/meetings/results/$_audioId/speech-status?job_id=other',
    };
    for (final entry in malformed.entries) {
      test('rejects ${entry.key} in a complete 202 response', () async {
        expect(
          () => UploadAcceptedDto.fromJson(entry.value),
          throwsFormatException,
        );
        adapter.reply(202, entry.value);
        await expectLater(
          api.upload(audioFile: file, options: _options()),
          throwsA(_failure(ApiFailureKind.invalidResponse)),
        );
      });
    }

    test(
      'ignores additive fields, preserves exact processing version and IDs',
      () {
        final json = _accepted()
          ..addAll({
            'future_field': {'value': true},
          });
        final result = UploadAcceptedDto.fromJson(json);
        expect(result.audioId, _audioId);
        expect(result.jobId, _jobId);
        expect(result.processingVersion, json['processing_version']);
        expect(result.sessionId, isNull);
      },
    );
  });
}

TypeMatcher<ApiFailure> _failure(ApiFailureKind kind) =>
    isA<ApiFailure>().having((e) => e.kind, 'kind', kind);

/// Test-only transport that consumes the real multipart stream, never sockets.
final class _UploadAdapter implements HttpClientAdapter {
  final _responses = Queue<_ScriptedUpload>();
  final requests = <RequestOptions>[];
  final bodies = <Uint8List>[];
  final chunkSizes = <int>[];
  final bodyRead = Completer<void>();

  void reply(
    int status,
    Object? body, {
    String contentType = 'application/json',
    Map<String, List<String>>? headers,
  }) => _responses.add(
    _ScriptedUpload(
      response: Future.value(
        _reply(status, body, contentType: contentType, headers: headers),
      ),
    ),
  );

  void fail(DioExceptionType type) =>
      _responses.add(_ScriptedUpload(failure: type));

  Completer<ResponseBody> defer() {
    final completer = Completer<ResponseBody>();
    _responses.add(_ScriptedUpload(response: completer.future));
    return completer;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_responses.isEmpty) {
      throw StateError('Missing scripted upload response');
    }
    final scripted = _responses.removeFirst();
    final builder = BytesBuilder();
    await for (final bytes in requestStream!) {
      chunkSizes.add(bytes.length);
      builder.add(bytes);
    }
    bodies.add(builder.takeBytes());
    if (!bodyRead.isCompleted) bodyRead.complete();
    if (scripted.failure != null) {
      throw DioException(
        requestOptions: options,
        type: scripted.failure!,
        message: 'private transport details',
      );
    }
    return scripted.response!;
  }

  @override
  void close({bool force = false}) {}
}

final class _ScriptedUpload {
  const _ScriptedUpload({this.response, this.failure});
  final Future<ResponseBody>? response;
  final DioExceptionType? failure;
}

ResponseBody _reply(
  int status,
  Object? body, {
  String contentType = 'application/json',
  Map<String, List<String>>? headers,
}) {
  final responseHeaders = {
    Headers.contentTypeHeader: [contentType],
    ...?headers,
  };
  if (body is Uint8List) {
    return ResponseBody.fromBytes(body, status, headers: responseHeaders);
  }
  return ResponseBody.fromString(
    body is String ? body : jsonEncode(body),
    status,
    headers: responseHeaders,
  );
}

Uint8List _wav({int dataBytes = 64}) {
  final bytes = Uint8List(44 + dataBytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  bytes.setRange(36, 40, 'data'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(4, bytes.length - 8, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 8000, Endian.little)
    ..setUint32(28, 16000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(40, dataBytes, Endian.little);
  return bytes;
}
