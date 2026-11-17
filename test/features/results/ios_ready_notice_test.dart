import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/lifecycle/ios_lifecycle_observer.dart';
import 'package:dict_ai/core/shell/main_shell.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/record/data/v2_upload_api.dart';
import 'package:dict_ai/features/record/presentation/record_exit_guard.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/results/data/pending_job_store.dart';
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/features/results/presentation/result_detail_screen.dart';
import 'package:dict_ai/features/results/presentation/result_ready_notice.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart' show InputDevice;

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '99999999-9999-4999-8999-999999999999';
const _audio = '22222222-2222-4222-8222-222222222222';
const _job = '33333333-3333-4333-8333-333333333333';
const _otherJob = '44444444-4444-4444-8444-444444444444';
const _key = (audioId: _audio, jobId: _job);
const _otherKey = (audioId: _audio, jobId: _otherJob);
const _notice = Key('result-ready-notice');
const _openLabel = 'Транскрипт готов. Открыть';
const _storage = SecureStorage(namespace: 'ios-ready-fixture');

String _token(String owner) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

class _Adapter extends ScriptedAdapter {
  String owner = _owner;
  String latestJob = _job;
  String transcript = 'ready';
  int canonicalCode = 200;
  int statusCode = 200;
  Completer<ResponseBody>? heldCanonical;

  Map<String, dynamic> status(String jobId) => {
    'job_id': jobId,
    'processing_version': 'fixture-v1',
    'workspace_id': null,
    'job_status': transcript == 'ready' ? 'completed' : 'running',
    'transcript_status': transcript,
    'summary_status': 'pending',
    'summary_error': null,
  };

  Map<String, dynamic> canonical(String audioId, String jobId) {
    final fixture =
        (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
                as Map)['speech']
            as Map<String, dynamic>;
    fixture['recording_id'] = audioId;
    fixture['job_id'] = jobId;
    fixture['processing_version'] = 'fixture-v1';
    fixture['access']['owner_user_id'] = owner;
    return fixture;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelled,
  ) async {
    requests.add(options);
    if (options.path == '/auth/login') {
      return ScriptedAdapter.reply(200, {'token': _token(owner)});
    }
    if (options.path == '/protected') {
      return ScriptedAdapter.reply(401, {'error': 'unauthorized'});
    }
    final jobId = options.queryParameters['job_id'] as String? ?? latestJob;
    if (options.path.endsWith('/speech-status')) {
      return ScriptedAdapter.reply(
        statusCode,
        statusCode == 200 ? status(jobId) : {'error': 'unavailable'},
      );
    }
    if (options.path.endsWith('/structured')) {
      if (heldCanonical case final held?) {
        heldCanonical = null;
        return held.future;
      }
      if (canonicalCode != 200) {
        final pending = status(jobId);
        pending['transcript_status'] = 'pending';
        return ScriptedAdapter.reply(canonicalCode, pending);
      }
      return ScriptedAdapter.reply(
        200,
        canonical(Uri.decodeComponent(options.path.split('/')[3]), jobId),
      );
    }
    throw StateError('Unexpected fixture request ${options.path}');
  }
}

Future<void> _persistAccepted(Directory support) async {
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  data.setUint32(4, 40, Endian.little);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  data.setUint32(40, 4, Endian.little);
  final source = File('${support.path}/accepted-source.wav');
  await source.writeAsBytes(bytes);
  final store = PendingUploadStore(
    ownerId: _owner,
    isCurrentSession: () => true,
    applicationSupportDirectory: () async => support,
  );
  final draft = await store.prepare(
    source: source,
    options: UploadOptions(
      anonymous: false,
      workspaceId: '55555555-5555-4555-8555-555555555555',
      idempotencyKey: 'ready-notice-relaunch-fixture',
      source: const ImportedWavUploadSource(),
      language: UploadLanguage.ru,
    ),
  );
  final adapter = ScriptedAdapter()
    ..enqueue(202, {
      'audio_id': _audio,
      'job_id': _job,
      'session_id': null,
      'processing_version': 'fixture-v1',
      'status_url': '/meetings/results/$_audio/speech-status',
    });
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  try {
    await store.submit(
      draft.localId,
      api: V2UploadApi(dio),
      cancelToken: CancelToken(),
    );
  } finally {
    dio.close(force: true);
  }
}

class _ScreenProbe extends StatefulWidget {
  const _ScreenProbe(this.harness);
  final _Harness harness;
  @override
  State<_ScreenProbe> createState() => _ScreenProbeState();
}

class _ScreenProbeState extends State<_ScreenProbe> {
  @override
  void initState() {
    super.initState();
    widget.harness.screenCreations++;
  }

  @override
  void dispose() {
    widget.harness.screenDisposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Record fixture'));
}

class _Capture implements AudioCapture {
  _Capture(this.file);
  final File file;
  int disposals = 0;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  bool get supportsPause => true;
  @override
  String get sourcePath => file.path;
  @override
  Future<List<InputDevice>> listInputDevices() async => [];
  @override
  Future<void> start({InputDevice? device}) async =>
      status = CaptureStatus.recording;
  @override
  Future<void> pause() async => status = CaptureStatus.paused;
  @override
  Future<void> resume() async => status = CaptureStatus.recording;
  @override
  Future<File?> finish({required bool confirmed}) async => file;
  @override
  Future<void> dispose() async {
    disposals++;
    status = CaptureStatus.disposed;
  }
}

class _Harness {
  _Harness(this.directory, this.lifecycle, this.container, this.dio);
  final Directory directory;
  final IosLifecycleObserver lifecycle;
  final ProviderContainer container;
  final Dio dio;
  late BatchSession session;
  late final capture = _Capture(
    File('${directory.path}/capture.wav')..writeAsBytesSync([0, 0]),
  );
  final adapter = _Adapter();
  final subscriptions = <ProviderSubscription<dynamic>>[];
  GoRouter? router;
  int screenCreations = 0, screenDisposals = 0;

  static Future<_Harness> create({bool restoreAccepted = false}) async {
    resetStorageFakes();
    await _storage.saveToken(_token(_owner));
    final directory = await Directory.systemTemp.createTemp('dictai-ready-');
    if (restoreAccepted) await _persistAccepted(directory);
    final lifecycle = IosLifecycleObserver()
      ..didChangeAppLifecycleState(AppLifecycleState.resumed);
    late _Harness harness;
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
        secureStorageProvider.overrideWithValue(_storage),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        resultTemporaryDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        iosLifecycleObserverProvider.overrideWithValue(lifecycle),
        recordCaptureFactoryProvider.overrideWithValue((_) => harness.capture),
      ],
    );
    final dio = container.read(dioProvider);
    harness = _Harness(directory, lifecycle, container, dio);
    dio.httpClientAdapter = harness.adapter;
    harness.session = await container.read(batchSessionProvider.future);
    harness.listenNotices();
    return harness;
  }

  ProcessingNotifier get tracker => container.read(
    processingNotifierProvider(session.processingSession).notifier,
  );
  ResultReadyNoticeController get controller =>
      container.read(resultReadyNoticeProvider(session).notifier);
  List<ProcessingJob> get notices =>
      container.read(resultReadyNoticeProvider(session));

  void listenNotices() {
    subscriptions.add(
      container.listen(resultReadyNoticeProvider(session), (_, __) {}),
    );
  }

  Future<void> track({String audioId = _audio, String jobId = _job}) async {
    tracker.track(
      ProcessingJob(ownerId: session.ownerId, audioId: audioId, jobId: jobId),
    );
    await until(() {
      final progress = container.read(
        processingNotifierProvider(session.processingSession),
      )[(audioId: audioId, jobId: jobId)];
      return progress?.status != null;
    });
  }

  Future<void> until(bool Function() predicate) async {
    for (var i = 0; i < 300 && !predicate(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(predicate(), isTrue, reason: 'Fixture failed to settle');
  }

  GoRouter createRouter({String initial = '/record'}) => router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/record',
            onExit: (context) =>
                container.read(recordExitGuardProvider).canLeave(context),
            builder: (_, __) => _ScreenProbe(this),
          ),
          GoRoute(
            path: '/workspaces',
            builder: (_, __) => const Center(child: Text('Workspace fixture')),
          ),
          GoRoute(
            path: '/results',
            builder: (_, __) => const Center(child: Text('Library fixture')),
            routes: [
              GoRoute(
                path: ':audioId',
                builder: (_, state) => ResultDetailScreen(
                  audioId: state.pathParameters['audioId']!,
                  jobId: state.uri.queryParameters['job_id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (_, __) => const Text('Login fixture')),
    ],
  );

  Future<void> close() async {
    router?.dispose();
    for (final subscription in subscriptions) {
      subscription.close();
    }
    container.dispose();
    lifecycle.dispose();
    dio.close(force: true);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _wait(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 200 && !predicate(); i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3)),
    );
  }
  expect(predicate(), isTrue, reason: 'Widget failed to settle');
}

Future<_Harness> _mount(
  WidgetTester tester, {
  String initial = '/record',
  Size size = const Size(320, 568),
  double scale = 1,
  bool restoreAccepted = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  final harness = (await tester.runAsync(
    () => _Harness.create(restoreAccepted: restoreAccepted),
  ))!;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: MaterialApp.router(
        theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
        routerConfig: harness.createRouter(initial: initial),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await _pump(tester);
  _mountedHarness = harness;
  return harness;
}

_Harness? _mountedHarness;

void _widgetTest(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      final harness = _mountedHarness;
      _mountedHarness = null;
      if (harness != null) await tester.runAsync(harness.close);
      await tester.binding.setSurfaceSize(null);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'notice requires canonical bytes and ignores independent pending summary',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.canonicalCode = 202;
      await h.track();
      expect(h.notices, isEmpty);
      h.adapter.canonicalCode = 200;
      await h.tracker.refresh(_key);
      expect(h.notices.map((job) => job.key), [_key]);
      final requests = h.adapter.requests.length;
      h.container.read(resultReadyNoticeProvider(h.session));
      h.container.read(resultReadyNoticeProvider(h.session));
      await Future<void>.delayed(Duration.zero);
      expect(h.adapter.requests, hasLength(requests));
      expect(
        h.adapter.requests.any(
          (request) => request.path.contains('/documents/'),
        ),
        isFalse,
      );
    },
  );

  test(
    'queue acknowledges exact jobs once across polling and repeated resume',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.track();
      await h.track(jobId: _otherJob);
      expect(h.notices.map((job) => job.key), [_key, _otherKey]);
      h.controller.acknowledge(_key);
      for (var i = 0; i < 3; i++) {
        h.lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        h.lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await h.tracker.refresh(_key);
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.notices.map((job) => job.key), [_otherKey]);
      h.controller.acknowledge(_otherKey);
      await h.tracker.refresh(_otherKey);
      expect(h.notices, isEmpty);
    },
  );

  test(
    'delete and lost access remove notices and reject late canonical',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.track();
      h.adapter.statusCode = 404;
      await h.tracker.refresh(_key);
      expect(h.notices, isEmpty);
      h.adapter.statusCode = 200;
      await h.tracker.refresh(_key);
      expect(h.notices, hasLength(1));
      h.tracker.removeAudio(_audio);
      expect(h.notices, isEmpty);
      expect(h.controller.canOpen(_key), isFalse);
      h.tracker.track(
        const ProcessingJob(ownerId: _owner, audioId: _audio, jobId: _otherJob),
      );
      expect(h.notices, isEmpty);
    },
  );

  test('delete during canonical read prevents late result notice', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    final held = Completer<ResponseBody>();
    h.adapter.heldCanonical = held;
    h.tracker.track(
      const ProcessingJob(ownerId: _owner, audioId: _audio, jobId: _job),
    );
    await h.until(() => h.adapter.requests.length == 2);
    h.tracker.removeAudio(_audio);
    held.complete(
      ScriptedAdapter.reply(200, h.adapter.canonical(_audio, _job)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(h.notices, isEmpty);
    expect(h.controller.canOpen(_key), isFalse);
  });

  test(
    'logout clears notice synchronously before a late old canonical',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.track();
      final controller = h.controller;
      final held = Completer<ResponseBody>();
      h.adapter.heldCanonical = held;
      h.tracker.track(
        const ProcessingJob(ownerId: _owner, audioId: _audio, jobId: _otherJob),
      );
      await h.until(() => h.adapter.requests.length == 4);
      final logout = h.container.read(authNotifierProvider.notifier).logout();
      expect(h.session.isCurrent, isFalse);
      expect(controller.canOpen(_key), isFalse);
      expect(h.notices, isEmpty);
      held.complete(
        ScriptedAdapter.reply(200, h.adapter.canonical(_audio, _otherJob)),
      );
      await logout;
      await Future<void>.delayed(Duration.zero);
      expect(h.notices, isEmpty);
    },
  );

  test(
    'matched 401 clears current notice and does not create another poller',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.track();
      final previous = h.controller;
      await expectLater(
        h.dio.get<void>('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(h.session.isCurrent, isFalse);
      expect(previous.canOpen(_key), isFalse);
      expect(h.notices, isEmpty);
      final requests = h.adapter.requests.length;
      h.lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      h.lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(h.adapter.requests, hasLength(requests));
    },
  );

  _widgetTest(
    'relaunch restores accepted job without POST or startup redirect',
    (tester) async {
      final h = await _mount(
        tester,
        initial: '/workspaces',
        restoreAccepted: true,
      );
      await _wait(tester, () => find.byKey(_notice).evaluate().isNotEmpty);
      expect(
        h.router!.routerDelegate.currentConfiguration.uri.path,
        '/workspaces',
      );
      expect(h.notices.map((job) => job.key), [_key]);
      expect(h.adapter.requests, hasLength(2));
      expect(
        h.adapter.requests.every((request) => request.method == 'GET'),
        isTrue,
      );
    },
  );

  _widgetTest('notice appearance and dismissal preserve current screen state', (
    tester,
  ) async {
    final h = await _mount(tester);
    expect(h.screenCreations, 1);
    expect(h.screenDisposals, 0);
    await tester.runAsync(() => h.track());
    await _pump(tester);
    expect(find.byKey(_notice), findsOneWidget);
    expect(h.screenCreations, 1);
    expect(h.screenDisposals, 0);
    await tester.tap(find.byTooltip('Скрыть уведомление о транскрипте'));
    await _pump(tester);
    expect(find.byKey(_notice), findsNothing);
    expect(h.screenCreations, 1);
    expect(h.screenDisposals, 0);
  });

  _widgetTest(
    'ready notice stays in other section without automatic navigation',
    (tester) async {
      final h = await _mount(tester, initial: '/workspaces');
      await tester.runAsync(() => h.track());
      await _pump(tester);
      expect(find.byKey(_notice), findsOneWidget);
      expect(
        h.router!.routerDelegate.currentConfiguration.uri.path,
        '/workspaces',
      );
      await tester.tap(find.byTooltip('Скрыть уведомление о транскрипте'));
      await _pump(tester);
      expect(find.byKey(_notice), findsNothing);
      await tester.runAsync(() => h.tracker.refresh(_key));
      await _pump(tester);
      expect(find.byKey(_notice), findsNothing);
    },
  );

  _widgetTest('current resolved latest job suppresses only its own notice', (
    tester,
  ) async {
    final h = await _mount(tester, initial: '/results/$_audio');
    await _wait(tester, () => h.adapter.requests.length >= 3);
    await _pump(tester);
    expect(find.byKey(_notice), findsNothing);
    await tester.runAsync(() => h.track(jobId: _otherJob));
    await _pump(tester);
    expect(find.byKey(_notice), findsOneWidget);
    await tester.tap(find.text(_openLabel));
    await _pump(tester);
    expect(h.router!.routerDelegate.currentConfiguration.uri.queryParameters, {
      'job_id': _otherJob,
    });
    expect(find.byKey(_notice), findsNothing);
    expect(h.notices, isEmpty);
  });

  _widgetTest('Open uses encoded audio and job route parameters', (
    tester,
  ) async {
    final h = await _mount(tester, initial: '/workspaces');
    const audio = 'audio with space';
    const job = 'job?one&two';
    await tester.runAsync(() => h.track(audioId: audio, jobId: job));
    await _pump(tester);
    await tester.tap(find.text(_openLabel));
    await _pump(tester);
    final uri = h.router!.routerDelegate.currentConfiguration.uri;
    expect(uri.pathSegments, ['results', audio]);
    expect(uri.queryParameters, {'job_id': job});
    expect(find.byKey(_notice), findsNothing);
  });

  _widgetTest('cancelled recording exit retains notice and recording', (
    tester,
  ) async {
    final h = await _mount(tester);
    final record = h.container.read(recordNotifierProvider.notifier);
    record.setAnonymous(true);
    await tester.runAsync(record.startRecording);
    await tester.runAsync(() => h.track());
    await _pump(tester);
    await tester.tap(find.text(_openLabel));
    await _pump(tester);
    expect(find.text('Отменить запись?'), findsOneWidget);
    expect(h.router!.routerDelegate.currentConfiguration.uri.path, '/record');
    await tester.tap(find.text('Остаться'));
    await _pump(tester);
    expect(find.byKey(_notice), findsOneWidget);
    expect(
      h.container.read(recordNotifierProvider).status,
      RecordStatus.recording,
    );
    expect(h.capture.disposals, 0);
    await tester.tap(find.text(_openLabel));
    await _pump(tester);
    await tester.tap(find.text('Отменить запись и выйти'));
    await _wait(
      tester,
      () => h.router!.routerDelegate.currentConfiguration.uri.path != '/record',
    );
    await _pump(tester);
    expect(h.router!.routerDelegate.currentConfiguration.uri.queryParameters, {
      'job_id': _job,
    });
    expect(h.capture.disposals, 1);
    expect(h.capture.file.existsSync(), isFalse);
    expect(find.byKey(_notice), findsNothing);
  });

  _widgetTest('account replacement removes old banner and stale action', (
    tester,
  ) async {
    final h = await _mount(tester, initial: '/workspaces');
    await tester.runAsync(() => h.track());
    await _pump(tester);
    final oldAction = tester
        .widget<TextButton>(find.widgetWithText(TextButton, _openLabel))
        .onPressed!;
    final oldController = h.controller;
    await tester.runAsync(() async {
      h.adapter.owner = _otherOwner;
      await h.container
          .read(authNotifierProvider.notifier)
          .login(
            email: 'fixture@example.invalid',
            password: 'synthetic-fixture',
            onSuccess: () {},
          );
      h.session = await h.container.read(batchSessionProvider.future);
      h.listenNotices();
    });
    await _pump(tester);
    expect(h.session.ownerId, _otherOwner);
    expect(find.byKey(_notice), findsNothing);
    expect(oldController.canOpen(_key), isFalse);
    oldAction();
    await _pump(tester);
    expect(
      h.router!.routerDelegate.currentConfiguration.uri.path,
      '/workspaces',
    );
    await tester.runAsync(() => h.track());
    await _pump(tester);
    expect(find.byKey(_notice), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 320)]) {
    _widgetTest('notice is usable at $size and text scale two', (tester) async {
      final h = await _mount(
        tester,
        initial: '/workspaces',
        size: size,
        scale: 2,
      );
      await tester.runAsync(() => h.track());
      await _pump(tester);
      expect(find.byKey(_notice), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(_openLabel));
      await _pump(tester);
      expect(
        h.router!.routerDelegate.currentConfiguration.uri.queryParameters,
        {'job_id': _job},
      );
      expect(tester.takeException(), isNull);
    });
  }
}
