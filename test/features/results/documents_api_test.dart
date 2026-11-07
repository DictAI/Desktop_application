import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/results/data/documents_api.dart';
import 'package:dict_ai/features/results/data/dto/document_kind.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Uint8List wav({int dataBytes = 16000}) {
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String text) =>
      bytes.setRange(offset, offset + text.length, text.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  return bytes;
}

ResponseBody response(
  List<int> bytes, {
  String contentType = 'audio/wav',
  int status = 200,
  int? declaredLength,
  Map<String, List<String>> extraHeaders = const {},
}) => ResponseBody.fromBytes(
  bytes,
  status,
  headers: {
    Headers.contentTypeHeader: [contentType],
    if (declaredLength != null)
      Headers.contentLengthHeader: ['$declaredLength'],
    ...extraHeaders,
  },
);

class _Secrets implements SecretStore {
  int reads = 0;
  int deletes = 0;
  @override
  Future<String?> read(String key) async {
    reads++;
    return key.endsWith('jwt_token') ? 'synthetic-token' : null;
  }

  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {
    deletes++;
  }
}

class _Legacy implements LegacyPreferences {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  late Directory temporary;
  late ScriptedAdapter adapter;
  late Dio dio;
  late DocumentsApi api;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dictai-download-test-');
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    api = DocumentsApi(dio);
  });
  tearDown(() async {
    dio.close(force: true);
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });
  void enqueue(ResponseBody body) => adapter.defer().complete(body);
  Future<void> noPartial() async =>
      expect(await temporary.list().toList(), isEmpty);

  test(
    '401 never subscribes to a body behind asynchronous auth cleanup',
    () async {
      final seen = Completer<void>();
      final allowError = Completer<void>();
      var subscribed = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (error, handler) async {
            seen.complete();
            await allowError.future;
            handler.next(error);
          },
        ),
      );
      enqueue(
        ResponseBody(
          Stream<Uint8List>.multi((controller) {
            subscribed++;
            controller.add(Uint8List(64 * 1024));
            controller.close();
          }),
          401,
        ),
      );
      final result = api.getOriginal('audio', temporaryDirectory: temporary);
      final rejected = expectLater(
        result,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.unauthorized,
          ),
        ),
      );
      await seen.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      final readBeforeCleanup = subscribed;
      allowError.complete();
      await rejected;
      expect(readBeforeCleanup, 0);
      expect(subscribed, 0);
      await noPartial();
    },
  );

  test('dot-segment audio IDs never reach another gateway path', () async {
    for (final id in ['.', '..']) {
      expect(
        () => api.getOriginal(id, temporaryDirectory: temporary),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => api.getDocument(
          id,
          DocumentKind.summaryTxt,
          temporaryDirectory: temporary,
        ),
        throwsA(isA<ValidationException>()),
      );
    }
    expect(adapter.requests, isEmpty);
    await noPartial();
  });

  test(
    'all four documents use exact R05 paths, pinned job and original bytes',
    () async {
      for (final kind in DocumentKind.values) {
        final bytes = utf8.encode(
          kind.contentType == 'application/pdf'
              ? '%PDF-1.4\nSynthetic Speaker 1\n%%EOF\n'
              : '[00:00:00.000000] Speaker 1\nСинтетический текст.\n',
        );
        enqueue(
          response(
            bytes,
            contentType: kind.contentType,
            declaredLength: bytes.length,
          ),
        );
        final result = await api.getDocument(
          'audio-fixture',
          kind,
          temporaryDirectory: temporary,
          jobId: 'job-fixture',
        );
        expect(await result.file.readAsBytes(), bytes);
        expect(result.byteLength, bytes.length);
        expect(result.file.path, endsWith('/${kind.fileName}'));
        expect(
          adapter.requests.last.path,
          '/meetings/results/audio-fixture/documents/${kind.fileName}',
        );
        expect(adapter.requests.last.queryParameters, {
          'job_id': 'job-fixture',
        });
        expect(adapter.requests.last.responseType, ResponseType.stream);
        expect(adapter.requests.last.headers.containsKey('Range'), isFalse);
        await result.delete();
        await result.delete();
        await noPartial();
      }
    },
  );

  test(
    'original chunked WAV without Content-Length is complete and file based',
    () async {
      final bytes = wav();
      enqueue(
        ResponseBody(
          Stream.fromIterable([
            Uint8List.sublistView(bytes, 0, 3),
            Uint8List.sublistView(bytes, 3, 11),
            Uint8List.sublistView(bytes, 11, 500),
            Uint8List.sublistView(bytes, 500),
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      final result = await api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      expect(await result.file.readAsBytes(), bytes);
      expect(result.byteLength, bytes.length);
      expect(result.file.path, endsWith('/original.wav'));
      expect(
        adapter.requests.single.path,
        '/ingest/v2/audio/audio-fixture/original',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(adapter.requests.single.headers['Accept-Encoding'], 'identity');
      await result.delete();
      await noPartial();
    },
  );

  test(
    'same recording downloads own independent files and preserve caller data',
    () async {
      final source = await File(
        '${temporary.path}/user-source.wav',
      ).writeAsBytes(wav());
      enqueue(response(wav()));
      final first = await api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      enqueue(response(wav()));
      final second = await api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      expect(first.file.path, isNot(second.file.path));
      await first.delete();
      expect(await second.file.exists(), isTrue);
      expect(await source.exists(), isTrue);
      await second.delete();
      expect(await source.readAsBytes(), wav());
    },
  );

  test(
    'generated multi-chunk original streams to disk without a full body list',
    () async {
      const payloadBytes = 8 * 1024 * 1024;
      final header = Uint8List.sublistView(wav(), 0, 44);
      ByteData.sublistView(header)
        ..setUint32(4, payloadBytes + 36, Endian.little)
        ..setUint32(40, payloadBytes, Endian.little);
      var produced = 0;
      Stream<Uint8List> chunks() async* {
        yield header;
        for (var offset = 0; offset < payloadBytes; offset += 32768) {
          // Each new chunk is generated lazily, with a network-like event gap.
          await Future<void>.delayed(Duration.zero);
          produced++;
          yield Uint8List(32768);
        }
      }

      enqueue(
        ResponseBody(
          chunks(),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      final result = await api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      expect(result.byteLength, payloadBytes + 44);
      expect(await result.file.length(), payloadBytes + 44);
      expect(produced, 256);
      await result.delete();
    },
  );

  for (final variant in [
    'empty',
    'short header',
    'RIFF truncated',
    'RIFF trailing',
    'bad magic',
    'bad format',
    'declared short',
    'declared long',
    'wrong MIME',
    'JSON instead of WAV',
    'over limit header',
  ]) {
    test('rejects $variant original and purges every partial file', () async {
      final bytes = wav();
      final body = switch (variant) {
        'empty' => response([]),
        'short header' => response(bytes.sublist(0, 8)),
        'RIFF truncated' => response(bytes.sublist(0, bytes.length - 2)),
        'RIFF trailing' => response([...bytes, 0]),
        'bad magic' => response([...bytes]..[0] = 0),
        'bad format' => response([...bytes]..[20] = 99),
        'declared short' => response(bytes, declaredLength: bytes.length - 1),
        'declared long' => response(bytes, declaredLength: bytes.length + 1),
        'wrong MIME' => response(bytes, contentType: 'text/html'),
        'JSON instead of WAV' => response(
          utf8.encode('{"error":"private-fixture"}'),
        ),
        _ => response(bytes, declaredLength: 1073741825),
      };
      enqueue(body);
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(isA<AppException>()),
      );
      await noPartial();
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
    'RIFF truncation at clean chunked EOF is incomplete, never playable',
    () async {
      final bytes = wav();
      enqueue(response(bytes.sublist(0, bytes.length - 10)));
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.incompleteTransfer,
          ),
        ),
      );
      await noPartial();
    },
  );

  test(
    'oversized RIFF declaration aborts a chunked source after its header',
    () async {
      final source = StreamController<Uint8List>();
      final stopped = Completer<void>();
      source.onCancel = () {
        if (!stopped.isCompleted) stopped.complete();
      };
      enqueue(
        ResponseBody(
          source.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      final pending = api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      final header = Uint8List.sublistView(wav(), 0, 12);
      ByteData.sublistView(header).setUint32(4, 1073741824, Endian.little);
      source.add(header);
      await expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
      await stopped.future;
      await source.close();
      await noPartial();
    },
  );

  test(
    'late stream failure after 200 removes partial and preserves retry-read',
    () async {
      final bytes = wav();
      Stream<Uint8List> broken() async* {
        yield Uint8List.sublistView(bytes, 0, 500);
        throw const SocketException('private-fixture');
      }

      enqueue(
        ResponseBody(
          broken(),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', ApiFailureKind.incompleteTransfer)
              .having(
                (e) => e.message,
                'safe',
                isNot(contains('private-fixture')),
              ),
        ),
      );
      await noPartial();
    },
  );

  test(
    'cancellation cleans partial and does not cancel a shared caller token on other failures',
    () async {
      final token = CancelToken();
      final source = StreamController<Uint8List>();
      final stopped = Completer<void>();
      source.onCancel = () {
        if (!stopped.isCompleted) stopped.complete();
      };
      enqueue(
        ResponseBody(
          source.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      final pending = api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
        cancelToken: token,
      );
      await adapter.firstRequest.future;
      source.add(Uint8List.sublistView(wav(), 0, 100));
      token.cancel();
      await expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      await stopped.future;
      await noPartial();
      await source.close();
      final shared = CancelToken();
      enqueue(response(wav(), contentType: 'text/html'));
      await expectLater(
        api.getOriginal(
          'audio-fixture',
          temporaryDirectory: temporary,
          cancelToken: shared,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(shared.isCancelled, isFalse);
      await noPartial();
    },
  );

  test(
    'HTTP error bodies are bounded streams and keep document404 marker',
    () async {
      enqueue(
        response(
          utf8.encode(
            '{"error":"document unavailable","summary_status":"failed"}',
          ),
          status: 404,
          contentType: 'application/json',
        ),
      );
      await expectLater(
        api.getDocument(
          'audio-fixture',
          DocumentKind.summaryPdf,
          temporaryDirectory: temporary,
        ),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', ApiFailureKind.documentUnavailable)
              .having(
                (e) => e.actions,
                'action',
                contains(ApiRecoveryAction.retryRead),
              ),
        ),
      );
      await noPartial();
      enqueue(
        response(
          utf8.encode('{"error":"document not found"}'),
          status: 404,
          contentType: 'application/json',
        ),
      );
      await expectLater(
        api.getDocument(
          'audio-fixture',
          DocumentKind.summaryPdf,
          temporaryDirectory: temporary,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.notFound,
          ),
        ),
      );
      await noPartial();
      final stopped = Completer<void>();
      final source = StreamController<Uint8List>();
      source.onCancel = () {
        if (!stopped.isCompleted) stopped.complete();
      };
      enqueue(
        ResponseBody(
          source.stream,
          404,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );
      final request = api.getDocument(
        'audio-fixture',
        DocumentKind.summaryPdf,
        temporaryDirectory: temporary,
      );
      source.add(Uint8List(16385));
      await expectLater(
        request,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.notFound,
          ),
        ),
      );
      await stopped.future;
      await source.close();
      await noPartial();
    },
  );

  test(
    'headers without a first body chunk time out and release the source',
    () async {
      dio.options.receiveTimeout = const Duration(milliseconds: 20);
      final source = StreamController<Uint8List>();
      final stopped = Completer<void>();
      source.onCancel = () {
        if (!stopped.isCompleted) stopped.complete();
      };
      enqueue(
        ResponseBody(
          source.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
      await stopped.future;
      await source.close();
      await noPartial();
    },
  );

  test(
    'an unreadable stalled error body preserves HTTP status within idle timeout',
    () async {
      dio.options.receiveTimeout = const Duration(milliseconds: 20);
      final source = StreamController<Uint8List>();
      final stopped = Completer<void>();
      source.onCancel = () {
        if (!stopped.isCompleted) stopped.complete();
      };
      enqueue(
        ResponseBody(
          source.stream,
          404,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await expectLater(
        api.getDocument(
          'audio-fixture',
          DocumentKind.summaryPdf,
          temporaryDirectory: temporary,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.notFound,
          ),
        ),
      );
      await stopped.future;
      await source.close();
      await noPartial();
    },
  );

  for (final (code, kind) in [
    (401, ApiFailureKind.unauthorized),
    (403, ApiFailureKind.forbidden),
    (404, ApiFailureKind.notFound),
    (503, ApiFailureKind.serviceUnavailable),
  ]) {
    test('original HTTP $code is safe and never saved as audio', () async {
      enqueue(
        response(
          utf8.encode('<html>private-fixture</html>'),
          status: code,
          contentType: 'text/html',
        ),
      );
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', kind)
              .having(
                (e) => e.message,
                'safe',
                isNot(contains('private-fixture')),
              ),
        ),
      );
      await noPartial();
    });
  }

  test(
    'PDF MIME/magic/status errors and content length failures do not become documents',
    () async {
      for (final body in [
        response(
          utf8.encode('{"error":"private-fixture"}'),
          contentType: 'application/json',
        ),
        response(
          utf8.encode('{"error":"private-fixture"}'),
          contentType: 'application/pdf',
        ),
        response(
          utf8.encode('%PDF-fixture'),
          contentType: 'application/pdf',
          status: 202,
        ),
        response(
          utf8.encode('%PDF-fixture'),
          contentType: 'application/pdf',
          declaredLength: 99,
        ),
        response(
          utf8.encode('%PDF-fixture'),
          contentType: 'application/pdf',
          extraHeaders: {
            Headers.contentLengthHeader: ['bad'],
          },
        ),
        response(
          utf8.encode('%PDF-fixture'),
          contentType: 'application/pdf',
          extraHeaders: {
            Headers.contentLengthHeader: ['12', '12'],
          },
        ),
      ]) {
        enqueue(body);
        await expectLater(
          api.getDocument(
            'audio-fixture',
            DocumentKind.transcriptPdf,
            temporaryDirectory: temporary,
          ),
          throwsA(isA<ApiFailure>()),
        );
        await noPartial();
      }
    },
  );

  test(
    'shared Dio enforces origin before JWT and keeps authorized gateway requests',
    () async {
      dio.close(force: true);
      adapter = ScriptedAdapter();
      final secrets = _Secrets();
      dio = createDio(
        baseUrl: 'https://fixture.invalid',
        storage: SecureStorage(
          secrets: secrets,
          preferences: _Legacy(),
          namespace: 'download-tests',
        ),
      )..httpClientAdapter = adapter;
      api = DocumentsApi(dio);
      enqueue(response(wav()));
      final result = await api.getOriginal(
        'audio-fixture',
        temporaryDirectory: temporary,
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic-token',
      );
      expect(adapter.requests.single.followRedirects, isFalse);
      await result.delete();
      final reads = secrets.reads;
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.path = 'https://foreign.invalid/private';
            handler.next(options);
          },
        ),
      );
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.requestPolicy,
          ),
        ),
      );
      expect(secrets.reads, reads);
      expect(adapter.requests, hasLength(1));
      await noPartial();
    },
  );

  test(
    'common local storage errors and unavailable destination keep safe messages',
    () async {
      const local = ServerException('Local secure storage unavailable');
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(requestOptions: options, error: local),
          ),
        ),
      );
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: temporary),
        throwsA(same(local)),
      );
      await noPartial();
      dio.interceptors.clear();
      final missing = Directory('${temporary.path}/private-fixture/missing');
      await expectLater(
        api.getOriginal('audio-fixture', temporaryDirectory: missing),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'safe',
            isNot(contains('private-fixture')),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'route IDs are encoded, latest has no query, blank pinned job cannot select latest',
    () async {
      enqueue(
        response(
          utf8.encode('Speaker 1'),
          contentType: 'text/plain; charset=utf-8',
        ),
      );
      final result = await api.getDocument(
        'audio/path?query=1',
        DocumentKind.transcriptTxt,
        temporaryDirectory: temporary,
      );
      expect(
        adapter.requests.single.path,
        '/meetings/results/audio%2Fpath%3Fquery%3D1/documents/transcript.txt',
      );
      expect(adapter.requests.single.queryParameters, isEmpty);
      for (final id in ['', ' ', ' job-fixture']) {
        expect(
          () => api.getDocument(
            'audio-fixture',
            DocumentKind.transcriptTxt,
            temporaryDirectory: temporary,
            jobId: id,
          ),
          throwsA(isA<ValidationException>()),
        );
      }
      await result.delete();
      await noPartial();
    },
  );
}
