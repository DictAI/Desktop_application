import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/presentation/discard_recording_dialog.dart';
import 'package:dict_ai/features/record/presentation/discard_recording_screen.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
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

List<int> _wav() => [
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

String _jwt() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': _owner, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

class _Capture implements AudioCapture, AudioCaptureEvents {
  _Capture(this.file);
  final File file;
  final events = StreamController<CaptureEvent>.broadcast(sync: true);
  int starts = 0, pauses = 0, resumes = 0, finishes = 0, disposals = 0;
  bool failDispose = false;
  Completer<void>? pauseGate, resumeGate, disposeGate, finishGate, startGate;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  Stream<CaptureEvent> get captureEvents => events.stream;
  @override
  String get sourcePath => file.path;
  @override
  bool get supportsPause => true;
  @override
  Future<List<InputDevice>> listInputDevices() async => [];
  @override
  Future<void> start({InputDevice? device}) async {
    starts++;
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
  Future<void> resume() async {
    resumes++;
    await resumeGate?.future;
    status = CaptureStatus.recording;
  }

  @override
  Future<File?> finish({required bool confirmed}) async {
    expect(confirmed, isTrue);
    finishes++;
    await finishGate?.future;
    status = CaptureStatus.finished;
    return file;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await disposeGate?.future;
    if (failDispose) {
      throw const ServerException('Не удалось освободить микрофон.');
    }
    status = CaptureStatus.disposed;
  }

  void interrupt() {
    status = CaptureStatus.paused;
    events.add(
      const CaptureEvent(CaptureStatus.paused, message: 'Прерывание микрофона'),
    );
  }
}

class _Transport extends ScriptedAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      expect(options.path, '/ingest/v2/audio/upload');
      return ScriptedAdapter.reply(202, {
        'audio_id': _audio,
        'session_id': null,
        'job_id': _job,
        'processing_version': 'fixture-v1',
        'status_url': '/meetings/results/$_audio/speech-status',
      });
    }
    if (options.path == '/protected') {
      return ScriptedAdapter.reply(401, {'error': 'unauthorized'});
    }
    if (options.path.endsWith('/speech-status')) {
      return ScriptedAdapter.reply(200, {
        'job_id': _job,
        'processing_version': 'fixture-v1',
        'workspace_id': _workspace,
        'job_status': 'failed',
        'transcript_status': 'failed',
        'summary_status': 'pending',
        'summary_error': null,
      });
    }
    if (options.path == '/workspaces/') {
      return ScriptedAdapter.reply(200, {
        'data': [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      });
    }
    if (options.path == '/meetings/results') {
      return ScriptedAdapter.reply(200, {
        'data': [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      });
    }
    throw StateError('Unexpected fixture request ${options.path}');
  }
}

class _Fixture {
  _Fixture() {
    resetStorageFakes();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => Directory('${directory.path}/support'),
        ),
        recordCaptureFactoryProvider.overrideWithValue((_) => capture),
      ],
    );
    dio = container.read(dioProvider)..httpClientAdapter = transport;
    record.selectWorkspace(_workspace, 'Original workspace');
    record.setLanguage(UploadLanguage.ru);
  }
  final directory = Directory.systemTemp.createTempSync('dictai-discard-');
  late final capture = _Capture(
    File('${directory.path}/capture.wav')..writeAsBytesSync(_wav()),
  );
  late final unrelated = File('${directory.path}/user-original.wav')
    ..writeAsBytesSync(_wav());
  final transport = _Transport();
  late final ProviderContainer container;
  late final Dio dio;
  GoRouter? router;
  RecordNotifier get record => container.read(recordNotifierProvider.notifier);
  RecordState get state => container.read(recordNotifierProvider);
  Iterable<RequestOptions> get posts =>
      transport.requests.where((r) => r.method == 'POST');
  String get path => router!.routerDelegate.currentConfiguration.uri.path;
  Future<void> signIn() => const SecureStorage().saveToken(_jwt());
  bool _disposed = false;
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    router?.dispose();
    container.dispose();
    dio.close(force: true);
    await capture.events.close();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    resetStorageFakes();
  }
}

Future<void> _animate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _wait(WidgetTester tester, bool Function() done) async {
  for (var attempt = 0; attempt < 200 && !done(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(done(), isTrue, reason: 'Operation failed to settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    fixture = _Fixture();
    await fixture.signIn();
  });
  tearDown(() async {
    await fixture.dispose();
  });

  test(
    'discard is idempotent, waits for native release and removes only its source',
    () async {
      final source = fixture.capture.file;
      final other = fixture.unrelated;
      await fixture.record.startRecording();
      await fixture.record.togglePause();
      final release = Completer<void>();
      fixture.capture.disposeGate = release;
      final first = fixture.record.discardRecording(confirmed: true);
      final second = fixture.record.discardRecording(confirmed: true);
      expect(first, same(second));
      await Future<void>.delayed(Duration.zero);
      expect(source.existsSync(), isTrue);
      await fixture.record.finishRecording(confirmed: true);
      await fixture.record.togglePause();
      await fixture.record.startRecording();
      release.complete();
      expect(await first, isTrue);
      expect(source.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(fixture.state.status, RecordStatus.idle);
      expect(fixture.capture.finishes, 0);
      expect(fixture.capture.disposals, 1);
      expect(fixture.capture.starts, 1);
      expect(fixture.posts, isEmpty);
      final session = await fixture.container.read(batchSessionProvider.future);
      expect((await session.uploads.list()).entries, isEmpty);
    },
  );

  for (final invalidate in ['logout', '401']) {
    test(
      '$invalidate stops capture before deleting only its unposted WAV',
      () async {
        final source = fixture.capture.file;
        final external = fixture.unrelated;
        await fixture.record.startRecording();
        final stopped = Completer<void>();
        fixture.capture.disposeGate = stopped;
        if (invalidate == 'logout') {
          await fixture.container.read(authNotifierProvider.notifier).logout();
        } else {
          await expectLater(
            fixture.dio.get('/protected'),
            throwsA(isA<DioException>()),
          );
        }
        expect(fixture.state.status, RecordStatus.idle);
        expect(
          source.existsSync(),
          isTrue,
          reason: 'Native writer still owns the file',
        );
        stopped.complete();
        for (var i = 0; i < 100 && source.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(source.existsSync(), isFalse);
        expect(external.existsSync(), isTrue);
        expect(fixture.capture.disposals, 1);
        expect(fixture.posts, isEmpty);
      },
    );
  }

  test(
    'logout during finish removes a late owned WAV without preparing a POST',
    () async {
      await fixture.record.startRecording();
      fixture.capture.finishGate = Completer<void>();
      final finishing = fixture.record.finishRecording(confirmed: true);
      await Future<void>.delayed(Duration.zero);
      await fixture.container.read(authNotifierProvider.notifier).logout();
      fixture.capture.finishGate!.complete();
      await finishing;
      for (var i = 0; i < 100 && fixture.capture.file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(fixture.capture.file.existsSync(), isFalse);
      expect(fixture.unrelated.existsSync(), isTrue);
      expect(fixture.state.status, RecordStatus.idle);
      expect(fixture.posts, isEmpty);
    },
  );

  test(
    'failed capture release retains its source ownership until logout cleanup',
    () async {
      await fixture.record.startRecording();
      fixture.capture.events.add(
        const CaptureEvent(
          CaptureStatus.failed,
          message: 'Synthetic encoder failure',
        ),
      );
      for (var i = 0; i < 100 && fixture.capture.disposals == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(fixture.state.status, RecordStatus.error);
      expect(fixture.capture.file.existsSync(), isTrue);
      await fixture.container.read(authNotifierProvider.notifier).logout();
      for (var i = 0; i < 100 && fixture.capture.file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(fixture.capture.file.existsSync(), isFalse);
      expect(fixture.unrelated.existsSync(), isTrue);
      expect(fixture.posts, isEmpty);
    },
  );

  test(
    'unconfirmed discard preserves paused source without native cleanup',
    () async {
      await fixture.record.startRecording();
      await fixture.record.togglePause();
      expect(await fixture.record.discardRecording(confirmed: false), isFalse);
      expect(fixture.state.status, RecordStatus.paused);
      expect(fixture.capture.file.existsSync(), isTrue);
      expect(fixture.capture.disposals, 0);
    },
  );

  test(
    'native cleanup failure retains ownership and permits an explicit retry',
    () async {
      await fixture.record.startRecording();
      fixture.capture.failDispose = true;
      expect(await fixture.record.discardRecording(confirmed: true), isFalse);
      expect(fixture.state.status, RecordStatus.error);
      expect(fixture.state.discardPending, isTrue);
      expect(fixture.record.canDiscard, isTrue);
      expect(fixture.capture.file.existsSync(), isTrue);
      fixture.record.reset();
      await fixture.record.startRecording();
      expect(fixture.state.status, RecordStatus.error);
      fixture.capture.failDispose = false;
      expect(await fixture.record.discardRecording(confirmed: true), isTrue);
      expect(fixture.state.status, RecordStatus.idle);
      expect(fixture.capture.file.existsSync(), isFalse);
      expect(fixture.posts, isEmpty);
    },
  );

  test(
    'filesystem deletion failure is visible and retry does not lose ownership',
    () async {
      await fixture.record.startRecording();
      final file = fixture.capture.file;
      file.deleteSync();
      final blocked = Directory(file.path)..createSync();
      File('${blocked.path}/keep').writeAsStringSync('synthetic obstruction');
      expect(await fixture.record.discardRecording(confirmed: true), isFalse);
      expect(fixture.state.discardPending, isTrue);
      expect(fixture.state.errorMessage, contains('удалить'));
      blocked.deleteSync(recursive: true);
      file.writeAsBytesSync(_wav());
      expect(await fixture.record.discardRecording(confirmed: true), isTrue);
      expect(file.existsSync(), isFalse);
    },
  );

  test(
    'discard serializes with pause and prevents late send or resume',
    () async {
      await fixture.record.startRecording();
      fixture.capture.pauseGate = Completer<void>();
      final pause = fixture.record.togglePause();
      final discard = fixture.record.discardRecording(confirmed: true);
      await fixture.record.finishRecording(confirmed: true);
      await fixture.record.togglePause();
      fixture.capture.pauseGate!.complete();
      await pause;
      expect(await discard, isTrue);
      expect(fixture.posts, isEmpty);
      expect(fixture.capture.finishes, 0);
      expect(fixture.capture.resumes, 0);
    },
  );

  test(
    'send during resume does not finish or post a stale paused capture',
    () async {
      await fixture.record.startRecording();
      await fixture.record.togglePause();
      fixture.capture.resumeGate = Completer<void>();
      final resume = fixture.record.togglePause();
      await fixture.record.sendPausedRecording();
      fixture.capture.resumeGate!.complete();
      await resume;
      expect(fixture.state.status, RecordStatus.recording);
      expect(fixture.capture.finishes, 0);
      expect(fixture.posts, isEmpty);
    },
  );

  test(
    'session invalidation during discard never updates the new session',
    () async {
      await fixture.record.startRecording();
      fixture.capture.disposeGate = Completer<void>();
      final discard = fixture.record.discardRecording(confirmed: true);
      await Future<void>.delayed(Duration.zero);
      await fixture.container.read(authNotifierProvider.notifier).logout();
      fixture.capture.disposeGate!.complete();
      expect(await discard, isFalse);
      expect(fixture.state.status, RecordStatus.idle);
      expect(fixture.state.discardPending, isFalse);
      expect(fixture.posts, isEmpty);
    },
  );

  void widgetTest(String description, WidgetTesterCallback run) {
    testWidgets(description, (tester) async {
      try {
        await run(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await fixture.dispose();
        await tester.binding.setSurfaceSize(null);
      }
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    fixture.router = fixture.container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp.router(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          routerConfig: fixture.router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.path, '/record');
  }

  Future<void> start(WidgetTester tester, {bool paused = false}) async {
    await tester.runAsync(fixture.record.startRecording);
    if (paused) await fixture.record.togglePause();
    await _animate(tester);
  }

  widgetTest(
    'primary action pauses/resumes the same capture and only paused send posts once',
    (tester) async {
      await mount(tester);
      await start(tester);
      expect(find.text('Отправить'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Приостановить запись'));
      await _animate(tester);
      expect(fixture.state.status, RecordStatus.paused);
      expect(find.text('Отправить'), findsOneWidget);
      expect(find.byTooltip('Удалить запись'), findsOneWidget);
      expect(fixture.capture.finishes, 0);
      await tester.tap(find.bySemanticsLabel('Продолжить запись'));
      await _animate(tester);
      expect(fixture.state.status, RecordStatus.recording);
      expect(find.text('Отправить'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Приостановить запись'));
      await _animate(tester);
      fixture.record.setLanguage(UploadLanguage.en);
      fixture.record.selectWorkspace(_audio, 'Must not replace');
      await tester.tap(find.text('Отправить'));
      await tester.tap(find.text('Отправить'), warnIfMissed: false);
      await _wait(tester, () => fixture.state.status == RecordStatus.accepted);
      expect(fixture.capture.starts, 1);
      expect(fixture.capture.finishes, 1);
      expect(fixture.posts, hasLength(1));
      final fields = Map.fromEntries(
        (fixture.posts.single.data as FormData).fields,
      );
      expect(fields['workspace_id'], _workspace);
      expect(fields['language'], 'ru');
    },
  );

  widgetTest('invalid WAV send stays on Record with an error and no POST', (
    tester,
  ) async {
    await mount(tester);
    fixture.capture.file.writeAsStringSync('invalid synthetic WAV');
    await start(tester, paused: true);
    await tester.tap(find.text('Отправить'));
    await _wait(tester, () => fixture.state.status == RecordStatus.error);
    expect(fixture.path, '/record');
    expect(fixture.capture.finishes, 1);
    expect(fixture.posts, isEmpty);
  });

  widgetTest('starting blocks navigation without a destructive confirmation', (
    tester,
  ) async {
    await mount(tester);
    fixture.capture.startGate = Completer<void>();
    final starting = fixture.record.startRecording();
    await _animate(tester);
    fixture.router!.go('/results');
    await _animate(tester);
    expect(fixture.path, '/record');
    expect(find.byType(DiscardRecordingScreen), findsNothing);
    fixture.capture.startGate!.complete();
    await _wait(tester, () => fixture.state.isActive);
    await starting;
    expect(fixture.path, '/record');
  });

  widgetTest('failed cleanup leaves an explicit delete retry on Record', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, paused: true);
    fixture.capture.failDispose = true;
    await tester.tap(find.byTooltip('Удалить запись'));
    await _animate(tester);
    await tester.tap(find.text('Удалить'));
    await _wait(tester, () => fixture.state.status == RecordStatus.error);
    await _animate(tester);
    expect(fixture.state.discardPending, isTrue);
    expect(find.text('Отправить'), findsNothing);
    fixture.capture.failDispose = false;
    await tester.ensureVisible(find.byTooltip('Удалить запись'));
    await tester.tap(find.byTooltip('Удалить запись'));
    await _animate(tester);
    await tester.tap(find.text('Удалить'));
    await _wait(tester, () => fixture.state.status == RecordStatus.idle);
    expect(fixture.capture.file.existsSync(), isFalse);
    expect(fixture.posts, isEmpty);
  });

  widgetTest(
    'delete cross cancel, Escape and Back preserve paused capture; confirm remains on Record',
    (tester) async {
      await mount(tester);
      await start(tester, paused: true);
      for (final close in <Future<void> Function()>[
        () => tester.tap(find.text('Оставить запись')),
        () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
        () async {
          await Navigator.of(
            tester.element(find.byType(DiscardRecordingDialog)),
          ).maybePop();
        },
      ]) {
        await tester.tap(find.byTooltip('Удалить запись'));
        await _animate(tester);
        expect(find.text('Удалить запись?'), findsOneWidget);
        await close();
        await _animate(tester);
        expect(fixture.state.status, RecordStatus.paused);
        expect(fixture.capture.disposals, 0);
        expect(fixture.capture.file.existsSync(), isTrue);
      }
      await tester.tap(find.byTooltip('Удалить запись'));
      await _animate(tester);
      await tester.tap(find.text('Удалить'));
      await _wait(tester, () => fixture.state.status == RecordStatus.idle);
      expect(fixture.path, '/record');
      expect(fixture.capture.file.existsSync(), isFalse);
      expect(fixture.posts, isEmpty);
    },
  );

  for (final paused in [false, true]) {
    widgetTest(
      'tabs/route/system Back offer a separate cancellation page; stay preserves state paused=$paused',
      (tester) async {
        await mount(tester);
        await start(tester, paused: paused);
        for (final leave in <Future<void> Function()>[
          () => tester.tap(find.text('Results')),
          () async => fixture.router!.go('/workspaces?from=record'),
          () async {
            unawaited(fixture.router!.routerDelegate.popRoute());
          },
        ]) {
          await leave();
          await _animate(tester);
          expect(find.byType(DiscardRecordingScreen), findsOneWidget);
          expect(fixture.path, '/record');
          await tester.tap(find.text('Остаться'));
          await _animate(tester);
          expect(
            fixture.state.status,
            paused ? RecordStatus.paused : RecordStatus.recording,
          );
          expect(fixture.capture.finishes, 0);
          expect(fixture.capture.disposals, 0);
        }
        expect(fixture.posts, isEmpty);
      },
    );
  }

  widgetTest(
    'confirmed exit preserves the first route query/extra once despite another navigation',
    (tester) async {
      await mount(tester);
      await start(tester);
      final extra = WorkspaceDto(
        workspaceId: _workspace,
        ownerUserId: _owner,
        name: 'Intent',
        createdAt: DateTime.utc(2026),
      );
      fixture.router!.go('/workspaces?source=record', extra: extra);
      await _animate(tester);
      fixture.router!.go('/results');
      await _animate(tester);
      expect(find.byType(DiscardRecordingScreen), findsOneWidget);
      await tester.tap(find.text('Отменить запись и выйти'));
      await _wait(tester, () => fixture.path == '/workspaces');
      expect(
        fixture.router!.routerDelegate.currentConfiguration.uri.queryParameters,
        {'source': 'record'},
      );
      expect(
        fixture.router!.routerDelegate.currentConfiguration.extra,
        same(extra),
      );
      expect(fixture.capture.disposals, 1);
      expect(fixture.capture.file.existsSync(), isFalse);
      expect(fixture.posts, isEmpty);
    },
  );

  widgetTest(
    'confirmation Back preserves recording; interruption while open is not undone',
    (tester) async {
      await mount(tester);
      await start(tester);
      fixture.router!.go('/results');
      await _animate(tester);
      fixture.capture.interrupt();
      await _animate(tester);
      expect(fixture.state.status, RecordStatus.paused);
      await tester.tap(find.byType(BackButton));
      await _animate(tester);
      expect(fixture.path, '/record');
      expect(fixture.state.status, RecordStatus.paused);
      expect(fixture.capture.resumes, 0);
      expect(fixture.capture.disposals, 0);
    },
  );

  widgetTest('intentional logout confirms before credentials are cleared', (
    tester,
  ) async {
    await mount(tester);
    await start(tester, paused: true);
    await tester.tap(find.byTooltip('Log out'));
    await _animate(tester);
    expect(find.byType(DiscardRecordingScreen), findsOneWidget);
    expect(await const SecureStorage().getToken(), isNotNull);
    await tester.tap(find.text('Остаться'));
    await _animate(tester);
    expect(await const SecureStorage().getToken(), isNotNull);
    expect(fixture.state.status, RecordStatus.paused);
    await tester.tap(find.byTooltip('Log out'));
    await _animate(tester);
    await tester.tap(find.text('Отменить запись и выйти'));
    await _wait(tester, () => fixture.path == '/login');
    expect(await const SecureStorage().getToken(), isNull);
    expect(fixture.capture.file.existsSync(), isFalse);
    expect(fixture.posts, isEmpty);
  });

  for (final dialog in [false, true]) {
    widgetTest(
      'forced 401 dismisses stale ${dialog ? 'delete dialog' : 'exit page'} and cannot send',
      (tester) async {
        await mount(tester);
        await start(tester, paused: dialog);
        if (dialog) {
          await tester.tap(find.byTooltip('Удалить запись'));
        } else {
          fixture.router!.go('/results');
        }
        await _animate(tester);
        final rejected = expectLater(
          fixture.dio.get('/protected'),
          throwsA(isA<DioException>()),
        );
        await _wait(tester, () => fixture.path == '/login');
        await rejected;
        await _animate(tester);
        expect(find.byType(DiscardRecordingScreen), findsNothing);
        expect(find.byType(DiscardRecordingDialog), findsNothing);
        expect(fixture.capture.disposals, 1);
        expect(fixture.capture.finishes, 0);
        expect(fixture.posts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  widgetTest(
    'both confirmations remain usable in narrow landscape at text scale two',
    (tester) async {
      await mount(tester, size: const Size(320, 375), textScale: 2);
      await start(tester, paused: true);
      await tester.ensureVisible(find.byTooltip('Удалить запись'));
      await tester.tap(find.byTooltip('Удалить запись'));
      await _animate(tester);
      await tester.ensureVisible(find.text('Оставить запись'));
      await tester.tap(find.text('Оставить запись'));
      await _animate(tester);
      fixture.router!.go('/results');
      await _animate(tester);
      await tester.ensureVisible(find.text('Отменить запись и выйти'));
      await tester.ensureVisible(find.text('Остаться'));
      await tester.tap(find.text('Остаться'));
      await _animate(tester);
      expect(fixture.state.status, RecordStatus.paused);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 375.0, 430.0]) {
    widgetTest(
      'pause controls and both confirmations fit $width with large text',
      (tester) async {
        await mount(tester, size: Size(width, 812), textScale: 2);
        await start(tester, paused: true);
        await tester.ensureVisible(find.text('Отправить'));
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Отправить')).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byTooltip('Удалить запись'));
        await _animate(tester);
        await tester.ensureVisible(find.text('Оставить запись'));
        await tester.tap(find.text('Оставить запись'));
        await _animate(tester);
        fixture.router!.go('/results');
        await _animate(tester);
        await tester.ensureVisible(find.text('Отменить запись и выйти'));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Остаться'));
        await _animate(tester);
      },
    );
  }
}
