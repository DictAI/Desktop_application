import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/record/data/v2_upload_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
const _workspaceId = '33333333-3333-4333-8333-333333333333';
const _audioId = '44444444-4444-4444-8444-444444444444';
const _jobId = '55555555-5555-4555-8555-555555555555';
const _sessionId = '66666666-6666-4666-8666-666666666666';

UploadOptions _options({String key = 'original-key', bool anonymous = false}) =>
    UploadOptions(
      anonymous: anonymous,
      workspaceId: anonymous ? null : _workspaceId,
      idempotencyKey: key,
      source: RecordingUploadSource(
        microphoneDeviceId: 'synthetic-device-id',
        captureSystemAudio: true,
      ),
      language: anonymous ? UploadLanguage.auto : UploadLanguage.ru,
      mixed: anonymous,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Directory support;
  late File source;
  late bool current;
  late Dio dio;
  late _Transport transport;
  late V2UploadApi api;

  PendingUploadStore store({
    String owner = _ownerA,
    bool Function()? session,
    int maxBytes = 1024 * 1024,
    int maxEntries = 8,
  }) => PendingUploadStore(
    ownerId: owner,
    isCurrentSession: session ?? () => current,
    applicationSupportDirectory: () async => support,
    maxSourceBytes: maxBytes,
    maxEntries: maxEntries,
  );

  String ownerPath([String owner = _ownerA]) =>
      '${support.path}/dictai-pending-v1/$owner';
  String entryPath(String id) => '${ownerPath()}/$id';
  File audio(String id) => File('${entryPath(id)}/source.wav');
  File metadata(String id) => File('${entryPath(id)}/upload.json');

  Future<PendingUpload> prepare(
    PendingUploadStore journal, {
    String key = 'original-key',
  }) => journal.prepare(
    source: source,
    options: _options(key: key),
  );

  Future<PendingUpload> submit(PendingUploadStore journal, String id) =>
      journal.submit(id, api: api, cancelToken: CancelToken());

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dictai-upload-journal-test-');
    support = Directory('${temp.path}/support');
    source = File('${temp.path}/user-import.wav');
    await source.writeAsBytes(_wav());
    current = true;
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'synthetic-test-token',
    });
    transport = _Transport();
    dio = createDio(
      baseUrl: 'https://example.invalid',
      storage: const SecureStorage(),
    )..httpClientAdapter = transport;
    api = V2UploadApi(dio);
  });

  tearDown(() async {
    dio.close(force: true);
    resetStorageFakes();
    await temp.delete(recursive: true);
  });

  test(
    'owner switch during journal lock close cannot publish old entries',
    () async {
      await prepare(store());
      var checks = 0;
      final journal = store(
        session: () {
          if (++checks == 7) scheduleMicrotask(() => current = false);
          return current;
        },
      );
      await expectLater(journal.list(), throwsA(isA<UnauthorizedException>()));
      expect(current, isFalse);
      expect((await store(session: () => true).list()).entries, hasLength(1));
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'owner switch during submit cleanup cannot publish an old accepted job',
    () async {
      final entry = await prepare(store());
      transport.accept();
      await submit(store(), entry.localId);
      var checks = 0;
      final journal = store(
        session: () {
          if (++checks == 8) scheduleMicrotask(() => current = false);
          return current;
        },
      );
      await expectLater(
        submit(journal, entry.localId),
        throwsA(isA<UnauthorizedException>()),
      );
      final restored = (await store(session: () => true).list()).entries.single;
      expect(restored.accepted!.jobId, _jobId);
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'prepare atomically persists owned bytes and immutable options before HTTP',
    () async {
      final entry = await prepare(store());
      final expected = await source.readAsBytes();
      expect(transport.requests, isEmpty);
      expect(entry.state, PendingUploadState.pending);
      expect(entry.accepted, isNull);
      expect(entry.localId, isNot(_audioId));
      expect(await audio(entry.localId).readAsBytes(), expected);
      final raw = await metadata(entry.localId).readAsString();
      expect(raw, isNot(contains('synthetic-test-token')));
      expect(raw, isNot(contains(source.path)));
      expect(raw, isNot(contains('user-import.wav')));

      await source.writeAsBytes(_wav(dataBytes: 96));
      final restored = (await store().list()).entries.single;
      expect(restored.localId, entry.localId);
      expect(restored.options.idempotencyKey, 'original-key');
      expect(restored.options.workspaceId, _workspaceId);
      expect(restored.options.language, UploadLanguage.ru);
      final capture = restored.options.source as RecordingUploadSource;
      expect(capture.microphoneDeviceId, 'synthetic-device-id');
      expect(capture.captureSystemAudio, isTrue);
      expect(await audio(entry.localId).readAsBytes(), expected);
    },
  );

  test(
    'SHA-256 matches independent fixtures at padding and stream boundaries',
    () async {
      const vectors = {
        10: 'fd9d9fe12e9457714f0e3927dca15555a4a6f2e56359cd1b96b04b54db1b4a40',
        12: 'e23b78e00cf155f408398a8a243db7f6a6eee4409d7b5747e2e07b4907add2ff',
        20: 'bca62ea9d071a60bbca916213fc7af9454efa0dab36590c507ecff933ad2a2c3',
        131086:
            '7b66d232cc0f5c279a6b9b63c4ed458ade0dd8f2ba88885c3965cc4c9b832cb8',
      };
      for (final vector in vectors.entries) {
        await source.writeAsBytes(_wav(dataBytes: vector.key));
        final entry = await prepare(store(), key: 'vector-${vector.key}');
        expect(entry.sha256, vector.value);
        expect(entry.byteCount, vector.key + 44);
      }
    },
  );

  for (final anonymous in [false, true]) {
    test(
      'lost response replays exact bytes/key and accepted becomes poll-only ($anonymous)',
      () async {
        final expected = await source.readAsBytes();
        final journal = store();
        final entry = await journal.prepare(
          source: source,
          options: _options(anonymous: anonymous),
        );
        transport.loseResponse();
        await expectLater(
          submit(journal, entry.localId),
          throwsA(
            _failure(ApiFailureKind.timeout).having(
              (e) => e.actions,
              'actions',
              {ApiRecoveryAction.replaySameUpload},
            ),
          ),
        );
        expect(
          (await store().list()).entries.single.state,
          PendingUploadState.pending,
        );
        expect(await audio(entry.localId).exists(), isTrue);
        await source.writeAsBytes(_wav(dataBytes: 96));

        transport.accept(anonymous: anonymous);
        final accepted = await submit(store(), entry.localId);
        expect(accepted.state, PendingUploadState.accepted);
        expect(accepted.accepted!.audioId, _audioId);
        expect(accepted.accepted!.jobId, _jobId);
        expect(accepted.accepted!.sessionId, anonymous ? _sessionId : null);
        expect(accepted.accepted!.processingVersion, 'processing-v1');
        expect(
          accepted.accepted!.statusUrl,
          '/meetings/results/$_audioId/speech-status',
        );
        expect(await audio(entry.localId).exists(), isFalse);
        expect(await source.exists(), isTrue);
        expect(
          transport.requests.map((r) => r.headers['Idempotency-Key']),
          everyElement('original-key'),
        );
        expect(transport.audioBytes, [expected, expected]);
        expect(transport.fields[0], transport.fields[1]);
        expect(transport.fields.first, entry.options.toMultipartFields());
        expect(
          transport.requests.first.path,
          anonymous
              ? '/ingest/v2/audio/upload/anonymous'
              : '/ingest/v2/audio/upload',
        );

        final pollOnly = await submit(store(), entry.localId);
        expect(pollOnly.accepted!.jobId, _jobId);
        expect(transport.requests, hasLength(2));
      },
    );
  }

  test(
    '409 persists conflict, preserves source and rejects further sends',
    () async {
      final entry = await prepare(store());
      transport.conflict();
      await expectLater(
        submit(store(), entry.localId),
        throwsA(_failure(ApiFailureKind.conflict)),
      );
      expect(
        (await store().list()).entries.single.state,
        PendingUploadState.conflict,
      );
      expect(await audio(entry.localId).exists(), isTrue);
      await expectLater(
        submit(store(), entry.localId),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        store().forgetAccepted(entry.localId),
        throwsA(isA<ValidationException>()),
      );
      expect(transport.requests, hasLength(1));
      expect(await source.exists(), isTrue);
    },
  );

  for (final scenario in [
    'same-size mutation',
    'missing file',
    'source symlink',
  ]) {
    test('$scenario blocks replay before network', () async {
      final entry = await prepare(store());
      final saved = audio(entry.localId);
      switch (scenario) {
        case 'same-size mutation':
          final bytes = await saved.readAsBytes();
          bytes[bytes.length - 1] ^= 1;
          await saved.writeAsBytes(bytes);
          expect(await saved.length(), entry.byteCount);
        case 'missing file':
          await saved.delete();
        case 'source symlink':
          await saved.delete();
          await Link(saved.path).create(source.path);
      }
      await expectLater(
        submit(store(), entry.localId),
        throwsA(isA<ValidationException>()),
      );
      expect(transport.requests, isEmpty);
      expect(
        (await store().list()).entries.single.state,
        PendingUploadState.pending,
      );
      expect(await source.exists(), isTrue);
    });
  }

  test(
    'owner namespace isolates list/send/cleanup and rejects traversal',
    () async {
      final entry = await prepare(store());
      final other = store(owner: _ownerB);
      expect((await other.list()).entries, isEmpty);
      await other.cleanup();
      expect(await audio(entry.localId).exists(), isTrue);
      await expectLater(
        submit(other, entry.localId),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        submit(store(), '../${entry.localId}'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => store(owner: '../owner'),
        throwsA(isA<ValidationException>()),
      );
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'expired session during prepare cannot commit the staged entry',
    () async {
      final journal = store(
        session: () {
          final dir = Directory(ownerPath());
          return !dir.existsSync() ||
              !dir.listSync().any((e) => e.path.contains('/.stage-'));
        },
      );
      await expectLater(
        prepare(journal),
        throwsA(isA<UnauthorizedException>()),
      );
      expect((await store().list()).entries, isEmpty);
      expect(
        Directory(
          ownerPath(),
        ).listSync().any((e) => e.path.contains('/.stage-')),
        isFalse,
      );
      expect(await source.exists(), isTrue);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'expired session before accepted commit preserves pending identity',
    () async {
      final entry = await prepare(store());
      final response = transport.defer();
      final attempt = expectLater(
        submit(store(), entry.localId),
        throwsA(isA<UnauthorizedException>()),
      );
      await transport.firstRequest.future;
      current = false;
      response.complete(_accepted());
      await attempt;
      await expectLater(store().list(), throwsA(isA<UnauthorizedException>()));
      final restored = (await store(session: () => true).list()).entries.single;
      expect(restored.state, PendingUploadState.pending);
      expect(restored.options.idempotencyKey, entry.options.idempotencyKey);
      expect(await audio(entry.localId).exists(), isTrue);
    },
  );

  test(
    'concurrent submit allows a read but emits one request for the entry',
    () async {
      final entry = await prepare(store());
      final response = transport.defer();
      final first = submit(store(), entry.localId);
      await transport.firstRequest.future;
      expect(
        (await store().list()).entries.single.state,
        PendingUploadState.pending,
      );
      await expectLater(
        submit(store(), entry.localId),
        throwsA(isA<ValidationException>()),
      );
      expect(transport.requests, hasLength(1));
      response.complete(_accepted());
      expect((await first).state, PendingUploadState.accepted);
      expect((await submit(store(), entry.localId)).accepted!.jobId, _jobId);
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'concurrent preparations with the same key create a single durable entry',
    () async {
      Future<Object> result(Future<PendingUpload> work) =>
          work.then<Object>((value) => value, onError: (Object e) => e);
      final results = await Future.wait([
        result(prepare(store())),
        result(prepare(store())),
      ]);
      expect(results.whereType<PendingUpload>(), hasLength(1));
      expect(results.whereType<ValidationException>(), hasLength(1));
      expect((await store().list()).entries, hasLength(1));
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'byte quota keeps unresolved audio and frees space after accepted commit',
    () async {
      final journal = store(maxBytes: await source.length());
      final entry = await prepare(journal);
      await expectLater(
        prepare(journal, key: 'next-key'),
        throwsA(isA<ValidationException>()),
      );
      expect(await audio(entry.localId).exists(), isTrue);
      transport.accept();
      await submit(journal, entry.localId);
      final next = await prepare(journal, key: 'next-key');
      expect(next.localId, isNot(entry.localId));
      expect((await journal.list()).entries, hasLength(2));
    },
  );

  test('entry quota can be released by explicit accepted cleanup', () async {
    final journal = store(maxEntries: 1);
    final entry = await prepare(journal);
    transport.accept();
    await submit(journal, entry.localId);
    await expectLater(
      prepare(journal, key: 'next-key'),
      throwsA(isA<ValidationException>()),
    );
    await journal.forgetAccepted(entry.localId);
    expect((await journal.list()).entries, isEmpty);
    await prepare(journal, key: 'next-key');
    expect(await source.exists(), isTrue);
  });

  test(
    'corrupt entry isolation and restart cleanup preserve other drafts',
    () async {
      final corrupt = await prepare(store());
      final intact = await prepare(store(), key: 'intact-key');
      final accepted = await prepare(store(), key: 'accepted-key');
      transport.accept();
      await submit(store(), accepted.localId);
      await source.copy(audio(accepted.localId).path);
      await metadata(corrupt.localId).writeAsString('{"version":');
      final stage = Directory(
        '${ownerPath()}/.stage-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      await stage.create();
      await source.copy('${stage.path}/source.wav');
      final restored = store();
      final before = await restored.list();
      expect(before.damagedEntries, 1);
      expect(
        before.entries.map((e) => e.localId),
        containsAll([intact.localId, accepted.localId]),
      );
      await restored.cleanup();
      expect(await stage.exists(), isFalse);
      expect(await audio(accepted.localId).exists(), isFalse);
      expect(await audio(intact.localId).exists(), isTrue);
      expect(await audio(corrupt.localId).exists(), isTrue);
      await expectLater(
        submit(restored, corrupt.localId),
        throwsA(isA<ValidationException>()),
      );
      expect(transport.requests, hasLength(1));
    },
  );

  test('valid JSON with a changed idempotency key cannot replay', () async {
    final entry = await prepare(store());
    final file = metadata(entry.localId);
    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final payload = envelope['entry'] as Map<String, dynamic>;
    final options = payload['options'] as Map<String, dynamic>;
    options['idempotency_key'] = 'changed-key';
    await file.writeAsString(jsonEncode(envelope));

    final result = await store().list();
    expect(result.entries, isEmpty);
    expect(result.damagedEntries, 1);
    await expectLater(
      submit(store(), entry.localId),
      throwsA(isA<ValidationException>()),
    );
    expect(transport.requests, isEmpty);
    expect(await audio(entry.localId).exists(), isTrue);
  });

  test(
    'HTTP-incompatible key never becomes an unsendable durable draft',
    () async {
      await expectLater(
        prepare(store(), key: 'ключ'),
        throwsA(isA<ValidationException>()),
      );
      expect((await store().list()).entries, isEmpty);
      expect(await source.exists(), isTrue);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'failed atomic receipt write keeps pending audio for same-key recovery',
    () async {
      final entry = await prepare(store());
      final original = await source.readAsBytes();
      final poisonedStage = Link('${metadata(entry.localId).path}.next');
      await poisonedStage.create(source.path);
      transport.accept();
      await expectLater(
        submit(store(), entry.localId),
        throwsA(isA<ServerException>()),
      );
      expect(await source.readAsBytes(), original);
      expect(await audio(entry.localId).readAsBytes(), original);
      expect(
        (await store().list()).entries.single.state,
        PendingUploadState.pending,
      );
      await poisonedStage.delete();
      transport.accept();
      expect(
        (await submit(store(), entry.localId)).state,
        PendingUploadState.accepted,
      );
      expect(transport.requests.map((r) => r.headers['Idempotency-Key']), [
        'original-key',
        'original-key',
      ]);
    },
  );

  test(
    'invalid WAV leaves neither a visible journal entry nor an owned copy',
    () async {
      await source.writeAsString('corrupt audio');
      await expectLater(prepare(store()), throwsA(isA<ValidationException>()));
      expect((await store().list()).entries, isEmpty);
      expect(
        await Directory(
          ownerPath(),
        ).list().map((e) => e.uri.pathSegments.last).toList(),
        ['journal.lock'],
      );
      expect(await source.readAsString(), 'corrupt audio');
    },
  );
}

TypeMatcher<ApiFailure> _failure(ApiFailureKind kind) =>
    isA<ApiFailure>().having((e) => e.kind, 'kind', kind);

ResponseBody _accepted({bool anonymous = false}) => ScriptedAdapter.reply(202, {
  'audio_id': _audioId,
  'session_id': anonymous ? _sessionId : null,
  'job_id': _jobId,
  'processing_version': 'processing-v1',
  'status_url': '/meetings/results/$_audioId/speech-status',
});

/// Consumes the real .19 multipart stream using deterministic HTTP outcomes.
final class _Transport implements HttpClientAdapter {
  final _outcomes = Queue<FutureOr<ResponseBody> Function(RequestOptions)>();
  final requests = <RequestOptions>[];
  final audioBytes = <Uint8List>[];
  final fields = <Map<String, String>>[];
  final firstRequest = Completer<void>();

  void accept({bool anonymous = false}) =>
      _outcomes.add((_) => _accepted(anonymous: anonymous));
  void conflict() => _outcomes.add(
    (_) => ScriptedAdapter.reply(409, {'error': 'idempotency_conflict'}),
  );
  void loseResponse() => _outcomes.add(
    (request) => throw DioException(
      requestOptions: request,
      type: DioExceptionType.receiveTimeout,
    ),
  );
  Completer<ResponseBody> defer() {
    final response = Completer<ResponseBody>();
    _outcomes.add((_) => response.future);
    return response;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final form = options.data as FormData;
    fields.add(Map.fromEntries(form.fields));
    final multipart = BytesBuilder();
    await for (final bytes in requestStream!) {
      multipart.add(bytes);
    }
    final bytes = multipart.takeBytes();
    final text = latin1.decode(bytes);
    final header = text.indexOf('name="audio"');
    final start = text.indexOf('\r\n\r\n', header) + 4;
    audioBytes.add(
      bytes.sublist(start, start + form.files.single.value.length),
    );
    if (!firstRequest.isCompleted) firstRequest.complete();
    if (_outcomes.isEmpty) throw StateError('Unexpected test request');
    return _outcomes.removeFirst()(options);
  }

  @override
  void close({bool force = false}) {}
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
    ..setUint32(24, 16000, Endian.little)
    ..setUint32(28, 32000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(40, dataBytes, Endian.little);
  for (var i = 44; i < bytes.length; i++) {
    bytes[i] = (i * 29 + 7) & 255;
  }
  return bytes;
}
