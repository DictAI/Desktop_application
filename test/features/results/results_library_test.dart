import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/results/presentation/results_notifier.dart';
import 'package:dict_ai/features/results/presentation/results_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';
const _audio = '44444444-4444-4444-8444-444444444444';
const _job = '55555555-5555-4555-8555-555555555555';
const _anonymousSession = '66666666-6666-4666-8666-666666666666';
const _workspace = '77777777-7777-4777-8777-777777777777';

Map<String, Object> _row({
  String audio = _audio,
  String job = _job,
  String owner = _owner,
  String status = 'done',
}) => {
  'result_id': job,
  'audio_id': audio,
  'workspace_id': '',
  'workspace_name': '',
  'upload_user_id': owner,
  'summary_url': '',
  'transcript_url': '',
  'status': status,
  'created_at': '2026-11-03T09:00:00.123456Z',
};

Map<String, Object> _page({
  int page = 1,
  int total = 41,
  List<Map<String, Object>>? rows,
}) => {
  'data': rows ?? [_row()],
  'pagination': {
    'page': page,
    'limit': 20,
    'total': total,
    'total_pages': (total / 20).ceil(),
  },
};

Map<String, Object?> _accepted({String? sessionId}) => {
  'audio_id': _audio,
  'job_id': _job,
  'session_id': sessionId,
  'processing_version': 'fixture-version',
  'status_url': '/meetings/results/$_audio/speech-status',
};

String _jwt(String owner) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry = DateTime.now().add(const Duration(hours: 2));
  return '${segment({'alg': 'HS256'})}.'
      '${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = Uint8List(48);
  final view = ByteData.sublistView(bytes);
  void tag(int at, String value) {
    bytes.setRange(at, at + value.length, value.codeUnits);
  }

  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  view.setUint32(4, 40, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 16000, Endian.little);
  view.setUint32(28, 32000, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, 4, Endian.little);
  view.setUint32(44, 0x11223344, Endian.little);
  return bytes;
}

class _Adapter extends ScriptedAdapter {
  final uploadBodies = <Uint8List>[];
  final firstPost = Completer<void>();
  Completer<RequestOptions>? nextStatus;
  int? statusError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/speech-status')) {
      requests.add(options);
      nextStatus?.complete(options);
      nextStatus = null;
      if (statusError case final code?) {
        return ScriptedAdapter.reply(code, {'error': 'fixture'});
      }
      return ScriptedAdapter.reply(200, {
        'job_id': options.queryParameters['job_id'],
        'processing_version': 'fixture-version',
        'workspace_id': _workspace,
        'job_status': 'failed',
        'transcript_status': 'failed',
        'summary_status': 'pending',
        'summary_error': null,
      });
    }
    if (options.method == 'POST' && requestStream != null) {
      final body = BytesBuilder(copy: false);
      await for (final part in requestStream) {
        body.add(part);
      }
      uploadBodies.add(body.takeBytes());
    }
    final response = super.fetch(options, requestStream, cancelFuture);
    if (options.method == 'POST' && !firstPost.isCompleted) {
      firstPost.complete();
    }
    return response;
  }

  Iterable<RequestOptions> get pages =>
      requests.where((request) => request.path == '/meetings/results');

  Iterable<RequestOptions> get posts =>
      requests.where((request) => request.method == 'POST');
}

class _Harness {
  _Harness(this.temp, this.adapter, this.dio, this.container, this.session);

  final Directory temp;
  final _Adapter adapter;
  final Dio dio;
  final ProviderContainer container;
  final BatchSession session;
  static const storage = SecureStorage(namespace: 'results-library-fixture');

  static Future<_Harness> create() async {
    resetStorageFakes();
    final temp = await Directory.systemTemp.createTemp('dictai-results-');
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    await storage.saveToken(_jwt(_owner));
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => temp,
        ),
      ],
    );
    final session = await container.read(batchSessionProvider.future);
    return _Harness(temp, adapter, dio, container, session);
  }

  Future<void> close() async {
    container.dispose();
    dio.close(force: true);
    await temp.delete(recursive: true);
  }

  ResultsNotifier get notifier =>
      container.read(resultsNotifierProvider(session).notifier);

  ResultsState get state => container.read(resultsNotifierProvider(session));

  Future<ResultsState> until(
    bool Function(ResultsState) predicate, {
    BatchSession? forSession,
  }) async {
    final complete = Completer<ResultsState>();
    final subscription = container.listen(
      resultsNotifierProvider(forSession ?? session),
      (_, next) {
        if (predicate(next) && !complete.isCompleted) complete.complete(next);
      },
      fireImmediately: true,
    );
    try {
      return await complete.future.timeout(const Duration(seconds: 5));
    } finally {
      subscription.close();
    }
  }

  Future<ResultsState> ready() =>
      until((state) => !state.page.isLoading && !state.uploads.isLoading);

  Future<BatchSession> reopen() {
    container.invalidate(batchSessionProvider);
    return container.read(batchSessionProvider.future);
  }

  Future<PendingUpload> prepare(String key, {bool anonymous = false}) async {
    final file = File('${temp.path}/import.wav');
    await file.writeAsBytes(_wav());
    return session.uploads.prepare(
      source: file,
      options: UploadOptions(
        anonymous: anonymous,
        workspaceId: anonymous ? null : _workspace,
        idempotencyKey: key,
        source: const ImportedWavUploadSource(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refresh and retry preserve date bounds and the current page', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    h.adapter.enqueue(200, _page());
    await h.ready();
    final dates = (start: DateTime(2026, 11, 1), end: DateTime(2026, 11, 6));
    h.adapter.enqueue(200, _page());
    await h.notifier.setDates(dates);
    h.adapter.enqueue(200, _page(page: 2));
    await h.notifier.goToPage(2);
    h.adapter.enqueue(503, {'error': 'fixture'});
    await h.notifier.refresh();
    expect(h.state.page.hasError, isTrue);
    expect(h.state.pageNumber, 2);
    h.adapter.enqueue(200, _page(page: 2));
    await h.notifier.refresh();

    final queries = h.adapter.pages
        .map((request) => request.queryParameters)
        .toList();
    expect(queries.map((query) => query['page']), [1, 1, 2, 2, 2]);
    expect(
      queries.skip(1).map((query) => query['start_date']),
      everyElement(DateTime(2026, 11, 1).toUtc().toIso8601String()),
    );
    expect(
      queries.skip(1).map((query) => query['end_date']),
      everyElement(
        DateTime(
          2026,
          11,
          7,
        ).subtract(const Duration(microseconds: 1)).toUtc().toIso8601String(),
      ),
    );
    expect(h.state.dates, dates);
    expect(h.state.page.asData?.value.pagination.total, 41);

    h.adapter.enqueue(200, _page(rows: [], total: 0));
    await h.notifier.setDates(null);
    expect(h.state.dates, isNull);
    expect(h.adapter.pages.last.queryParameters, {'page': 1, 'limit': 20});
  });

  test('superseded R01 response cannot overwrite the new date query', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    final old = h.adapter.defer();
    unawaited(h.ready());
    await h.adapter.firstRequest.future;
    final first = h.adapter.pages.single;

    h.adapter.enqueue(200, _page(rows: [_row(audio: 'new')]));
    await h.notifier.setDates((
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 6),
    ));
    old.complete(ScriptedAdapter.reply(200, _page(rows: [_row(audio: 'old')])));
    await Future<void>.delayed(Duration.zero);

    expect(first.cancelToken?.isCancelled, isTrue);
    expect(h.state.page.asData?.value.data.single.audioId, 'new');
    expect(h.adapter.pages, hasLength(2));
  });

  test(
    'when a page disappears, refresh reads the last available page once',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.enqueue(200, _page());
      await h.ready();
      h.adapter.enqueue(200, _page(page: 3));
      await h.notifier.goToPage(3);

      h.adapter.enqueue(200, _page(page: 3, total: 21, rows: []));
      h.adapter.enqueue(200, _page(page: 2, total: 21));
      await h.notifier.refresh();

      expect(h.state.pageNumber, 2);
      expect(
        h.adapter.pages.map((request) => request.queryParameters['page']),
        [1, 3, 3, 2],
      );
    },
  );

  test(
    'returning to Results reloads the journal without a duplicate initial GET',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.enqueue(200, _page());
      await h.ready();
      await h.notifier.openLibrary();
      expect(h.adapter.pages, hasLength(1));

      final draft = await h.prepare('added-after-first-visit');
      h.adapter.enqueue(200, _page());
      await h.notifier.openLibrary();

      expect(h.adapter.pages, hasLength(2));
      expect(
        h.state.uploads.asData?.value.entries.single.localId,
        draft.localId,
      );
    },
  );

  test(
    'pending journal is visible while R01 is unavailable and replay is explicit',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final draft = await h.prepare('saved-idempotency-key');
      h.adapter.enqueue(503, {'error': 'fixture'});
      await h.ready();

      expect(h.state.page.hasError, isTrue);
      expect(
        h.state.uploads.asData?.value.entries.single.localId,
        draft.localId,
      );
      expect(h.adapter.posts, isEmpty);

      final response = h.adapter.defer();
      h.adapter.enqueue(200, _page(rows: [], total: 0));
      final replay = h.notifier.replay(draft.localId);
      await h.notifier.replay(draft.localId);
      response.complete(ScriptedAdapter.reply(202, _accepted()));
      await replay;

      expect(
        h.adapter.posts.single.headers['Idempotency-Key'],
        'saved-idempotency-key',
      );
      expect(
        latin1.decode(h.adapter.uploadBodies.single),
        contains(latin1.decode(_wav())),
      );
      expect(
        h.state.uploads.asData?.value.entries.single.state,
        PendingUploadState.accepted,
      );
      await h.notifier.replay(draft.localId);
      expect(h.adapter.posts, hasLength(1));
    },
  );

  test(
    'R01 exact owner/audio/job releases an accepted receipt and retains unsent and conflicted uploads',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final receipt = await h.prepare('first-accepted');
      h.adapter.enqueue(202, _accepted());
      await h.session.submit(receipt.localId);

      final conflict = await h.prepare('conflict');
      h.adapter.enqueue(409, {'error': 'fixture'});
      await expectLater(
        h.session.submit(conflict.localId),
        throwsA(
          isA<ApiFailure>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.conflict,
          ),
        ),
      );
      final pending = await h.prepare('still-pending');

      h.adapter.enqueue(
        200,
        _page(
          rows: [
            _row(job: 'different-job'),
            _row(owner: _otherOwner),
          ],
        ),
      );
      await h.ready();
      expect(h.state.page.asData?.value.data.single.resultId, 'different-job');
      expect((await h.session.uploads.list()).entries, hasLength(3));

      h.adapter.enqueue(200, _page());
      await h.notifier.refresh();
      final remaining = (await h.session.uploads.list()).entries;
      expect(
        remaining.map((entry) => entry.localId),
        unorderedEquals([pending.localId, conflict.localId]),
      );
      expect(h.state.page.asData?.value.data.single.resultId, _job);
      await h.notifier.replay(conflict.localId);
      expect(h.adapter.posts, hasLength(2));
    },
  );

  test(
    'busy replay remains available after the other submission fails',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final draft = await h.prepare('busy-replay-key');
      h.adapter.enqueue(200, _page());
      await h.ready();

      final response = h.adapter.defer();
      final original = expectLater(
        h.session.submit(draft.localId),
        throwsA(isA<ApiFailure>()),
      );
      await h.adapter.firstPost.future.timeout(const Duration(seconds: 5));
      await h.notifier.replay(draft.localId);
      expect(h.adapter.posts, hasLength(1));
      expect(h.state.actionFailed, isTrue);
      expect(h.state.blockedReplays, isEmpty);

      response.complete(ScriptedAdapter.reply(503, {'error': 'fixture'}));
      await original;
      h.adapter.enqueue(202, _accepted());
      h.adapter.enqueue(200, _page(rows: [], total: 0));
      await h.notifier.replay(draft.localId);

      expect(h.adapter.posts.map((r) => r.headers['Idempotency-Key']), [
        'busy-replay-key',
        'busy-replay-key',
      ]);
      expect(
        h.state.uploads.asData?.value.entries.single.state,
        PendingUploadState.accepted,
      );
    },
  );

  test(
    'reopened Results tracks the pending R01 job after its local receipt is pruned',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final draft = await h.prepare('restart-after-prune');
      h.adapter.enqueue(202, _accepted());
      await h.session.submit(draft.localId);
      h.adapter.enqueue(200, _page(rows: [_row(status: 'pending')]));
      await h.until(
        (state) =>
            state.page.asData != null &&
            state.uploads.asData?.value.entries.isEmpty == true,
      );
      expect((await h.session.uploads.list()).entries, isEmpty);

      final restarted = await h.reopen();
      expect(restarted, isNot(same(h.session)));
      final status = Completer<RequestOptions>();
      h.adapter.nextStatus = status;
      h.adapter.enqueue(200, _page(rows: [_row(status: 'pending')]));
      await h.until(
        (state) => !state.page.isLoading && !state.uploads.isLoading,
        forSession: restarted,
      );
      final request = await status.future.timeout(const Duration(seconds: 5));

      expect(request.path, '/meetings/results/$_audio/speech-status');
      expect(request.queryParameters, {'job_id': _job});
      expect(h.adapter.posts, hasLength(1));
    },
  );

  test(
    'reopened anonymous pending job retains its richer U03 receipt',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final draft = await h.prepare('anonymous-restart', anonymous: true);
      h.adapter.enqueue(202, _accepted(sessionId: _anonymousSession));
      await h.session.submit(draft.localId);
      final restarted = await h.reopen();
      final status = Completer<RequestOptions>();
      h.adapter.nextStatus = status;
      h.adapter.enqueue(200, _page(rows: [_row(status: 'pending')]));
      await h.until(
        (state) => !state.page.isLoading && !state.uploads.isLoading,
        forSession: restarted,
      );
      await status.future.timeout(const Duration(seconds: 5));

      final state = h.container.read(
        processingNotifierProvider(restarted.processingSession),
      );
      final job = state[(audioId: _audio, jobId: _job)]?.job;
      expect(job?.processingVersion, 'fixture-version');
      expect(job?.sessionId, _anonymousSession);
      expect(
        (await restarted.uploads.list()).entries.single.localId,
        draft.localId,
      );
      expect(h.adapter.posts, hasLength(1));
    },
  );

  test(
    'unavailable journal does not prevent tracking an exact pending R01 job',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await File('${h.temp.path}/dictai-pending-v1').writeAsString('fixture');
      final status = Completer<RequestOptions>();
      h.adapter.nextStatus = status;
      h.adapter.enqueue(200, _page(rows: [_row(status: 'pending')]));
      await h.ready();
      final request = await status.future.timeout(const Duration(seconds: 5));

      expect(h.state.uploads.hasError, isTrue);
      expect(h.state.page.asData?.value.data.single.resultId, _job);
      expect(request.queryParameters, {'job_id': _job});
      expect(h.adapter.posts, isEmpty);
    },
  );

  test(
    'missing owned WAV disables replay and leaves the receipt intact',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final draft = await h.prepare('missing-wav');
      await File(
        '${h.temp.path}/dictai-pending-v1/$_owner/${draft.localId}/source.wav',
      ).delete();
      h.adapter.enqueue(200, _page());
      await h.ready();

      await h.notifier.replay(draft.localId);
      expect(h.state.blockedReplays[draft.localId], contains('Восстановление'));
      expect(
        h.state.uploads.asData?.value.entries.single.state,
        PendingUploadState.pending,
      );
      await h.notifier.replay(draft.localId);
      expect(h.adapter.posts, isEmpty);
    },
  );

  test(
    'logging out cancels an in-flight library page and fences its response',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final old = h.adapter.defer();
      final keep = h.container.listen(
        resultsNotifierProvider(h.session),
        (_, __) {},
      );
      addTearDown(keep.close);
      await h.adapter.firstRequest.future;
      final request = h.adapter.pages.single;

      await h.container.read(authNotifierProvider.notifier).logout();
      expect(h.session.isCurrent, isFalse);
      expect(request.cancelToken?.isCancelled, isTrue);
      old.complete(ScriptedAdapter.reply(200, _page()));
      await Future<void>.delayed(Duration.zero);
      expect(h.state.page.asData, isNull);
    },
  );

  test(
    'confirmed delete fences a previously returned row without inventing an API',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      h.adapter.enqueue(200, _page());
      await h.ready();
      h.adapter.enqueue(204, '');
      h.adapter.enqueue(200, _page()); // Simulates stale R01 after the 204.
      await h.notifier.delete(_audio);

      expect(
        h.adapter.requests
            .where((request) => request.method == 'DELETE')
            .single
            .path,
        '/meetings/results/$_audio',
      );
      expect(h.state.page.asData?.value.data, isEmpty);
    },
  );

  testWidgets(
    'R01 row shows anonymous context and opens the exact job after a transient R03 error',
    (tester) async {
      final h = await tester.runAsync(_Harness.create);
      addTearDown(() async => tester.runAsync(h!.close));
      h!.adapter.statusError = 503;
      h.adapter.enqueue(
        200,
        _page(
          rows: [_row(audio: 'a', job: 'job v2', status: 'pending')],
        ),
      );
      await tester.runAsync(() async {
        final unavailable = Completer<void>();
        final subscription = h.container.listen(
          processingNotifierProvider(h.session.processingSession),
          (_, jobs) {
            if (jobs[(audioId: 'a', jobId: 'job v2')]?.error is ApiFailure &&
                !unavailable.isCompleted) {
              unavailable.complete();
            }
          },
        );
        try {
          await h.ready();
          await unavailable.future.timeout(const Duration(seconds: 5));
        } finally {
          subscription.close();
        }
      });

      final router = GoRouter(
        initialLocation: '/results',
        routes: [
          GoRoute(
            path: '/results',
            builder: (context, state) => Scaffold(
              body: ResultsScreen(
                onOpen: (audio, job) => context.go(
                  Uri(
                    pathSegments: ['', 'results', audio],
                    queryParameters: {'job_id': job},
                  ).toString(),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/results/:audioId',
            builder: (_, state) => Scaffold(
              body: Text(
                '${state.pathParameters['audioId']} / ${state.uri.queryParameters['job_id']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Запись a'), findsOneWidget);
      expect(find.textContaining('Без рабочего пространства'), findsOneWidget);
      expect(find.textContaining('Результат недоступен'), findsOneWidget);
      expect(find.text('Summary PDF'), findsNothing);
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('a / job v2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
