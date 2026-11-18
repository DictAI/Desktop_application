import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/lifecycle/ios_lifecycle_observer.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/ios_wav_import.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/results/data/ios_document_export.dart';
import 'package:dict_ai/features/results/presentation/audio_player.dart';
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/features/results/presentation/result_detail_notifier.dart';
import 'package:dict_ai/features/results/presentation/results_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' show InputDevice;

import '../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _workspace = '33333333-3333-4333-8333-333333333333';
const _audio = '44444444-4444-4444-8444-444444444444';
const _job = '55555555-5555-4555-8555-555555555555';
const _version = 'batch-regression-v1';
const _key = (audioId: _audio, jobId: _job);
const _exportText = 'Синтетический экспорт\r\nстрока 2\n';

String _jwt(String owner) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = Uint8List(32044);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, bytes.length - 44, Endian.little);
  return bytes;
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Batch did not settle.');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

final class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = _owner;
  final tokens = {_owner: _jwt(_owner), _otherOwner: _jwt(_otherOwner)};
  bool accepted = false, deleted = false, ready = true;
  int unknownUploads = 0;
  Completer<ResponseBody>? statusGate, pageGate, deletionGate;
  final deletionStarted = Completer<void>();

  Map<String, Object?> status() => {
    'job_id': _job,
    'processing_version': _version,
    'workspace_id': _workspace,
    'job_status': ready ? 'completed' : 'running',
    'transcript_status': ready ? 'ready' : 'pending',
    'summary_status': ready ? 'ready' : 'pending',
    'summary_error': null,
  };

  ResponseBody canonical() {
    final fixture =
        (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
                as Map)['speech']
            as Map<String, dynamic>;
    fixture['recording_id'] = _audio;
    fixture['job_id'] = _job;
    fixture['processing_version'] = _version;
    (fixture['access'] as Map)['owner_user_id'] = _owner;
    (fixture['access'] as Map)['workspace_id'] = _workspace;
    return ScriptedAdapter.reply(200, fixture);
  }

  ResponseBody page({bool stale = false}) => ScriptedAdapter.reply(200, {
    'data': [
      if (accepted && owner == _owner && (!deleted || stale))
        {
          'result_id': _job,
          'audio_id': _audio,
          'workspace_id': _workspace,
          'workspace_name': 'Fixture workspace',
          'upload_user_id': _owner,
          'summary_url': '',
          'transcript_url': '',
          'status': 'done',
          'created_at': '2026-11-18T12:00:00Z',
        },
    ],
    'pagination': {
      'page': 1,
      'limit': 20,
      'total': accepted && !deleted ? 1 : 0,
      'total_pages': accepted && !deleted ? 1 : 0,
    },
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/auth/login' && options.method == 'POST') {
      owner = (options.data as Map)['email'] == 'b@fixture.invalid'
          ? _otherOwner
          : _owner;
      return ScriptedAdapter.reply(200, {'token': tokens[owner]});
    }
    // Every protected request must have traversed the real AuthInterceptor.
    expect(options.headers['Authorization'], 'Bearer ${tokens[owner]}');
    if (options.path == '/workspaces/' && options.method == 'GET') {
      return ScriptedAdapter.reply(200, {
        'data': [
          {
            'workspace_id': _workspace,
            'owner_user_id': owner,
            'name': 'Fixture workspace',
            'created_at': '2026-11-18T12:00:00Z',
          },
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
      });
    }
    if (options.path == '/ingest/v2/audio/upload' && options.method == 'POST') {
      if (unknownUploads > 0) {
        unknownUploads--;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('synthetic lost acceptance response'),
        );
      }
      accepted = true;
      return ScriptedAdapter.reply(202, {
        'audio_id': _audio,
        'job_id': _job,
        'session_id': null,
        'processing_version': _version,
        'status_url': '/meetings/results/$_audio/speech-status',
      });
    }
    if (options.path.endsWith('/speech-status')) {
      if (statusGate case final gate?) {
        statusGate = null;
        return gate.future;
      }
      return ScriptedAdapter.reply(200, status());
    }
    if (options.path.endsWith('/structured')) return canonical();
    if (options.path.endsWith('/documents/transcript.txt') ||
        options.path.endsWith('/documents/summary.txt')) {
      return ScriptedAdapter.reply(200, _exportText, contentType: 'text/plain');
    }
    if (options.path.endsWith('/original')) {
      final bytes = _wav();
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/wav'],
          Headers.contentLengthHeader: [bytes.length.toString()],
        },
      );
    }
    if (options.path == '/meetings/results' && options.method == 'GET') {
      if (pageGate case final gate?) {
        pageGate = null;
        return gate.future;
      }
      return page();
    }
    if (options.path == '/meetings/results/$_audio' &&
        options.method == 'DELETE') {
      if (!deletionStarted.isCompleted) deletionStarted.complete();
      deleted = true;
      return deletionGate?.future ?? ScriptedAdapter.reply(204, '');
    }
    throw StateError(
      'Unexpected batch request ${options.method} ${options.path}',
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Capture implements AudioCapture, AudioCaptureEvents {
  _Capture(this.file);
  final File file;
  final events = StreamController<CaptureEvent>.broadcast(sync: true);
  int starts = 0, disposals = 0;
  AppException? startError;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  bool get supportsPause => true;
  @override
  String get sourcePath => file.path;
  @override
  Stream<CaptureEvent> get captureEvents => events.stream;
  @override
  Future<List<InputDevice>> listInputDevices() async => [];
  @override
  Future<void> start({InputDevice? device}) async {
    starts++;
    if (startError case final error?) throw error;
    status = CaptureStatus.recording;
  }

  @override
  Future<void> pause() async => status = CaptureStatus.paused;
  @override
  Future<void> resume() async => status = CaptureStatus.recording;
  @override
  Future<File?> finish({required bool confirmed}) async {
    expect(confirmed, isTrue);
    status = CaptureStatus.finished;
    return file;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    status = CaptureStatus.disposed;
  }

  void interrupt() {
    status = CaptureStatus.paused;
    events.add(
      const CaptureEvent(CaptureStatus.paused, message: 'Interruption'),
    );
  }
}

final class _Decoder implements AudioPlayer {
  final events = StreamController<AudioEvent>.broadcast(sync: true);
  final calls = <String>[];
  File? input;
  bool disposed = false;
  @override
  PlayerState get state =>
      disposed ? PlayerState.disposed : PlayerState.stopped;
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  Stream<AudioEvent> get eventStream => events.stream;
  @override
  Future<void> setAudioContext(AudioContext context) async =>
      calls.add('context');
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async => calls.add('mode');
  @override
  Future<void> setSourceDeviceFile(String path, {String? mimeType}) async {
    input = File(path);
    expect(await input!.readAsBytes(), _wav());
    expect(mimeType, 'audio/wav');
    calls.add('source');
  }

  @override
  Future<Duration?> getDuration() async => const Duration(seconds: 1);
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration position) async => calls.add('seek');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async {
    disposed = true;
    calls.add('dispose');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Sheet implements IosShareSheet {
  _Sheet(this.userCopy);
  final File userCopy;
  File? input;
  int calls = 0;
  @override
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    VoidCallback? onPresented,
  }) async {
    input = file;
    calls++;
    expect(contentType, 'text/plain');
    expect(await file.readAsString(), _exportText);
    await file.copy(userCopy.path);
    onPresented?.call();
    return IosShareOutcome.completed;
  }

  @override
  Future<void> cancel(String id) async {}
}

final class _Fixture {
  _Fixture(this.root);
  final Directory root;
  final transport = _Transport();
  late final source = File('${root.path}/user-original.wav')
    ..writeAsBytesSync(_wav());
  late final capture = _Capture(
    File('${root.path}/capture.wav')..writeAsBytesSync(_wav()),
  );
  late final sheet = _Sheet(File('${root.path}/user-export.txt'));
  late ProviderContainer container;
  late Dio dio;
  final subscriptions = <ProviderSubscription<Object?>>[];
  late final lifecycle = IosLifecycleObserver();

  static Future<_Fixture> create() async {
    resetStorageFakes();
    final f = _Fixture(await Directory.systemTemp.createTemp('dictai-batch-'));
    f.source;
    f.open();
    return f;
  }

  void open() {
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => root,
        ),
        resultTemporaryDirectoryProvider.overrideWithValue(() async => root),
        recordCaptureFactoryProvider.overrideWithValue((_) => capture),
        iosShareSheetProvider.overrideWithValue(sheet),
        iosLifecycleObserverProvider.overrideWithValue(lifecycle),
      ],
    );
    dio = container.read(dioProvider)..httpClientAdapter = transport;
  }

  RecordNotifier get record => container.read(recordNotifierProvider.notifier);
  AuthNotifier get auth => container.read(authNotifierProvider.notifier);
  Iterable<RequestOptions> get uploads => transport.requests.where(
    (r) => r.path == '/ingest/v2/audio/upload' && r.method == 'POST',
  );
  Future<void> login([String owner = _owner]) async {
    var succeeded = false;
    await auth.login(
      email: owner == _owner ? 'a@fixture.invalid' : 'b@fixture.invalid',
      password: 'synthetic-fixture-password',
      onSuccess: () => succeeded = true,
    );
    expect(succeeded, isTrue);
    expect(container.read(authNotifierProvider).status, AuthStatus.success);
  }

  Future<void> selectWorkspace() async {
    final workspace =
        (await container.read(workspaceApiProvider).getWorkspaces()).single;
    expect(
      record.selectWorkspace(workspace.workspaceId, workspace.name),
      isTrue,
    );
    record.setLanguage(UploadLanguage.ru);
  }

  void restart() {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    subscriptions.clear();
    container.dispose();
    dio.close(force: true);
    open();
  }

  Future<void> dispose() async {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    container.dispose();
    dio.close(force: true);
    await capture.events.close();
    lifecycle.dispose();
    // Let session cancellation and app-owned cleanup finish before test-root removal.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (await root.exists()) await root.delete(recursive: true);
    resetStorageFakes();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final input in ['Files', 'microphone']) {
    test(
      '$input: login/workspace through canonical, player/export and delete/logout',
      () async {
        final f = await _Fixture.create();
        addTearDown(f.dispose);
        await f.login();
        await f.selectWorkspace();
        final session = await f.container.read(batchSessionProvider.future);
        if (input == 'Files') {
          final imported = await IosWavImporter(
            pickFile: () async => f.source,
            temporaryDirectory: () async => f.root,
          ).pick(isCurrent: () => session.isCurrent);
          expect(imported, isNotNull);
          expect(imported!.file.path, isNot(f.source.path));
          await f.record.uploadFile(imported.file, language: UploadLanguage.ru);
          await imported.discard();
          expect(await imported.file.exists(), isFalse);
        } else {
          await f.record.startRecording();
          expect(f.record.state.status, RecordStatus.recording);
          f.capture.interrupt();
          expect(f.record.state.status, RecordStatus.paused);
          expect(f.uploads, isEmpty);
          await f.record.togglePause();
          expect(f.record.state.status, RecordStatus.recording);
          await f.record.togglePause();
          await f.record.sendPausedRecording();
        }
        expect(f.record.state.status, RecordStatus.accepted);
        expect(f.record.state.accepted!.processingVersion, _version);
        expect(f.uploads, hasLength(1));
        final post = f.uploads.single;
        final fields = Map.fromEntries((post.data as FormData).fields);
        expect(fields['workspace_id'], _workspace);
        expect(fields['language'], 'ru');
        expect(fields['mixed'], 'false');
        expect((post.data as FormData).files.single.key, 'audio');
        expect(post.headers['Idempotency-Key'], isNotEmpty);

        final tracker = f.container.read(
          processingNotifierProvider(session.processingSession).notifier,
        );
        await _until(() => tracker.state[_key]?.phase == ProcessingPhase.ready);
        final progress = tracker.state[_key]!;
        expect(progress.canonical!.recordingId, _audio);
        expect(progress.canonical!.jobId, _job);
        expect(progress.canonical!.processingVersion, _version);
        expect(progress.canonical!.access.ownerUserId, _owner);
        expect(
          f.transport.requests
              .singleWhere((r) => r.path.endsWith('/structured'))
              .queryParameters['job_id'],
          _job,
        );

        final detailKey = (session: session, audioId: _audio, jobId: _job);
        final detailProvider = resultDetailNotifierProvider(detailKey);
        f.subscriptions.add(f.container.listen(detailProvider, (_, __) {}));
        final detail = f.container.read(detailProvider.notifier);
        await _until(() => detail.state.progress?.canonical != null);
        f.subscriptions.add(
          f.container.listen(resultReadyNoticeProvider(session), (_, __) {}),
        );
        expect(
          f.container.read(resultReadyNoticeProvider(session)),
          hasLength(1),
        );

        f.subscriptions.add(
          f.container.listen(originalAudioCacheProvider(session), (_, __) {}),
        );
        final cache = f.container.read(originalAudioCacheProvider(session));
        final decoder = _Decoder();
        final player = ResultAudioController(
          cache: cache,
          audioId: _audio,
          jobId: _job,
          isCurrentSession: () =>
              session.isCurrent && !session.jobs.isDeleted(_key),
          playerFactory: () => decoder,
        );
        addTearDown(() async {
          await player.close();
          player.dispose();
          await decoder.events.close();
        });
        await player.toggle();
        expect(player.playing, isTrue);
        expect(decoder.calls, ['context', 'mode', 'source', 'resume']);
        await player.seek(const Duration(milliseconds: 500));
        expect(player.position, const Duration(milliseconds: 500));
        await player.stop();
        expect(decoder.disposed, isTrue);

        final exportProvider = iosDocumentExporterProvider(detailKey);
        f.subscriptions.add(f.container.listen(exportProvider, (_, __) {}));
        final exporter = f.container.read(exportProvider);
        expect(
          await exporter.share(
            audioId: _audio,
            jobId: _job,
            kind: IosExportKind.transcriptTxt,
            status: progress.status!,
          ),
          IosShareOutcome.completed,
        );
        expect(f.sheet.calls, 1);
        expect(await f.sheet.input!.exists(), isFalse);
        expect(await f.sheet.userCopy.readAsString(), _exportText);

        final resultsProvider = resultsNotifierProvider(session);
        f.subscriptions.add(f.container.listen(resultsProvider, (_, __) {}));
        final results = f.container.read(resultsProvider.notifier);
        await _until(() => results.state.page.asData?.value.data.length == 1);
        final stalePage = Completer<ResponseBody>();
        f.transport.pageGate = stalePage;
        final deleting = results.delete(_audio);
        await _until(() => session.jobs.isDeleted(_key));
        expect(tracker.state, isNot(contains(_key)));
        expect(detail.state.progress?.canonical, isNull);
        expect(f.container.read(resultReadyNoticeProvider(session)), isEmpty);
        await expectLater(
          exporter.share(
            audioId: _audio,
            jobId: _job,
            kind: IosExportKind.transcriptTxt,
            status: progress.status!,
          ),
          throwsA(isA<UnauthorizedException>()),
        );
        stalePage.complete(f.transport.page(stale: true));
        await deleting;
        expect(results.state.page.asData!.value.data, isEmpty);
        expect((await session.uploads.list()).entries, isEmpty);
        expect(await decoder.input!.exists(), isFalse);
        await f.auth.logout();
        expect(session.isCurrent, isFalse);
        expect(session.cancelToken.isCancelled, isTrue);
        expect(await f.source.readAsBytes(), _wav());
        expect(await f.sheet.userCopy.readAsString(), _exportText);
      },
    );
  }

  test(
    'invalid Files and refused microphone never cross the upload boundary',
    () async {
      final f = await _Fixture.create();
      addTearDown(f.dispose);
      await f.login();
      await f.selectWorkspace();
      final invalid = await File(
        '${f.root.path}/invalid.wav',
      ).writeAsString('bad');
      await expectLater(
        IosWavImporter(
          pickFile: () async => invalid,
          temporaryDirectory: () async => f.root,
        ).pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      f.capture.startError = const ValidationException(
        'Microphone permission denied',
      );
      await f.record.startRecording();
      expect(f.record.state.status, RecordStatus.error);
      expect(f.capture.starts, 1);
      expect(f.capture.disposals, greaterThanOrEqualTo(1));
      expect(f.uploads, isEmpty);
      expect(await invalid.readAsString(), 'bad');
      expect(await f.source.readAsBytes(), _wav());
    },
  );

  test(
    'suspend cancels accepted-job reads; late A response stays fenced after login B',
    () async {
      final f = await _Fixture.create();
      addTearDown(f.dispose);
      await f.login();
      await f.selectWorkspace();
      final old = Completer<ResponseBody>();
      f.transport.statusGate = old;
      await f.record.uploadFile(f.source, language: UploadLanguage.ru);
      final sessionA = await f.container.read(batchSessionProvider.future);
      await _until(
        () =>
            f.transport.requests.any((r) => r.path.endsWith('/speech-status')),
      );
      final oldRequest = f.transport.requests.lastWhere(
        (r) => r.path.endsWith('/speech-status'),
      );
      f.lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(oldRequest.cancelToken!.isCancelled, isTrue);
      final before = f.transport.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(f.transport.requests, hasLength(before));
      expect(
        f.transport.requests.where((r) => r.path.endsWith('/structured')),
        isEmpty,
      );
      f.lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      final trackerA = f.container.read(
        processingNotifierProvider(sessionA.processingSession).notifier,
      );
      await _until(() => trackerA.state[_key]?.canonical != null);
      expect(
        f.uploads,
        hasLength(1),
        reason: 'Resume is a GET recovery, not a new upload',
      );
      await f.auth.logout();
      await f.login(_otherOwner);
      final sessionB = await f.container.read(batchSessionProvider.future);
      final trackerB = f.container.read(
        processingNotifierProvider(sessionB.processingSession).notifier,
      );
      expect(sessionA.isCurrent, isFalse);
      final after = f.transport.requests.length;
      old.complete(ScriptedAdapter.reply(200, f.transport.status()));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(trackerB.state, isEmpty);
      expect((await sessionB.uploads.list()).entries, isEmpty);
      expect(f.transport.requests, hasLength(after));
      expect(f.uploads, hasLength(1));
    },
  );

  test(
    'unknown upload outcome survives restart, isolates B and replays the same key for A',
    () async {
      final f = await _Fixture.create();
      addTearDown(f.dispose);
      await f.login();
      await f.selectWorkspace();
      f.transport.unknownUploads = 1;
      await f.record.uploadFile(f.source, language: UploadLanguage.ru);
      expect(f.record.state.status, RecordStatus.error);
      expect(f.record.state.canRetryUpload, isTrue);
      final first = await f.container.read(batchSessionProvider.future);
      final saved = (await first.uploads.list()).entries.single;
      expect(saved.state, PendingUploadState.pending);
      expect(f.uploads, hasLength(1));
      final key = f.uploads.single.headers['Idempotency-Key'];
      f.restart();
      final restored = await f.container.read(batchSessionProvider.future);
      expect(
        (await restored.uploads.list()).entries.single.sha256,
        saved.sha256,
      );
      expect(
        f.uploads,
        hasLength(1),
        reason: 'Restart must not automatically POST',
      );
      await f.auth.logout();
      await f.login(_otherOwner);
      final accountB = await f.container.read(batchSessionProvider.future);
      expect(restored.isCurrent, isFalse);
      expect(accountB.ownerId, _otherOwner);
      expect((await accountB.uploads.list()).entries, isEmpty);
      expect(f.uploads, hasLength(1));
      await f.auth.logout();
      await f.login();
      final accountA = await f.container.read(batchSessionProvider.future);
      final recovered = (await accountA.uploads.list()).entries.single;
      expect(recovered.localId, saved.localId);
      expect(recovered.sha256, saved.sha256);
      expect(recovered.options.idempotencyKey, key);
      await accountA.submit(recovered.localId);
      expect(f.uploads, hasLength(2));
      expect(f.uploads.map((r) => r.headers['Idempotency-Key']), [key, key]);
      final tracker = f.container.read(
        processingNotifierProvider(accountA.processingSession).notifier,
      );
      await _until(() => tracker.state[_key]?.canonical != null);
      expect(tracker.state[_key]!.canonical!.processingVersion, _version);
      expect(await f.source.readAsBytes(), _wav());
    },
  );
}
