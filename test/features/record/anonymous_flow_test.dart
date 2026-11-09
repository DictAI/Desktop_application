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
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart' show InputDevice;

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _workspace = '22222222-2222-4222-8222-222222222222';
const _audio = '33333333-3333-4333-8333-333333333333';
const _job = '44444444-4444-4444-8444-444444444444';
const _sessionId = '55555555-5555-4555-8555-555555555555';
const _version = 'fixture-v1';
const _uploadPath = '/ingest/v2/audio/upload/anonymous';
const _statusPath = '/meetings/results/$_audio/speech-status';
const _sessionPath = '/ingest/v2/audio/anonymous/$_sessionId';
const _mic = InputDevice(id: 'fixture-mic', label: 'Fixture mic');

Map<String, Object?> _receipt() => {
  'audio_id': _audio,
  'session_id': _sessionId,
  'job_id': _job,
  'processing_version': _version,
  'status_url': _statusPath,
};

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final claims = encode({
    'iss': 'dictai-auth-v2',
    'aud': 'dictai-user',
    'user_id': _owner,
    'exp':
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  return '${encode({'alg': 'HS256'})}.$claims.fixture';
}

// 16 kHz mono PCM16 with two zero samples.
final _wav = Uint8List.fromList([
  ...ascii.encode('RIFF'),
  40,
  0,
  0,
  0,
  ...ascii.encode('WAVEfmt '),
  16,
  0,
  0,
  0,
  1,
  0,
  1,
  0,
  128,
  62,
  0,
  0,
  0,
  125,
  0,
  0,
  2,
  0,
  16,
  0,
  ...ascii.encode('data'),
  4,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
]);

final class _Capture implements AudioCapture {
  _Capture(this.file);
  final File file;
  Completer<void>? startGate;
  InputDevice? device;
  int finishes = 0;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  String get sourcePath => file.path;
  @override
  bool get supportsPause => false;
  @override
  Future<List<InputDevice>> listInputDevices() async => [_mic];
  @override
  Future<void> start({InputDevice? device}) async {
    this.device = device;
    await startGate?.future;
    status = CaptureStatus.recording;
  }

  @override
  Future<void> pause() async => fail('Unexpected Pause');
  @override
  Future<void> resume() async => fail('Unexpected Resume');
  @override
  Future<File?> finish({required bool confirmed}) async {
    if (!confirmed) return null;
    finishes++;
    status = CaptureStatus.finished;
    return file..writeAsBytesSync(_wav);
  }

  @override
  Future<void> dispose() async => status = CaptureStatus.disposed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late Directory support;
  late File source;
  late ScriptedAdapter transport;
  late Dio dio;
  late ProviderContainer container;
  late RecordNotifier recorder;
  late _Capture capture;
  Completer<void>? startGate;
  late List<bool> captureModes;
  RecordState state() => container.read(recordNotifierProvider);
  Future<BatchSession> session() => container.read(batchSessionProvider.future);
  Iterable<RequestOptions> uploads() =>
      transport.requests.where((request) => request.method == 'POST');

  void enqueueAccepted([String? terminal]) {
    transport
      ..enqueue(202, _receipt())
      ..enqueue(200, {
        'job_id': _job,
        'processing_version': _version,
        'workspace_id': null,
        'job_status': 'queued',
        'transcript_status': 'pending',
        'summary_status': 'pending',
        'summary_error': null,
      })
      ..enqueue(200, {
        ..._receipt(),
        'status': terminal ?? 'queued',
        'confirm_required': false,
      });
  }

  setUp(() {
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({'jwt_token': _token()});
    temporary = Directory.systemTemp.createTempSync('dictai-owner-flow-');
    support = Directory('${temporary.path}/support');
    source = File('${temporary.path}/imported.wav')..writeAsBytesSync(_wav);
    startGate = null;
    captureModes = [];
    transport = ScriptedAdapter();
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
          captureModes.add(system);
          capture = _Capture(File('${temporary.path}/capture.wav'))
            ..startGate = startGate;
          return capture;
        }),
      ],
    );
    recorder = container.read(recordNotifierProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    dio.close(force: true);
    await temporary.delete(recursive: true);
    resetStorageFakes();
  });

  test(
    'owner-only capture freezes mode and options until confirmed U02',
    () async {
      enqueueAccepted();
      recorder.selectWorkspace(_workspace, 'Previous workspace');
      recorder.setAnonymous(true);
      recorder.selectDevice(_mic);
      recorder.setCaptureSystemAudio(true);
      recorder.setLanguage(UploadLanguage.en);
      final gate = Completer<void>();
      startGate = gate;
      final starting = recorder.startRecording();
      expect(state().status, RecordStatus.starting);
      recorder.setAnonymous(false);
      recorder.setLanguage(UploadLanguage.ru);
      recorder.setCaptureSystemAudio(false);
      recorder.selectDevice(null);
      expect(recorder.selectWorkspace(_owner, 'Other workspace'), isFalse);
      await recorder.startRecording();
      gate.complete();
      await starting;
      expect(state().anonymous, isTrue);
      expect(captureModes, [true]);
      expect(capture.device, _mic);
      expect(recorder.supportsPause, isFalse);
      await recorder.finishRecording(confirmed: false);
      expect(state().status, RecordStatus.recording);
      expect(capture.finishes, 0);
      expect(uploads(), isEmpty);
      final stopping = recorder.finishRecording(confirmed: true);
      expect(state().status, RecordStatus.preparing);
      recorder.setAnonymous(false);
      await Future.wait([
        stopping,
        recorder.finishRecording(confirmed: true),
        recorder.uploadFile(source),
      ]);
      expect(capture.finishes, 1);
      expect(state().anonymous, isTrue);
      expect(state().status, RecordStatus.accepted);
      final post = uploads().single;
      expect(post.path, _uploadPath);
      expect(post.headers['Authorization'], startsWith('Bearer '));
      final form = post.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'language': 'en',
        'mixed': 'false',
      });
      expect(form.files.single.key, 'audio');
      final accepted = (await (await session()).uploads.list()).entries.single;
      expect(accepted.options.workspaceId, isNull);
      expect(accepted.options.anonymous, isTrue);
      expect(accepted.options.idempotencyKey, post.headers['Idempotency-Key']);
      expect(accepted.accepted?.sessionId, _sessionId);
      expect(accepted.accepted?.audioId, _audio);
      expect(accepted.accepted?.jobId, _job);
      expect(accepted.accepted?.processingVersion, _version);
      final batch = await session();
      final tracked = container.read(
        processingNotifierProvider(batch.processingSession),
      );
      expect(
        tracked[(audioId: _audio, jobId: _job)]?.job.sessionId,
        _sessionId,
      );
    },
  );

  for (final terminal in [
    ProcessingPhase.failed,
    ProcessingPhase.cancelled,
    ProcessingPhase.expired,
  ]) {
    test(
      'owner-only file upload tracks $terminal through R03 and U03',
      () async {
        enqueueAccepted(terminal.name);
        recorder.setAnonymous(true);
        final batch = await session();
        final finished = Completer<void>();
        final subscription = container.listen(
          processingNotifierProvider(batch.processingSession),
          (_, jobs) {
            if (jobs[(audioId: _audio, jobId: _job)]?.phase == terminal &&
                !finished.isCompleted) {
              finished.complete();
            }
          },
        );
        addTearDown(subscription.close);
        await recorder.uploadFile(
          source,
          language: UploadLanguage.auto,
          mixed: true,
        );
        await finished.future.timeout(const Duration(seconds: 3));
        expect(state().selectedWorkspaceId, isNull);
        expect(state().accepted?.sessionId, _sessionId);
        expect(source.readAsBytesSync(), _wav);
        expect(Map.fromEntries((uploads().single.data as FormData).fields), {
          'language': '',
          'mixed': 'true',
        });
        expect(
          transport.requests.map((request) => (request.method, request.path)),
          [('POST', _uploadPath), ('GET', _statusPath), ('GET', _sessionPath)],
        );
        expect(transport.requests[1].queryParameters, {'job_id': _job});
      },
    );
  }

  test('U02 links to owner-only canonical while summary is pending', () async {
    final fixture =
        jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
            as Map<String, dynamic>;
    final canonical = fixture['speech'] as Map<String, dynamic>;
    canonical.addAll({
      'recording_id': _audio,
      'job_id': _job,
      'processing_version': _version,
      'access': {'owner_user_id': _owner, 'workspace_id': null},
    });
    transport
      ..enqueue(202, _receipt())
      ..enqueue(200, {
        'job_id': _job,
        'processing_version': _version,
        'workspace_id': null,
        'job_status': 'completed',
        'transcript_status': 'ready',
        'summary_status': 'pending',
        'summary_error': null,
      })
      ..enqueue(200, canonical);
    final batch = await session();
    const key = (audioId: _audio, jobId: _job);
    final ready = Completer<JobProgress>();
    final subscription = container.listen(
      processingNotifierProvider(batch.processingSession),
      (_, jobs) {
        final job = jobs[key];
        if (job != null && job.canonicalReady && !ready.isCompleted) {
          ready.complete(job);
        }
      },
    );
    addTearDown(subscription.close);
    recorder.setAnonymous(true);
    await recorder.uploadFile(source);
    final result = await ready.future.timeout(const Duration(seconds: 3));
    expect(result.job.sessionId, _sessionId);
    expect(result.canonical?.access.workspaceId, isNull);
    expect(result.canonical?.speakers.first.label, 'Speaker 1');
    expect(transport.requests.map((request) => request.path), [
      _uploadPath,
      _statusPath,
      '/meetings/results/$_audio/structured',
    ]);
  });

  test('owner-only rejects invalid language and WAV before sending', () async {
    recorder.setAnonymous(true);
    recorder.setLanguage(UploadLanguage.en);
    recorder.setMixed(true);
    expect(state().language, UploadLanguage.auto);
    recorder.setLanguage(UploadLanguage.ru);
    expect(state().mixed, isFalse);
    await recorder.uploadFile(source, language: UploadLanguage.ru, mixed: true);
    expect(state().status, RecordStatus.error);
    expect(source.readAsBytesSync(), _wav);
    source.writeAsStringSync('not WAV');
    await recorder.uploadFile(source);
    expect(state().status, RecordStatus.error);
    expect(source.readAsStringSync(), 'not WAV');
    expect(transport.requests, isEmpty);
    expect((await (await session()).uploads.list()).entries, isEmpty);
  });

  test(
    'logout cancels U02 and retains pending upload for the original owner',
    () async {
      recorder.setAnonymous(true);
      final delayed = transport.defer();
      final batch = await session();
      final sending = recorder.uploadFile(source);
      await transport.firstRequest.future.timeout(const Duration(seconds: 3));
      expect(state().status, RecordStatus.uploading);
      recorder.setAnonymous(false);
      expect(state().anonymous, isTrue);
      await container.read(authNotifierProvider.notifier).logout();
      delayed.complete(ScriptedAdapter.reply(202, _receipt()));
      await sending;
      expect(batch.isCurrent, isFalse);
      expect(state().anonymous, isFalse);
      expect(state().status, RecordStatus.idle);
      expect(state().accepted, isNull);
      expect(transport.requests.map((request) => request.path), [_uploadPath]);
      final retained = await PendingUploadStore(
        ownerId: _owner,
        isCurrentSession: () => true,
        applicationSupportDirectory: () async => support,
      ).list();
      expect(retained.entries.single.state, PendingUploadState.pending);
      expect(retained.entries.single.options.anonymous, isTrue);
    },
  );

  testWidgets('owner-only uses shared WAV picker and Stop dialog', (
    tester,
  ) async {
    transport.enqueue(200, {
      'data': [],
      'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
    });
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: RecordScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без рабочего пространства'));
    await tester.pumpAndSettle();
    expect(state().anonymous, isTrue);
    await tester.tap(find.text('Upload Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Перетащите файл WAV'), findsOneWidget);
    expect(find.text('Смешанная речь'), findsNWidgets(2));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.runAsync(recorder.startRecording);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Завершить запись?'), findsOneWidget);
    await tester.tap(find.text('Продолжить запись'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(capture.finishes, 0);
    expect(state().status, RecordStatus.recording);
    expect(uploads(), isEmpty);

    enqueueAccepted('expired');
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Завершить и отправить'));
    // Flush the widget future while the journal's real filesystem work runs.
    for (
      var attempt = 0;
      attempt < 300 &&
          state().status != RecordStatus.accepted &&
          state().status != RecordStatus.error;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(state().status, RecordStatus.accepted, reason: state().errorMessage);
    await tester.pumpAndSettle();
    expect(find.text('Отправка принята'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(capture.finishes, 1);
    expect(uploads().single.path, _uploadPath);
  });
}
