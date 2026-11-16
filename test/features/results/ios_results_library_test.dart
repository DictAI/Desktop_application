import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
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

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _audio = '44444444-4444-4444-8444-444444444444';
const _job = '55555555-5555-4555-8555-555555555555';

String _token() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.'
      '${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': _owner, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = Uint8List(48);
  final view = ByteData.sublistView(bytes);
  void tag(int at, String text) =>
      bytes.setRange(at, at + text.length, text.codeUnits);
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
  return bytes;
}

class _Adapter extends ScriptedAdapter {
  bool unavailable = false;
  bool empty = false;
  Completer<ResponseBody>? heldPage;

  Iterable<RequestOptions> get pages =>
      requests.where((r) => r.path == '/meetings/results');
  Iterable<RequestOptions> get posts =>
      requests.where((r) => r.method == 'POST');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/meetings/results') {
      if (heldPage case final held?) {
        heldPage = null;
        return held.future;
      }
      return page(options);
    }
    if (options.path.endsWith('/speech-status')) {
      return ScriptedAdapter.reply(200, {
        'job_id': options.queryParameters['job_id'],
        'processing_version': 'fixture-v1',
        'workspace_id': null,
        'job_status': 'failed',
        'transcript_status': 'failed',
        'summary_status': 'pending',
        'summary_error': null,
      });
    }
    if (options.method == 'POST') {
      if (requestStream != null) await requestStream.drain<void>();
      return ScriptedAdapter.reply(202, {
        'audio_id': _audio,
        'job_id': _job,
        'session_id': '66666666-6666-4666-8666-666666666666',
        'processing_version': 'fixture-v1',
        'status_url': '/meetings/results/$_audio/speech-status',
      });
    }
    throw StateError(
      'Unexpected fixture request: ${options.method} ${options.path}',
    );
  }

  ResponseBody page(RequestOptions options) {
    if (unavailable) return ScriptedAdapter.reply(503, {'error': 'fixture'});
    final number = options.queryParameters['page'] as int? ?? 1;
    Map<String, Object> row(String status) => {
      'result_id': '$status-job-$number',
      'audio_id': '$status-audio-$number',
      'workspace_id': '77777777-7777-4777-8777-777777777777',
      'workspace_name':
          'Рабочее пространство с длинным названием для встреч команды',
      'upload_user_id': _owner,
      'summary_url': '',
      'transcript_url': '',
      'status': status,
      'created_at': '2026-11-03T09:00:00.123456Z',
    };
    return ScriptedAdapter.reply(200, {
      'data': empty ? [] : [row('done'), row('failed')],
      'pagination': {
        'page': number,
        'limit': 20,
        'total': empty ? 0 : 41,
        'total_pages': empty ? 0 : 3,
      },
    });
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
  final _Adapter adapter;
  final Dio dio;
  final ProviderContainer container;
  final BatchSession session;
  static const storage = SecureStorage(namespace: 'ios-results-fixture');

  static Future<_Harness> create({bool unavailable = false}) async {
    resetStorageFakes();
    final directory = await Directory.systemTemp.createTemp(
      'dictai-ios-results-',
    );
    final adapter = _Adapter()..unavailable = unavailable;
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    await storage.saveToken(_token());
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
      ],
    );
    final session = await container.read(batchSessionProvider.future);
    return _Harness(directory, adapter, dio, container, session);
  }

  ResultsNotifier get notifier =>
      container.read(resultsNotifierProvider(session).notifier);

  Future<void> until(bool Function(ResultsState) predicate) async {
    final done = Completer<void>();
    final subscription = container.listen(resultsNotifierProvider(session), (
      _,
      next,
    ) {
      if (predicate(next) && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    try {
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      subscription.close();
    }
  }

  Future<void> ready() =>
      until((s) => !s.page.isLoading && !s.uploads.isLoading);

  Future<PendingUpload> draft() async {
    final file = File('${directory.path}/source.wav');
    await file.writeAsBytes(_wav());
    return session.uploads.prepare(
      source: file,
      options: UploadOptions(
        anonymous: true,
        workspaceId: null,
        idempotencyKey: 'ios-results-retained-key',
        source: const ImportedWavUploadSource(),
      ),
    );
  }

  Future<void> close() async {
    container.dispose();
    dio.close(force: true);
    await directory.delete(recursive: true);
  }
}

void main() {
  Future<_Harness> mount(
    WidgetTester tester, {
    double width = 320,
    double height = 700,
    double scale = 2,
    bool unavailable = false,
    bool draft = true,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    final h = (await tester.runAsync(
      () => _Harness.create(unavailable: unavailable),
    ))!;
    if (draft) await tester.runAsync(h.draft);
    await tester.runAsync(h.ready);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(h.close);
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Dict AI')),
            bottomNavigationBar: const SizedBox(height: 80),
            body: const ResultsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  for (final dimensions in [
    (320.0, 700.0),
    (375.0, 812.0),
    (430.0, 932.0),
    (844.0, 390.0),
  ]) {
    testWidgets(
      'results, pending action and pagination fit $dimensions with large text',
      (tester) async {
        final h = await mount(
          tester,
          width: dimensions.$1,
          height: dimensions.$2,
        );
        expect(h.adapter.pages, hasLength(1));
        expect(find.byType(RefreshIndicator), findsOneWidget);
        await reveal(tester, find.text('Повторить отправку'));
        expect(find.text('Повторить отправку'), findsOneWidget);
        await reveal(tester, find.byTooltip('Следующая страница'));
        expect(find.text('Страница 1 из 3'), findsOneWidget);
        expect(find.text('Открыть'), findsNothing);
        expect(find.text('Summary PDF'), findsNothing);
        expect(h.adapter.posts, isEmpty);
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Следующая страница'));
          await h.ready();
        });
        await tester.pumpAndSettle();
        expect(h.adapter.pages.last.queryParameters['page'], 2);
        expect(find.text('Страница 2 из 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'foreground refresh retains selected dates/page and never replays drafts',
    (tester) async {
      final h = await mount(tester);
      await tester.runAsync(
        () => h.notifier.setDates((
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 6),
        )),
      );
      await tester.runAsync(() => h.notifier.goToPage(2));
      await tester.pumpAndSettle();
      final before = h.adapter.pages.length;
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await h.ready();
      });
      await tester.pumpAndSettle();
      expect(h.adapter.pages.length, before + 1);
      final query = h.adapter.pages.last.queryParameters;
      expect(query['page'], 2);
      expect(
        query['start_date'],
        DateTime(2026, 11, 1).toUtc().toIso8601String(),
      );
      expect(
        query['end_date'],
        DateTime(
          2026,
          11,
          7,
        ).subtract(const Duration(microseconds: 1)).toUtc().toIso8601String(),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.adapter.pages.length, before + 1);
      expect(h.adapter.posts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.adapter.pages.length, before + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date picker cancel preserves filters and clearing dates is explicit',
    (tester) async {
      final h = await mount(tester, draft: false);
      await tester.runAsync(
        () => h.notifier.setDates((
          start: DateTime(2026, 11, 1),
          end: DateTime(2026, 11, 6),
        )),
      );
      await tester.pumpAndSettle();
      final before = h.adapter.pages.length;
      await tester.tap(find.text('01.11.2026 — 06.11.2026'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(h.adapter.pages.length, before);
      expect(find.text('01.11.2026 — 06.11.2026'), findsOneWidget);
      await reveal(tester, find.text('Сбросить период'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Сбросить период'));
        await h.ready();
      });
      await tester.pumpAndSettle();
      expect(h.adapter.pages.last.queryParameters, {'page': 1, 'limit': 20});
      expect(find.text('Выбрать период'), findsOneWidget);
      expect(find.text('Сбросить период'), findsNothing);
      expect(h.adapter.posts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a pending draft retries only after a tap using its original key',
    (tester) async {
      final h = await mount(tester);
      expect(h.adapter.posts, isEmpty);
      await reveal(tester, find.text('Повторить отправку'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Повторить отправку'));
        await h.until(
          (s) =>
              s.sending.isEmpty &&
              s.uploads.asData?.value.entries.any(
                    (e) => e.state == PendingUploadState.accepted,
                  ) ==
                  true,
        );
      });
      await tester.pumpAndSettle();
      expect(h.adapter.posts, hasLength(1));
      expect(
        h.adapter.posts.single.headers['Idempotency-Key'],
        'ios-results-retained-key',
      );
      expect(find.text('Повторить отправку'), findsNothing);
      expect(find.text('Открыть'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'page error keeps the pending draft and retry reveals the empty state',
    (tester) async {
      final h = await mount(tester, unavailable: true);
      await reveal(tester, find.text('Повторить загрузку'));
      expect(find.text('Повторить отправку'), findsOneWidget);
      h.adapter.unavailable = false;
      h.adapter.empty = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Повторить загрузку'));
        await h.ready();
      });
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Результатов пока нет.'));
      expect(find.text('Результатов пока нет.'), findsOneWidget);
      expect(h.adapter.posts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logout fences a late page and removes the previous library', (
    tester,
  ) async {
    final h = await mount(tester, draft: false, scale: 1);
    final response = Completer<ResponseBody>();
    h.adapter.heldPage = response;
    await tester.runAsync(() async {
      final refresh = h.notifier.refresh();
      await Future<void>.delayed(Duration.zero);
      await h.container.read(authNotifierProvider.notifier).logout();
      response.complete(h.adapter.page(h.adapter.pages.last));
      await refresh;
    });
    await tester.pumpAndSettle();
    expect(h.session.isCurrent, isFalse);
    expect(find.text('Запись done-audio-1'), findsNothing);
    expect(h.adapter.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
