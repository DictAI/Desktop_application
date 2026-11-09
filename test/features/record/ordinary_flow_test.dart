import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' show InputDevice;

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _anotherOwner = '22222222-2222-4222-8222-222222222222';
const _workspace = '33333333-3333-4333-8333-333333333333';
const _audio = '44444444-4444-4444-8444-444444444444';
const _job = '55555555-5555-4555-8555-555555555555';
const _version = 'example-processing-v1';
const _statusPath = '/meetings/results/$_audio/speech-status';
const _uploadPath = '/ingest/v2/audio/upload';
const _device = InputDevice(id: 'fixture-device', label: 'Fixture microphone');

Map<String, Object?> _receipt() => {
  'audio_id': _audio,
  'session_id': null,
  'job_id': _job,
  'processing_version': _version,
  'status_url': _statusPath,
};

String _jwt(String userId) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': userId, 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = ByteData(48);
  void text(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 40, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, 16000, Endian.little);
  bytes.setUint32(28, 32000, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, 4, Endian.little);
  return bytes.buffer.asUint8List();
}

class _Capture implements AudioCapture {
  _Capture(this.file, {required this.supportsPause});
  final File file;
  @override
  final bool supportsPause;
  @override
  CaptureStatus status = CaptureStatus.idle;
  InputDevice? device;
  int starts = 0;
  int finishes = 0;
  int pauses = 0;
  int disposals = 0;
  final enteredStart = Completer<void>();
  final enteredFinish = Completer<void>();
  Completer<void>? startGate;
  Completer<void>? finishGate;
  Completer<void>? pauseGate;

  @override
  String? get sourcePath => file.path;
  @override
  Future<List<InputDevice>> listInputDevices() async => [_device];
  @override
  Future<void> start({InputDevice? device}) async {
    starts++;
    this.device = device;
    enteredStart.complete();
    await startGate?.future;
    status = CaptureStatus.recording;
  }

  @override
  Future<void> pause() async {
    pauses++;
    await pauseGate?.future;
    status = CaptureStatus.paused;
  }

  @override
  Future<void> resume() async => status = CaptureStatus.recording;
  @override
  Future<File?> finish({required bool confirmed}) async {
    if (!confirmed) return null;
    finishes++;
    enteredFinish.complete();
    await finishGate?.future;
    status = CaptureStatus.finished;
    return file;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    status = CaptureStatus.disposed;
  }
}

class _Transport extends ScriptedAdapter {
  Future<void> Function(RequestOptions)? checkPost;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == _uploadPath) {
      await checkPost?.call(options);
    }
    return super.fetch(options, requestStream, cancelFuture);
  }

  void accept() {
    enqueue(202, _receipt());
    enqueue(200, {
      'job_id': _job,
      'processing_version': _version,
      'workspace_id': _workspace,
      'job_status': 'failed',
      'transcript_status': 'failed',
      'summary_status': 'pending',
      'summary_error': null,
    });
  }
}

class _Fixture {
  _Fixture() {
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({'jwt_token': _jwt(_owner)});
    dio = createDio(
      baseUrl: 'https://fixture.invalid',
      storage: const SecureStorage(),
      onUnauthorized: () async =>
          container.read(sessionNotifierProvider).invalidate(),
    )..httpClientAdapter = transport;
    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => support,
        ),
        recordCaptureFactoryProvider.overrideWithValue((system) {
          final file = File('${temp.path}/capture-${captures.length}.wav')
            ..writeAsBytesSync(_wav());
          final capture = _Capture(file, supportsPause: !system)
            ..startGate = startGate;
          captures.add(capture);
          return capture;
        }),
      ],
    );
    source.writeAsBytesSync(_wav());
    recorder.selectWorkspace(_workspace, 'Workspace fixture');
  }

  final temp = Directory.systemTemp.createTempSync('dictai-ordinary-flow-');
  late final support = Directory('${temp.path}/support');
  late final source = File('${temp.path}/user-original.wav');
  final transport = _Transport();
  final captures = <_Capture>[];
  Completer<void>? startGate;
  late final Dio dio;
  late final ProviderContainer container;
  RecordNotifier get recorder =>
      container.read(recordNotifierProvider.notifier);
  RecordState get state => container.read(recordNotifierProvider);
  Future<BatchSession> get session =>
      container.read(batchSessionProvider.future);
  Iterable<RequestOptions> get posts =>
      transport.requests.where((request) => request.path == _uploadPath);
  Future<void> dispose() async {
    container.dispose();
    dio.close(force: true);
    await temp.delete(recursive: true);
    resetStorageFakes();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() => fixture = _Fixture());
  tearDown(() => fixture.dispose());

  test(
    'ordinary capture freezes options, validates WAV, journals before one POST and tracks 202',
    () async {
      fixture.transport.accept();
      final session = await fixture.session;
      fixture.transport.checkPost = (request) async {
        final pending = (await session.uploads.list()).entries.single;
        expect(pending.state, PendingUploadState.pending);
        expect(
          pending.options.idempotencyKey,
          request.headers['Idempotency-Key'],
        );
        expect(pending.options.workspaceId, _workspace);
        expect(pending.options.language, UploadLanguage.ru);
        expect(
          (pending.options.source as RecordingUploadSource).microphoneDeviceId,
          _device.id,
        );
        expect(
          (pending.options.source as RecordingUploadSource).captureSystemAudio,
          isTrue,
        );
      };
      fixture.recorder.selectDevice(_device);
      fixture.recorder.setCaptureSystemAudio(true);
      fixture.recorder.setLanguage(UploadLanguage.ru);
      final gate = Completer<void>();
      fixture.startGate = gate;
      final starting = fixture.recorder.startRecording();
      expect(fixture.state.status, RecordStatus.starting);
      await fixture.recorder.startRecording();
      expect(fixture.recorder.selectWorkspace(_anotherOwner, 'Other'), isFalse);
      fixture.recorder.setCaptureSystemAudio(false);
      fixture.recorder.setLanguage(UploadLanguage.en);
      fixture.recorder.selectDevice(null);
      gate.complete();
      await starting;
      final capture = fixture.captures.single;
      expect(capture.device, _device);
      expect(capture.starts, 1);
      expect(fixture.recorder.supportsPause, isFalse);
      await fixture.recorder.togglePause();
      expect(capture.pauses, 0);
      await fixture.recorder.finishRecording(confirmed: false);
      expect(fixture.state.status, RecordStatus.recording);
      expect(capture.finishes, 0);
      expect(fixture.posts, isEmpty);
      await Future.wait([
        fixture.recorder.finishRecording(confirmed: true),
        fixture.recorder.finishRecording(confirmed: true),
      ]);
      expect(capture.finishes, 1);
      expect(capture.disposals, 1);
      expect(capture.file.existsSync(), isFalse);
      expect(fixture.state.status, RecordStatus.accepted);
      expect(fixture.state.accepted?.jobId, _job);
      expect(fixture.posts, hasLength(1));
      expect((fixture.posts.single.data as FormData).fields.toMap(), {
        'workspace_id': _workspace,
        'language': 'ru',
        'mixed': 'false',
      });
      expect(
        (await session.uploads.list()).entries.single.accepted?.jobId,
        _job,
      );
      expect(containerJob(fixture.container, session), _job);
    },
  );

  test(
    'ordinary file import retries a transient failure with the same durable identity',
    () async {
      fixture.transport.enqueue(503, {'error': 'upload_unavailable'});
      fixture.transport.accept();
      final session = await fixture.session;
      await fixture.recorder.uploadFile(
        fixture.source,
        language: UploadLanguage.auto,
        mixed: true,
      );
      expect(fixture.state.status, RecordStatus.error);
      expect(fixture.state.canRetryUpload, isTrue);
      final before = (await session.uploads.list()).entries.single;
      expect(before.state, PendingUploadState.pending);
      expect(fixture.posts, hasLength(1));
      await fixture.recorder.retryUpload();
      final after = (await session.uploads.list()).entries.single;
      expect(after.localId, before.localId);
      expect(after.state, PendingUploadState.accepted);
      expect(
        fixture.posts
            .map((request) => request.headers['Idempotency-Key'])
            .toSet(),
        {before.options.idempotencyKey},
      );
      expect(
        fixture.posts.map(
          (request) => (request.data as FormData).fields.toMap(),
        ),
        everyElement({
          'workspace_id': _workspace,
          'language': '',
          'mixed': 'true',
        }),
      );
      expect(fixture.source.readAsBytesSync(), _wav());
    },
  );

  test(
    'an invalid WAV never reaches the server or leaves a pending receipt',
    () async {
      fixture.source.writeAsStringSync('invalid audio');
      await fixture.recorder.uploadFile(fixture.source);
      expect(fixture.state.status, RecordStatus.error);
      expect(fixture.posts, isEmpty);
      expect((await (await fixture.session).uploads.list()).entries, isEmpty);
      expect(fixture.source.existsSync(), isTrue);
    },
  );

  test(
    'missing workspace cannot start native capture or send an upload',
    () async {
      fixture.recorder.clearWorkspace();
      await fixture.recorder.startRecording();
      expect(fixture.captures, isEmpty);
      expect(fixture.state.status, RecordStatus.error);
      await fixture.recorder.uploadFile(fixture.source);
      expect(fixture.posts, isEmpty);
    },
  );

  test(
    'logout cancels a pending POST and late success cannot cross accounts',
    () async {
      final delayed = fixture.transport.defer();
      final original = await fixture.session;
      final sending = fixture.recorder.uploadFile(fixture.source);
      await fixture.transport.firstRequest.future.timeout(
        const Duration(seconds: 5),
      );
      final auth = fixture.container.read(authNotifierProvider.notifier);
      await auth.logout();
      expect(original.isCurrent, isFalse);
      expect(fixture.state.status, RecordStatus.idle);
      expect(fixture.state.selectedWorkspaceId, isNull);
      delayed.complete(ScriptedAdapter.reply(202, _receipt()));
      await sending;
      final retained = await PendingUploadStore(
        ownerId: _owner,
        isCurrentSession: () => true,
        applicationSupportDirectory: () async => fixture.support,
      ).list();
      expect(retained.entries.single.state, PendingUploadState.pending);
      fixture.transport.enqueue(200, {'token': _jwt(_anotherOwner)});
      await auth.login(
        email: 'another@example.invalid',
        password: 'fixture-password',
        onSuccess: () {},
      );
      final replacement = await fixture.session;
      expect(replacement.ownerId, _anotherOwner);
      expect((await replacement.uploads.list()).entries, isEmpty);
      expect(fixture.state.accepted, isNull);
      expect(fixture.posts, hasLength(1));
      expect(
        fixture.transport.requests.any(
          (request) => request.path == _statusPath,
        ),
        isFalse,
      );
    },
  );

  test('confirmed stop waits for pause and still sends exactly once', () async {
    fixture.transport.accept();
    await fixture.recorder.startRecording();
    final capture = fixture.captures.single;
    final gate = Completer<void>();
    capture.pauseGate = gate;
    final pausing = fixture.recorder.togglePause();
    final first = fixture.recorder.finishRecording(confirmed: true);
    final second = fixture.recorder.finishRecording(confirmed: true);
    expect(capture.finishes, 0);
    gate.complete();
    await Future.wait([pausing, first, second]);
    expect(capture.finishes, 1);
    expect(fixture.posts, hasLength(1));
    expect(fixture.state.status, RecordStatus.accepted);
  });

  testWidgets('ordinary Stop can be dismissed and then confirmed once', (
    tester,
  ) async {
    fixture.transport
      ..enqueue(200, {
        'data': [
          {
            'workspace_id': _workspace,
            'owner_user_id': _owner,
            'name': 'Workspace fixture',
            'created_at': '2026-10-24T09:00:00Z',
          },
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
      })
      ..accept();
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: RecordScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(fixture.recorder.startRecording);
    await tester.pump();
    final capture = fixture.captures.last;
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Завершить запись?'), findsOneWidget);
    await tester.tap(find.text('Продолжить запись'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(capture.finishes, 0);
    expect(fixture.posts, isEmpty);
    expect(fixture.state.status, RecordStatus.recording);
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Завершить и отправить'));
    // Dialog futures use widget-test time. The real journal has filesystem
    // and isolate completions, so yield real I/O time between frames.
    for (
      var attempt = 0;
      attempt < 300 &&
          fixture.state.status != RecordStatus.accepted &&
          fixture.state.status != RecordStatus.error;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(
      fixture.state.status,
      RecordStatus.accepted,
      reason: fixture.state.errorMessage,
    );
    await tester.pumpAndSettle();
    expect(capture.finishes, 1);
    expect(fixture.posts, hasLength(1));
    expect(fixture.state.status, RecordStatus.accepted);
  });
}

String? containerJob(ProviderContainer container, BatchSession session) =>
    container
        .read(processingNotifierProvider(session.processingSession))[(
          audioId: _audio,
          jobId: _job,
        )]
        ?.job
        .jobId;

extension on List<MapEntry<String, String>> {
  Map<String, String> toMap() => Map.fromEntries(this);
}
