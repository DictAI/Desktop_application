import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/lifecycle/ios_lifecycle_observer.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/record/data/v2_upload_api.dart';
import 'package:dict_ai/features/results/data/canonical_api.dart';
import 'package:dict_ai/features/results/data/pending_job_store.dart';
import 'package:dict_ai/features/results/data/speech_status_api.dart';
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _workspace = '33333333-3333-4333-8333-333333333333';
const _audio = '44444444-4444-4444-8444-444444444444';
const _jobId = '55555555-5555-4555-8555-555555555555';
const _version = 'fixture-recovery-v1';
const _key = (audioId: _audio, jobId: _jobId);
const _job = ProcessingJob(
  ownerId: _owner,
  audioId: _audio,
  jobId: _jobId,
  processingVersion: _version,
);

Map<String, Object?> _status({bool ready = false, bool failed = false}) => {
  'job_id': _jobId,
  'processing_version': _version,
  'workspace_id': _workspace,
  'job_status': failed
      ? 'failed'
      : ready
      ? 'completed'
      : 'running',
  'transcript_status': failed
      ? 'failed'
      : ready
      ? 'ready'
      : 'pending',
  'summary_status': ready ? 'ready' : 'pending',
  'summary_error': null,
};

Map<String, Object?> _acceptance() => {
  'audio_id': _audio,
  'job_id': _jobId,
  'session_id': null,
  'processing_version': _version,
  'status_url': '/meetings/results/$_audio/speech-status',
};

Map<String, dynamic> _canonical() {
  final fixture =
      (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
              as Map)['no_speech']
          as Map<String, dynamic>;
  fixture['recording_id'] = _audio;
  fixture['job_id'] = _jobId;
  fixture['processing_version'] = _version;
  (fixture['access'] as Map)['owner_user_id'] = _owner;
  return fixture;
}

String _jwt(String owner) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  text(8, 'WAVE');
  text(12, 'fmt ');
  text(36, 'data');
  data.setUint32(4, 40, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, 4, Endian.little);
  return bytes;
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Recovery did not settle.');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late File source;
  late ScriptedAdapter adapter;
  late Dio dio;
  late PendingUploadStore uploads;
  late ProcessingNotifier tracker;
  late bool current;

  PendingUploadStore journal({
    String owner = _owner,
    Future<Directory> Function()? directory,
  }) => PendingUploadStore(
    ownerId: owner,
    isCurrentSession: () => current,
    applicationSupportDirectory: directory ?? () async => support,
  );

  ProcessingNotifier polling(PendingUploadStore store) => ProcessingNotifier(
    store: PendingJobStore(uploads: store, isCurrentSession: () => current),
    statusApi: SpeechStatusApi(dio),
    canonicalApi: CanonicalApi(dio),
    isCurrentSession: () => current,
    pollInterval: const Duration(milliseconds: 100),
    maxBackoff: const Duration(milliseconds: 400),
  );

  Future<PendingUpload> prepare() => uploads.prepare(
    source: source,
    options: UploadOptions(
      anonymous: false,
      workspaceId: _workspace,
      idempotencyKey: 'same-key-after-relaunch',
      source: const ImportedWavUploadSource(),
      language: UploadLanguage.ru,
    ),
  );

  ProviderContainer container(IosLifecycleObserver observer) =>
      ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(dio),
          iosLifecycleObserverProvider.overrideWithValue(observer),
          batchApplicationSupportDirectoryProvider.overrideWithValue(
            () async => support,
          ),
        ],
      );

  setUp(() async {
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({'jwt_token': _jwt(_owner)});
    current = true;
    support = await Directory.systemTemp.createTemp('dictai-ios-recovery-');
    source = File('${support.path}/user-owned.wav');
    await source.writeAsBytes(_wav());
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    uploads = journal();
    tracker = polling(uploads);
  });

  tearDown(() async {
    tracker.dispose();
    dio.close(force: true);
    resetStorageFakes();
    await support.delete(recursive: true);
  });

  test(
    'binding observer deduplicates foreground and detaches on dispose',
    () async {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final observer = IosLifecycleObserver(binding: binding);
      var changes = 0;
      observer.addListener(() => changes++);
      expect(observer.isForeground, isTrue);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(observer.isForeground, isFalse);
      expect(changes, 1);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(changes, 2);
      observer.dispose();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(changes, 2);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  test(
    'suspend cancels reads and timers; late completion cannot replace resume',
    () async {
      final old = adapter.defer();
      tracker.track(_job);
      await adapter.firstRequest.future;
      final oldToken = adapter.requests.single.cancelToken!;
      tracker.suspendPolling();
      tracker.suspendPolling();
      expect(oldToken.isCancelled, isTrue);
      expect(tracker.isPollingSuspended, isTrue);
      await tracker.refresh(_key);
      expect(adapter.requests, hasLength(1));

      adapter.enqueue(200, _status());
      tracker.resumePolling();
      tracker.resumePolling();
      await _until(() => tracker.state[_key]?.status != null);
      expect(adapter.requests, hasLength(2));
      old.complete(ScriptedAdapter.reply(200, _status(ready: true)));
      await Future<void>.delayed(Duration.zero);
      expect(tracker.state[_key]!.canonical, isNull);
      expect(tracker.state[_key]!.phase, ProcessingPhase.waiting);
      tracker.suspendPolling();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(adapter.requests, hasLength(2));
      expect(tracker.state, hasLength(1));
    },
  );

  test(
    'terminal failures and authorization errors do not restart on resume',
    () async {
      adapter.enqueue(200, _status(failed: true));
      tracker.track(_job);
      await _until(() => tracker.state[_key]?.status != null);
      tracker.suspendPolling();
      tracker.resumePolling();
      expect(adapter.requests, hasLength(1));
      tracker.dispose();
      tracker = polling(uploads);
      adapter.enqueue(401, {'error': 'unauthorized'});
      tracker.track(_job);
      await _until(() => tracker.state[_key]?.error != null);
      expect(
        tracker.state[_key]!.error,
        isA<ApiFailure>()
            .having((error) => error.kind, 'kind', ApiFailureKind.unauthorized)
            .having((error) => error.statusCode, 'statusCode', 401),
      );
      tracker.suspendPolling();
      tracker.resumePolling();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests, hasLength(2));
      expect(tracker.state[_key]!.retryIn, isNull);
    },
  );

  test(
    'retry backoff remains capped across repeated foreground transitions',
    () async {
      for (var attempt = 0; attempt < 4; attempt++) {
        final previous = tracker.state[_key];
        adapter.enqueue(503, {'error': 'unavailable'});
        if (attempt == 0) {
          tracker.track(_job);
        } else {
          tracker.resumePolling();
          tracker.resumePolling();
          await Future<void>.delayed(const Duration(milliseconds: 25));
          expect(adapter.requests, hasLength(attempt));
        }
        await _until(() => adapter.requests.length == attempt + 1);
        await _until(() => !identical(tracker.state[_key], previous));
        await _until(() => tracker.state[_key]?.error != null);
        // Wait for this attempt's response, not the preceding error snapshot.
        await _until(
          () =>
              tracker.state[_key]?.retryIn ==
              Duration(milliseconds: attempt == 0 ? 200 : 400),
        );
        tracker.suspendPolling();
      }
      expect(tracker.state[_key]!.retryIn, const Duration(milliseconds: 400));
      expect(adapter.requests, hasLength(4));
    },
  );

  test(
    'journal restore survives suspend/resume while directory read is pending',
    () async {
      final draft = await prepare();
      adapter.enqueue(202, _acceptance());
      await uploads.submit(
        draft.localId,
        api: V2UploadApi(dio),
        cancelToken: CancelToken(),
      );
      final directory = Completer<Directory>();
      tracker.dispose();
      tracker = polling(journal(directory: () => directory.future));
      final restoring = tracker.restore();
      tracker.suspendPolling();
      tracker.resumePolling();
      adapter.enqueue(200, _status(failed: true));
      directory.complete(support);
      await restoring;
      await _until(() => tracker.state[_key]?.phase == ProcessingPhase.failed);
      expect(adapter.requests.map((r) => r.method), ['POST', 'GET']);
    },
  );

  test(
    'initial suspended session restores accepted job on resume without POST',
    () async {
      final draft = await prepare();
      adapter.enqueue(202, _acceptance());
      await uploads.submit(
        draft.localId,
        api: V2UploadApi(dio),
        cancelToken: CancelToken(),
      );
      final observer = IosLifecycleObserver()
        ..didChangeAppLifecycleState(AppLifecycleState.paused);
      final scope = container(observer);
      try {
        final session = await scope.read(batchSessionProvider.future);
        final sessionTracker = scope.read(
          processingNotifierProvider(session.processingSession).notifier,
        );
        expect(sessionTracker.isPollingSuspended, isTrue);
        expect(adapter.requests.map((r) => r.method), ['POST']);
        adapter
          ..enqueue(200, _status(ready: true))
          ..enqueue(200, _canonical());
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await _until(() => sessionTracker.state[_key]?.canonicalReady == true);
        expect(adapter.requests.map((r) => r.method), ['POST', 'GET', 'GET']);
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(adapter.requests, hasLength(3));
        expect(await source.exists(), isTrue);
      } finally {
        scope.dispose();
        observer.dispose();
      }
    },
  );

  test(
    'unknown upload survives relaunch and explicit replay uses identical key and bytes',
    () async {
      final draft = await prepare();
      await source.delete(); // Recovery must use the journal's owned WAV.
      final lostResponse = adapter.defer();
      final sending = uploads.submit(
        draft.localId,
        api: V2UploadApi(dio),
        cancelToken: CancelToken(),
      );
      await adapter.firstRequest.future;
      lostResponse.completeError(
        DioException(
          requestOptions: adapter.requests.single,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(sending, throwsA(isA<ApiFailure>()));
      final afterFailure = (await journal().list()).entries.single;
      expect(afterFailure.state, PendingUploadState.pending);
      expect(afterFailure.sha256, draft.sha256);
      expect(
        afterFailure.options.toMultipartFields(),
        draft.options.toMultipartFields(),
      );

      final observer = IosLifecycleObserver()
        ..didChangeAppLifecycleState(AppLifecycleState.paused);
      final scope = container(observer);
      try {
        final session = await scope.read(batchSessionProvider.future);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(adapter.requests, hasLength(1));
        adapter
          ..enqueue(202, _acceptance())
          ..enqueue(200, _status(failed: true));
        final accepted = await session.submit(draft.localId);
        final sessionTracker = scope.read(
          processingNotifierProvider(session.processingSession).notifier,
        );
        await _until(() => sessionTracker.state[_key]?.status != null);
        expect(accepted.state, PendingUploadState.accepted);
        expect(accepted.sha256, draft.sha256);
        final posts = adapter.requests.where((r) => r.method == 'POST');
        expect(posts, hasLength(2));
        expect(posts.map((r) => r.headers['Idempotency-Key']), [
          'same-key-after-relaunch',
          'same-key-after-relaunch',
        ]);
        expect(
          (await session.uploads.list()).entries.single.accepted!.jobId,
          _jobId,
        );
      } finally {
        scope.dispose();
        observer.dispose();
      }
    },
  );

  test(
    'temporary journal access failure preserves recovery and account isolation',
    () async {
      final draft = await prepare();
      var locked = true;
      final recovering = journal(
        directory: () async {
          if (locked) {
            throw const FileSystemException('synthetic protected directory');
          }
          return support;
        },
      );
      await expectLater(recovering.list(), throwsA(isA<ServerException>()));
      locked = false;
      final restored = (await recovering.list()).entries.single;
      expect(restored.localId, draft.localId);
      expect(restored.options.idempotencyKey, draft.options.idempotencyKey);
      expect((await journal(owner: _otherOwner).list()).entries, isEmpty);
      expect(adapter.requests, isEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'POSIX protected source and metadata can be retried after access returns',
    () async {
      final draft = await prepare();
      final directory =
          '${support.path}/dictai-pending-v1/$_owner/${draft.localId}';
      final savedSource = '$directory/source.wav';
      final metadata = '$directory/upload.json';
      Future<void> mode(String path, String value) async {
        final result = await Process.run('chmod', [value, path]);
        expect(result.exitCode, 0);
      }

      try {
        await mode(metadata, '000');
        await expectLater(uploads.list(), throwsA(isA<ServerException>()));
        await mode(metadata, '600');
        expect((await uploads.list()).damagedEntries, 0);
        await mode(savedSource, '000');
        await expectLater(
          uploads.submit(
            draft.localId,
            api: V2UploadApi(dio),
            cancelToken: CancelToken(),
          ),
          throwsA(
            isA<ServerException>().having(
              PendingUploadStore.isUnrecoverableReplayError,
              'permanent replay block',
              isFalse,
            ),
          ),
        );
        expect(adapter.requests, isEmpty);
        await mode(savedSource, '600');
        adapter.enqueue(202, _acceptance());
        final accepted = await uploads.submit(
          draft.localId,
          api: V2UploadApi(dio),
          cancelToken: CancelToken(),
        );
        expect(accepted.state, PendingUploadState.accepted);
        expect(accepted.options.idempotencyKey, draft.options.idempotencyKey);
        expect(await source.exists(), isTrue);
      } finally {
        if (File(savedSource).existsSync()) await mode(savedSource, '600');
        await mode(metadata, '600');
      }
    },
  );

  test(
    'logout cancels poll, detaches lifecycle and rejects delayed acceptance',
    () async {
      final observer = IosLifecycleObserver()
        ..didChangeAppLifecycleState(AppLifecycleState.resumed);
      final scope = container(observer);
      try {
        final session = await scope.read(batchSessionProvider.future);
        final sessionTracker = scope.read(
          processingNotifierProvider(session.processingSession).notifier,
        );
        final pending = adapter.defer();
        sessionTracker.track(_job);
        await adapter.firstRequest.future;
        final token = adapter.requests.single.cancelToken!;
        await scope.read(authNotifierProvider.notifier).logout();
        expect(session.isCurrent, isFalse);
        expect(token.isCancelled, isTrue);
        pending.complete(ScriptedAdapter.reply(200, _status(ready: true)));
        observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(adapter.requests, hasLength(1));
        expect(await source.exists(), isTrue);
      } finally {
        scope.dispose();
        observer.dispose();
      }
    },
  );
}
