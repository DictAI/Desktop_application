import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/app.dart';
import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_screen.dart';
import 'package:dict_ai/features/workspace/data/dto/workspace_dto.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart' show InputDevice;

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _workspace = '22222222-2222-4222-8222-222222222222';
const _audio = '33333333-3333-4333-8333-333333333333';
const _job = '44444444-4444-4444-8444-444444444444';
const _statusPath = '/meetings/results/$_audio/speech-status';
const _dialogTitle = 'Завершить запись?';
const _continue = 'Продолжить запись';
const _send = 'Завершить и отправить';
const _motion = Duration(milliseconds: 250);

class _Capture implements AudioCapture {
  _Capture(this.file);

  final File file;
  int finishes = 0;
  int disposals = 0;
  Completer<void>? startGate;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  String get sourcePath => file.path;
  @override
  bool get supportsPause => true;
  @override
  Future<List<InputDevice>> listInputDevices() async => [];
  @override
  Future<void> start({InputDevice? device}) async {
    await startGate?.future;
    status = CaptureStatus.recording;
  }

  @override
  Future<void> pause() async => status = CaptureStatus.paused;
  @override
  Future<void> resume() async => status = CaptureStatus.recording;
  @override
  Future<File?> finish({required bool confirmed}) async {
    if (!confirmed) return null;
    finishes++;
    status = CaptureStatus.finished;
    return file;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    status = CaptureStatus.disposed;
  }
}

// 16 kHz mono PCM16 with two zero samples.
List<int> _validWav() => [
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
];

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final claims = encode({
    'iss': 'dictai-auth-v2',
    'aud': 'dictai-user',
    'user_id': _owner,
    'exp':
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
        1000,
  });
  return '${encode({'alg': 'HS256'})}.$claims.fixture';
}

Future<void> _animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_motion);
}

Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var attempt = 0; attempt < 300 && !done(); attempt++) {
    await tester.pump(const Duration(milliseconds: 5));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(done(), isTrue, reason: 'The recording operation did not settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late GoRouter router;
  late Dio dio;
  late ScriptedAdapter transport;
  late _Capture capture;
  late RecordNotifier record;
  Future<void> Function()? closeFixture;

  RecordState state() => container.read(recordNotifierProvider);
  String path() => router.routerDelegate.currentConfiguration.uri.path;
  Iterable<RequestOptions> uploads() =>
      transport.requests.where((request) => request.method == 'POST');

  void guardTest(String description, Future<void> Function(WidgetTester) run) {
    testWidgets(description, (tester) async {
      try {
        await run(tester);
      } finally {
        await closeFixture?.call();
        closeFixture = null;
      }
    });
  }

  Future<void> mount(WidgetTester tester, {bool anonymous = false}) async {
    resetStorageFakes();
    const storage = SecureStorage();
    await storage.saveToken(_token());
    final directory = Directory.systemTemp.createTempSync('dictai-exit-');
    capture = _Capture(
      File('${directory.path}/capture.wav')..writeAsBytesSync(_validWav()),
    );
    final workspace = WorkspaceDto(
      workspaceId: _workspace,
      ownerUserId: _owner,
      name: 'Recording workspace',
      createdAt: DateTime.utc(2026, 11, 9),
    );
    transport = ScriptedAdapter()
      ..enqueue(200, {
        'data': [workspace.toJson()],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
      });
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
        secureStorageProvider.overrideWithValue(storage),
        recordCaptureFactoryProvider.overrideWithValue(
          (_) => state().status == RecordStatus.starting
              ? capture
              : _Capture(capture.file),
        ),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => Directory('${directory.path}/support'),
        ),
      ],
    );
    dio = container.read(dioProvider)..httpClientAdapter = transport;
    router = container.read(routerProvider);
    record = container.read(recordNotifierProvider.notifier);
    if (anonymous) {
      record.setAnonymous(true);
    } else {
      router.go('/record?workspaceId=$_workspace', extra: workspace);
    }
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    closeFixture = () async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      dio.close(force: true);
      directory.deleteSync(recursive: true);
      resetStorageFakes();
      await tester.binding.setSurfaceSize(null);
    };
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    expect(path(), '/record');
  }

  Future<void> start(WidgetTester tester, {bool paused = false}) async {
    await tester.runAsync(record.startRecording);
    expect(state().status, RecordStatus.recording);
    if (paused) await record.togglePause();
    await _animate(tester);
  }

  for (final anonymous in [false, true]) {
    guardTest('Stop keeps capture on cancel and Escape, anonymous=$anonymous', (
      tester,
    ) async {
      await mount(tester, anonymous: anonymous);
      await start(tester, paused: anonymous);
      final previous = state().status;
      final stop = find.byIcon(Icons.stop_rounded);
      await tester.tap(stop);
      await _animate(tester);
      expect(find.text(_dialogTitle), findsOneWidget);
      expect(find.text(_send), findsOneWidget);
      await tester.tap(find.text(_continue));
      await _animate(tester);
      expect(find.text(_dialogTitle), findsNothing);
      await tester.tap(stop);
      await _animate(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _animate(tester);
      expect(find.text(_dialogTitle), findsNothing);
      await tester.tap(stop);
      await _animate(tester);
      await tester.tapAt(const Offset(24, 24));
      await _animate(tester);
      expect(find.text(_dialogTitle), findsNothing);
      expect(state().status, previous);
      expect(capture.finishes, 0);
      expect(uploads(), isEmpty);
    });
  }

  guardTest('sidebar, route, and Back share the paused capture guard', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, paused: true);
    for (final leave in <Future<void> Function()>[
      () => tester.tap(find.text('Results')),
      () async => router.go('/workspaces'),
      () async => expect(await router.routerDelegate.popRoute(), isTrue),
    ]) {
      await leave();
      await _animate(tester);
      expect(find.text(_dialogTitle), findsOneWidget);
      expect(path(), '/record');
      await tester.tap(find.text(_continue));
      await _animate(tester);
      expect(path(), '/record');
      expect(state().status, RecordStatus.paused);
      expect(state().selectedWorkspaceId, _workspace);
    }
    expect(capture.finishes, 0);
    expect(uploads(), isEmpty);
  });

  guardTest(
    'confirming a guarded exit sends one WAV and allows upload navigation',
    (tester) async {
      await mount(tester);
      await start(tester);
      final accepted = transport.defer();
      router.go('/workspaces');
      await _animate(tester);
      router.go('/results');
      await _animate(tester);
      expect(find.text(_dialogTitle), findsOneWidget);
      await tester.tap(find.text(_send));
      await tester.tap(find.text(_send), warnIfMissed: false);
      await _waitFor(
        tester,
        () => uploads().isNotEmpty || state().status == RecordStatus.error,
      );
      expect(find.byType(RecordScreen), findsOneWidget);
      expect(
        state().status,
        RecordStatus.uploading,
        reason: state().errorMessage,
      );
      expect(capture.finishes, 1);
      expect(uploads().single.path, '/ingest/v2/audio/upload');
      expect(
        Map.fromEntries(
          (uploads().single.data as FormData).fields,
        )['workspace_id'],
        _workspace,
      );

      await _animate(tester);
      await tester.tap(find.text('Workspaces'));
      await tester.pumpAndSettle();
      expect(path(), '/workspaces');
      expect(find.text(_dialogTitle), findsNothing);
      expect(state().status, RecordStatus.uploading);
      transport.enqueue(200, {
        'job_id': _job,
        'processing_version': 'fixture-v1',
        'workspace_id': _workspace,
        'job_status': 'queued',
        'transcript_status': 'pending',
        'summary_status': 'pending',
        'summary_error': null,
      });
      accepted.complete(
        ScriptedAdapter.reply(202, {
          'audio_id': _audio,
          'session_id': null,
          'job_id': _job,
          'processing_version': 'fixture-v1',
          'status_url': _statusPath,
        }),
      );
      await _waitFor(
        tester,
        () =>
            state().status == RecordStatus.accepted ||
            state().status == RecordStatus.error,
      );
      expect(
        state().status,
        RecordStatus.accepted,
        reason: state().errorMessage,
      );
      expect(path(), '/workspaces');
      expect(capture.finishes, 1);
      expect(uploads(), hasLength(1));
    },
  );

  guardTest('invalid WAV after confirmation stays on Record without upload', (
    tester,
  ) async {
    await mount(tester, anonymous: true);
    capture.file.writeAsStringSync('invalid WAV');
    await start(tester);
    router.go('/results');
    await _animate(tester);
    await tester.tap(find.text(_send));
    await _waitFor(tester, () => state().status == RecordStatus.error);
    await _animate(tester);
    expect(path(), '/record');
    expect(find.text(state().errorMessage!), findsOneWidget);
    expect(capture.finishes, 1);
    expect(uploads(), isEmpty);
  });

  guardTest(
    'navigation while capture starts cannot leave it in the background',
    (tester) async {
      await mount(tester, anonymous: true);
      final gate = Completer<void>();
      capture.startGate = gate;
      final starting = record.startRecording();
      await _animate(tester);
      expect(state().status, RecordStatus.starting);
      router.go('/results');
      await _animate(tester);
      expect(path(), '/record');
      expect(find.text(_dialogTitle), findsNothing);
      gate.complete();
      await _waitFor(tester, () => state().isActive);
      await starting;
      expect(path(), '/record');
      expect(uploads(), isEmpty);
    },
  );

  for (final unauthorized in [false, true]) {
    guardTest(
      'logout or 401 dismisses a stale confirmation, 401=$unauthorized',
      (tester) async {
        await mount(tester, anonymous: true);
        await start(tester);
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await _animate(tester);
        expect(find.text(_dialogTitle), findsOneWidget);
        if (unauthorized) {
          transport.enqueue(401, {'error': 'unauthorized'});
          final rejected = expectLater(
            dio.get('/protected'),
            throwsA(isA<DioException>()),
          );
          await tester.pumpAndSettle();
          await rejected;
        } else {
          await container.read(authNotifierProvider.notifier).logout();
        }
        await tester.pumpAndSettle();
        expect(path(), '/login');
        expect(find.text(_dialogTitle), findsNothing);
        expect(capture.disposals, 1);
        expect(capture.finishes, 0);
        expect(uploads(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
