import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/app.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/lifecycle/ios_lifecycle_observer.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/dto/upload_accepted_dto.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/results/data/dto/canonical_transcript_dto.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/features/results/presentation/result_detail_notifier.dart';
import 'package:dict_ai/features/results/presentation/result_detail_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _audio = '22222222-2222-4222-8222-222222222222';
const _job = '33333333-3333-4333-8333-333333333333';
const _otherJob = '44444444-4444-4444-8444-444444444444';
const _storage = SecureStorage(namespace: 'ios-detail-fixture');

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.'
      '${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': _owner, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

class _DetailAdapter extends ScriptedAdapter {
  String latestJob = _job;
  String transcript = 'ready';
  String summary = 'pending';
  String jobState = 'completed';
  bool noSpeech = false;
  int structuredStatus = 200;
  int statusCode = 200;
  int summaryCode = 200;
  String summaryText = 'Настоящее синтетическое краткое содержание.';
  Completer<ResponseBody>? holdStatus;
  Completer<ResponseBody>? holdSummary;

  Map<String, dynamic> status(String jobId) => {
    'job_id': jobId,
    'processing_version': 'fixture-v1',
    'workspace_id': null,
    'job_status': jobState,
    'transcript_status': transcript,
    'summary_status': summary,
    'summary_error': summary == 'failed' ? 'not_configured' : null,
  };

  Map<String, dynamic> canonical(String jobId) {
    final fixture =
        (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
                as Map)[noSpeech ? 'no_speech' : 'speech']
            as Map<String, dynamic>;
    fixture['recording_id'] = _audio;
    fixture['job_id'] = jobId;
    fixture['processing_version'] = 'fixture-v1';
    fixture['access']['owner_user_id'] = _owner;
    return fixture;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method != 'GET') {
      throw StateError('Detail must never mutate or upload');
    }
    final jobId = options.queryParameters['job_id'] as String? ?? latestJob;
    if (options.path.endsWith('/speech-status')) {
      if (holdStatus case final held?) {
        holdStatus = null;
        return held.future;
      }
      return ScriptedAdapter.reply(
        statusCode,
        statusCode == 200 ? status(jobId) : {'error': 'result unavailable'},
      );
    }
    if (options.path.endsWith('/structured')) {
      return ScriptedAdapter.reply(structuredStatus, switch (structuredStatus) {
        200 => canonical(jobId),
        202 =>
          status(jobId)
            ..['transcript_status'] =
                jobState == 'failed' || jobState == 'cancelled'
                ? jobState
                : 'pending',
        _ => {'error': 'artifact unavailable'},
      });
    }
    if (options.path.endsWith('/documents/summary.txt')) {
      if (holdSummary case final held?) {
        holdSummary = null;
        return held.future;
      }
      return ScriptedAdapter.reply(
        summaryCode,
        summaryCode == 200
            ? summaryText
            : {'error': 'document unavailable', 'summary_status': summary},
        contentType: summaryCode == 200 ? 'text/plain' : 'application/json',
      );
    }
    if (options.path == '/meetings/results') {
      return ScriptedAdapter.reply(200, {
        'data': [
          {
            'result_id': _job,
            'audio_id': _audio,
            'workspace_id': '',
            'workspace_name': '',
            'upload_user_id': _owner,
            'summary_url': '',
            'transcript_url': '',
            'status': 'done',
            'created_at': '2026-11-17T12:00:00Z',
          },
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
      });
    }
    throw StateError('Unexpected fixture GET ${options.path}');
  }
}

class _AcceptedRecordNotifier extends RecordNotifier {
  _AcceptedRecordNotifier(Future<BatchSession> Function() openSession)
    : super(
        captureFactory: (_) => throw StateError('No hardware in fixture'),
        session: openSession,
      ) {
    state = RecordState(
      status: RecordStatus.accepted,
      anonymous: true,
      accepted: UploadAcceptedDto.fromJson({
        'audio_id': _audio,
        'job_id': _job,
        'session_id': null,
        'processing_version': 'fixture-v1',
        'status_url': '/meetings/results/$_audio/speech-status',
      }),
    );
  }
}

class _Harness {
  _Harness(
    this.directory,
    this.adapter,
    this.dio,
    this.container,
    this.session,
  );
  final Directory directory;
  final _DetailAdapter adapter;
  final Dio dio;
  final ProviderContainer container;
  final BatchSession session;

  static Future<_Harness> create({
    IosLifecycleObserver? lifecycle,
    bool acceptedRecord = false,
  }) async {
    resetStorageFakes();
    final directory = await Directory.systemTemp.createTemp(
      'dictai-ios-detail-',
    );
    final adapter = _DetailAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    await _storage.saveToken(_token());
    final container = ProviderContainer(
      overrides: [
        if (acceptedRecord)
          recordNotifierProvider.overrideWith(
            (ref) => _AcceptedRecordNotifier(
              () => ref.read(batchSessionProvider.future),
            ),
          ),
        secureStorageProvider.overrideWithValue(_storage),
        dioProvider.overrideWithValue(dio),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        resultTemporaryDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        iosLifecycleObserverProvider.overrideWithValue(lifecycle),
      ],
    );
    final session = await container.read(batchSessionProvider.future);
    return _Harness(directory, adapter, dio, container, session);
  }

  ResultDetailKey request({String? jobId = _job}) =>
      (session: session, audioId: _audio, jobId: jobId);

  Future<void> until(
    ResultDetailKey key,
    bool Function(ResultDetailState state) predicate,
  ) async {
    final done = Completer<void>();
    final sub = container.listen(resultDetailNotifierProvider(key), (_, next) {
      if (predicate(next) && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    try {
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      sub.close();
    }
  }

  Future<void> close() async {
    container.dispose();
    dio.close(force: true);
    await directory.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exact job shares canonical tracker and never downloads original/uploads',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.progress?.canonical != null);
      final state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress!.canonical!.segments.first.text, 'Первая реплика.');
      expect(state.progress!.status!.summaryStatus, SummaryStatus.pending);
      expect(state.summaryAttempted, isFalse);
      expect(h.adapter.requests, hasLength(2));
      expect(
        h.adapter.requests.every((r) => r.queryParameters['job_id'] == _job),
        isTrue,
      );
      expect(
        h.adapter.requests.any((r) => r.path.endsWith('/original')),
        isFalse,
      );
      expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test(
    'missing job_id resolves latest once and pins all later reads',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final key = h.request(jobId: null);
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.progress?.canonical != null);
      h.adapter.latestJob = _otherJob;
      await h.container
          .read(resultDetailNotifierProvider(key).notifier)
          .refresh();
      expect(h.container.read(resultDetailNotifierProvider(key)).jobId, _job);
      final requests = h.adapter.requests;
      expect(requests.first.queryParameters, isEmpty);
      expect(
        requests.skip(1).every((r) => r.queryParameters['job_id'] == _job),
        isTrue,
      );
      expect(
        requests.where((r) => !r.queryParameters.containsKey('job_id')),
        hasLength(1),
      );
    },
  );

  for (final terminal in ['failed', 'cancelled']) {
    test(
      'canonical 202 $terminal stops waiting rather than reporting ready',
      () async {
        final h = await _Harness.create();
        addTearDown(h.close);
        h.adapter
          ..structuredStatus = 202
          ..jobState = terminal;
        final key = h.request();
        final sub = h.container.listen(
          resultDetailNotifierProvider(key),
          (_, __) {},
        );
        addTearDown(sub.close);
        await h.until(
          key,
          (s) =>
              s.progress?.phase ==
              (terminal == 'failed'
                  ? ProcessingPhase.failed
                  : ProcessingPhase.cancelled),
        );
        final progress = h.container
            .read(resultDetailNotifierProvider(key))
            .progress!;
        expect(progress.canonical, isNull);
        expect(progress.retryIn, isNull);
        expect(h.adapter.requests, hasLength(2));
      },
    );
  }

  test(
    'canonical 202 pending can recover without upload or another tracker',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.structuredStatus = 202;
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(
        key,
        (s) => s.progress?.status?.transcriptStatus == TranscriptStatus.pending,
      );
      h.adapter.structuredStatus = 200;
      await h.container
          .read(resultDetailNotifierProvider(key).notifier)
          .refresh();
      expect(
        h.container.read(resultDetailNotifierProvider(key)).progress!.canonical,
        isNotNull,
      );
      expect(h.adapter.requests, hasLength(4));
    },
  );

  test(
    'artifact 503 remains a read error and explicit refresh recovers',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.structuredStatus = 503;
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.progress?.error != null);
      expect(
        (h.container.read(resultDetailNotifierProvider(key)).progress!.error
                as ApiFailure)
            .kind,
        ApiFailureKind.artifactUnavailable,
      );
      h.adapter.structuredStatus = 200;
      await h.container
          .read(resultDetailNotifierProvider(key).notifier)
          .refresh();
      expect(
        h.container.read(resultDetailNotifierProvider(key)).progress!.canonical,
        isNotNull,
      );
    },
  );

  test(
    'available summary is readable while canonical artifact returns 503',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter
        ..summary = 'ready'
        ..structuredStatus = 503;
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.progress?.error != null);
      expect(
        h.container
            .read(resultDetailNotifierProvider(key))
            .progress!
            .status
            ?.summaryStatus,
        SummaryStatus.ready,
      );
      await h.until(key, (s) => s.summary.asData?.value != null);
      final state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress!.canonical, isNull);
      expect(
        (state.progress!.error as ApiFailure).kind,
        ApiFailureKind.artifactUnavailable,
      );
      expect(state.summary.asData!.value, h.adapter.summaryText);
    },
  );

  test(
    'summary 404 is independent; retry reads TXT and deletes owned download',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter
        ..summary = 'ready'
        ..summaryCode = 404;
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.summary.hasError);
      var state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress!.canonical, isNotNull);
      expect(
        (state.summary.error as ApiFailure).kind,
        ApiFailureKind.documentUnavailable,
      );
      h.adapter.summaryCode = 200;
      await h.container
          .read(resultDetailNotifierProvider(key).notifier)
          .retrySummary();
      state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.summary.asData!.value, h.adapter.summaryText);
      expect(state.progress!.canonical, isNotNull);
      expect(
        await h.directory
            .list()
            .where((p) => p.path.contains('dictai-download-'))
            .length,
        0,
      );
    },
  );

  test('summary preview is bounded and deletes oversized owned TXT', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    h.adapter
      ..summary = 'ready'
      ..summaryText = 'a' * (ResultDetailNotifier.maxSummaryPreviewBytes + 1);
    final key = h.request();
    final sub = h.container.listen(
      resultDetailNotifierProvider(key),
      (_, __) {},
    );
    addTearDown(sub.close);
    await h.until(key, (s) => s.summary.hasError);
    final state = h.container.read(resultDetailNotifierProvider(key));
    expect(state.summary.error, isA<ValidationException>());
    expect(state.progress!.canonical, isNotNull);
    expect(
      await h.directory
          .list()
          .where((p) => p.path.contains('dictai-download-'))
          .length,
      0,
    );
  });

  test(
    'reopening detail reuses completed shared job without a second poller',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.summary = 'failed';
      final key = h.request();
      var sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      await h.until(key, (s) => s.progress?.canonical != null);
      sub.close();
      await h.container.pump();
      sub = h.container.listen(resultDetailNotifierProvider(key), (_, __) {});
      addTearDown(sub.close);
      await h.until(key, (s) => s.progress?.canonical != null);
      expect(h.adapter.requests, hasLength(2));
    },
  );

  test(
    'logout fences late latest-job resolution and clears old canonical/summary',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final held = Completer<ResponseBody>();
      h.adapter.holdStatus = held;
      final key = h.request(jobId: null);
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.resolving);
      await Future<void>.delayed(Duration.zero);
      await h.container.read(authNotifierProvider.notifier).logout();
      held.complete(ScriptedAdapter.reply(200, h.adapter.status(_job)));
      await Future<void>.delayed(Duration.zero);
      final state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress, isNull);
      expect(state.summary.asData?.value, isNull);
      expect(state.error, isA<UnauthorizedException>());
      expect(
        h.adapter.requests.where((r) => r.path.endsWith('/structured')),
        isEmpty,
      );
    },
  );

  test(
    'delete during summary read clears detail and discards late document',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final held = Completer<ResponseBody>();
      h.adapter
        ..summary = 'ready'
        ..holdSummary = held;
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.summary.isLoading);
      await Future<void>.delayed(Duration.zero);
      h.container
          .read(
            processingNotifierProvider(h.session.processingSession).notifier,
          )
          .removeAudio(_audio);
      held.complete(
        ScriptedAdapter.reply(
          200,
          'late old summary',
          contentType: 'text/plain',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress, isNull);
      expect(state.error, isA<NotFoundException>());
      expect(state.summary.asData?.value, isNull);
      expect(
        await h.directory
            .list()
            .where((p) => p.path.contains('dictai-download-'))
            .length,
        0,
      );
    },
  );

  test('invalid route identity never issues requests', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    final key = (session: h.session, audioId: _audio, jobId: '');
    final sub = h.container.listen(
      resultDetailNotifierProvider(key),
      (_, __) {},
    );
    addTearDown(sub.close);
    await h.until(key, (s) => s.error is ValidationException);
    expect(h.adapter.requests, isEmpty);
  });

  test(
    'unavailable temporary directory produces a retryable summary error',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.summary = 'ready';
      var unavailable = true;
      final notifier = ResultDetailNotifier(
        key: h.request(),
        tracker: h.container.read(
          processingNotifierProvider(h.session.processingSession).notifier,
        ),
        statusApi: h.container.read(speechStatusApiProvider),
        documentsApi: h.container.read(documentsApiProvider),
        temporaryDirectory: () async {
          if (unavailable) {
            throw MissingPlatformDirectoryException('fixture unavailable');
          }
          return h.directory;
        },
      );
      addTearDown(notifier.dispose);
      final failed = Completer<void>();
      final remove = notifier.addListener((s) {
        if (s.summary.hasError && !failed.isCompleted) failed.complete();
      });
      await failed.future.timeout(const Duration(seconds: 5));
      remove();
      expect(notifier.state.progress!.canonical, isNotNull);
      expect(notifier.state.summary.error, isA<ServerException>());
      unavailable = false;
      await notifier.retrySummary();
      expect(notifier.state.summary.asData!.value, h.adapter.summaryText);
    },
  );

  test(
    'remote lost access removes previously loaded summary with canonical',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.summary = 'ready';
      final key = h.request();
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await h.until(key, (s) => s.summary.asData?.value != null);
      h.adapter.statusCode = 404;
      await h.container
          .read(resultDetailNotifierProvider(key).notifier)
          .refresh();
      final state = h.container.read(resultDetailNotifierProvider(key));
      expect(state.progress!.canonical, isNull);
      expect(state.summary.asData?.value, isNull);
      expect(
        (state.progress!.error as ApiFailure).kind,
        ApiFailureKind.notFound,
      );
    },
  );

  test(
    'latest-job resolution suspends and rejects late response before resume',
    () async {
      final lifecycle = IosLifecycleObserver();
      addTearDown(lifecycle.dispose);
      final h = await _Harness.create(lifecycle: lifecycle);
      addTearDown(h.close);
      final held = Completer<ResponseBody>();
      h.adapter.holdStatus = held;
      final key = h.request(jobId: null);
      final sub = h.container.listen(
        resultDetailNotifierProvider(key),
        (_, __) {},
      );
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      final count = h.adapter.requests.length;
      held.complete(ScriptedAdapter.reply(200, h.adapter.status(_otherJob)));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.container.read(resultDetailNotifierProvider(key)).jobId, isNull);
      expect(h.adapter.requests, hasLength(count));
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await h.until(key, (s) => s.progress?.canonical != null);
      expect(h.container.read(resultDetailNotifierProvider(key)).jobId, _job);
      expect(
        h.adapter.requests
            .where((r) => r.path.endsWith('/structured'))
            .single
            .queryParameters['job_id'],
        _job,
      );
    },
  );

  test('result URL encodes independent path/query identifiers', () {
    final uri = Uri.parse(
      resultDetailLocation('audio with space', jobId: 'job?one&two'),
    );
    expect(uri.pathSegments, ['results', 'audio with space']);
    expect(uri.queryParameters, {'job_id': 'job?one&two'});
  });

  Future<_Harness> mount(WidgetTester tester, {bool noSpeech = false}) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final h = (await tester.runAsync(_Harness.create))!;
    h.adapter
      ..noSpeech = noSpeech
      ..summary = 'failed';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: ResultDetailScreen(audioId: _audio, jobId: _job),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(h.close);
      await tester.binding.setSurfaceSize(null);
    });
    return h;
  }

  testWidgets(
    'narrow scaled detail shows actual transcript despite failed summary',
    (tester) async {
      await mount(tester);
      expect(find.text('Транскрипт готов.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Первая реплика.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Первая реплика.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no_speech is successful empty transcript UI', (tester) async {
    final h = await mount(tester, noSpeech: true);
    await tester.scrollUntilVisible(
      find.text('Речь не обнаружена.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Речь не обнаружена.'), findsOneWidget);
    expect(
      h.container
          .read(resultDetailNotifierProvider(h.request()))
          .progress!
          .canonical!
          .speechState,
      CanonicalSpeechState.noSpeech,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted Record action opens its real audio and job result', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => _Harness.create(acceptedRecord: true),
    ))!;
    h.adapter.summary = 'failed';
    await tester.binding.setSurfaceSize(const Size(375, 812));
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(h.close);
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: h.container, child: const App()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Открыть результат'));
    await tester.tap(find.text('Открыть результат'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final router = h.container.read(routerProvider);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/results/$_audio',
    );
    expect(
      router.routerDelegate.currentConfiguration.uri.queryParameters['job_id'],
      _job,
    );
    expect(find.text('Результат записи'), findsOneWidget);
    expect(h.adapter.requests.every((r) => r.method == 'GET'), isTrue);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'production route opens from library, Back returns, logout guards direct URL',
    (tester) async {
      final h = (await tester.runAsync(_Harness.create))!;
      h.adapter.summary = 'failed';
      await tester.binding.setSurfaceSize(const Size(375, 812));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        UncontrolledProviderScope(container: h.container, child: const App()),
      );
      final router = h.container.read(routerProvider);
      router.go('/results');
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Открыть'));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/results/$_audio',
      );
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['job_id'],
        _job,
      );
      expect(find.text('Результат записи'), findsOneWidget);
      expect(router.canPop(), isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/results');
      await tester.runAsync(
        () => h.container.read(authNotifierProvider.notifier).logout(),
      );
      router.go(resultDetailLocation(_audio, jobId: _job));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(h.close);
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    },
  );
}
