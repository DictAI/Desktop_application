import 'dart:async';
import 'dart:convert';

import 'package:dict_ai/app.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/data/anonymous_session_api.dart';
import 'package:dict_ai/features/record/data/microphone_capture.dart';
import 'package:dict_ai/features/record/presentation/anonymous_record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_screen.dart';
import 'package:dict_ai/features/workspace/data/dto/workspace_dto.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_detail_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _oldId = '44444444-4444-4444-8444-444444444444';
WorkspaceDto _workspace([String id = _id]) => WorkspaceDto(
  workspaceId: id,
  ownerUserId: '22222222-2222-4222-8222-222222222222',
  name: 'Empty workspace',
  createdAt: DateTime.utc(2026, 10, 24),
);
Map<String, dynamic> _detail() => _workspace().toJson();
Map<String, Object> _page() => {
  'data': [_detail()],
  'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
};

class _Record extends RecordNotifier {
  _Record()
    : super(
        captureFactory: (_) => MicrophoneCapture(isMacOS: true),
        session: () async =>
            throw StateError('Recording is outside this route fixture'),
      );
  void snapshot(RecordStatus status) => state = RecordState(
    status: status,
    uploadProgress: status == RecordStatus.uploading ? 0 : null,
    selectedWorkspaceId: _oldId,
    selectedWorkspaceName: 'Existing selection',
  );
}

class _Anon extends AnonRecordNotifier {
  _Anon(Dio dio) : super(AnonymousSessionApi(dio));
  void snapshot(AnonStatus status) => state = AnonState(status: status);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const recorder = MethodChannel('com.llfbandit.record/messages');
  final events = <MethodChannel>[];
  setUp(() {
    resetStorageFakes();
    messenger.setMockMethodCallHandler(recorder, (call) async {
      if (call.method == 'create') {
        final event = MethodChannel(
          'com.llfbandit.record/events/${call.arguments['recorderId']}',
        );
        events.add(event);
        messenger.setMockMethodCallHandler(event, (_) async => null);
        return null;
      }
      if (call.method == 'hasPermission') return false;
      if (call.method == 'listInputDevices') return [];
      if (call.method == 'dispose') return null;
      fail('Unexpected native call ${call.method}');
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(recorder, null);
    for (final event in events) {
      messenger.setMockMethodCallHandler(event, null);
    }
    events.clear();
  });

  Future<(ProviderContainer, GoRouter)> mount(
    WidgetTester tester,
    ScriptedAdapter adapter, {
    RecordStatus? ordinary,
    AnonStatus? anonymous,
    String? directId,
    WorkspaceDto? extra,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final record = _Record();
    final anon = _Anon(dio);
    if (ordinary != null) record.snapshot(ordinary);
    if (anonymous != null) anon.snapshot(anonymous);
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        recordNotifierProvider.overrideWith((_) => record),
        anonRecordNotifierProvider.overrideWith((_) => anon),
      ],
    );
    container.read(recordNotifierProvider);
    container.read(anonRecordNotifierProvider);
    final router = GoRouter(
      initialLocation: directId == null
          ? '/workspaces/$_id'
          : '/record?workspaceId=${Uri.encodeComponent(directId)}',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/workspaces/:workspaceId',
              builder: (_, state) => WorkspaceDetailScreen(
                workspaceId: state.pathParameters['workspaceId']!,
              ),
            ),
            GoRoute(
              path: '/record',
              builder: (_, state) => RecordScreen(
                workspaceId: state.uri.queryParameters['workspaceId'],
                workspace: state.extra is WorkspaceDto
                    ? state.extra as WorkspaceDto
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      dio.close(force: true);
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (extra != null) {
      router.go('/record?workspaceId=$directId', extra: extra);
      await tester.pumpAndSettle();
    }
    return (container, router);
  }

  testWidgets(
    'detail New recording selects a workspace with no contacts and no profiles',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _detail())
        ..enqueue(200, [])
        ..enqueue(200, _page());
      final (container, router) = await mount(tester, adapter);
      await tester.tap(find.text('Новая запись'));
      await tester.pumpAndSettle();
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['workspaceId'],
        _id,
      );
      expect(container.read(recordNotifierProvider).selectedWorkspaceId, _id);
      expect(
        container.read(recordNotifierProvider).selectedWorkspaceName,
        'Empty workspace',
      );
      expect(adapter.requests.map((r) => r.path), [
        '/workspaces/$_id',
        '/workspaces/$_id/participants',
        '/workspaces/',
      ]);
      expect(find.byType(RecordScreen), findsOneWidget);
    },
  );

  for (final status in [
    RecordStatus.recording,
    RecordStatus.paused,
    RecordStatus.uploading,
  ]) {
    testWidgets(
      'New recording cannot overwrite an ordinary $status operation',
      (tester) async {
        final adapter = ScriptedAdapter()
          ..enqueue(200, _detail())
          ..enqueue(200, []);
        final (container, router) = await mount(
          tester,
          adapter,
          ordinary: status,
        );
        await tester.tap(find.text('Новая запись'));
        await tester.pump();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/workspaces/$_id',
        );
        expect(
          container.read(recordNotifierProvider).selectedWorkspaceId,
          _oldId,
        );
        expect(container.read(recordNotifierProvider).status, status);
        expect(
          find.textContaining('Сначала завершите активную запись'),
          findsOneWidget,
        );
      },
    );
  }

  for (final status in [
    AnonStatus.recording,
    AnonStatus.uploading,
    AnonStatus.confirming,
  ]) {
    testWidgets(
      'New recording cannot overwrite an anonymous $status operation',
      (tester) async {
        final adapter = ScriptedAdapter()
          ..enqueue(200, _detail())
          ..enqueue(200, []);
        final (container, router) = await mount(
          tester,
          adapter,
          anonymous: status,
        );
        await tester.tap(find.text('Новая запись'));
        await tester.pump();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/workspaces/$_id',
        );
        expect(container.read(anonRecordNotifierProvider).status, status);
      },
    );
  }

  for (final id in ['bad-id', _id]) {
    testWidgets(
      'unconfirmed direct context $id preserves selection and explains recovery',
      (tester) async {
        final adapter = ScriptedAdapter()..enqueue(200, _page());
        final (container, _) = await mount(
          tester,
          adapter,
          ordinary: RecordStatus.idle,
          directId: id,
        );
        expect(
          container.read(recordNotifierProvider).selectedWorkspaceId,
          _oldId,
        );
        expect(
          find.textContaining('Контекст рабочего пространства не подтверждён'),
          findsOneWidget,
        );
        expect(adapter.requests.map((r) => r.path), ['/workspaces/']);
      },
    );
  }

  testWidgets(
    'Record rechecks active operation when typed workspace reaches destination',
    (tester) async {
      final adapter = ScriptedAdapter()..enqueue(200, _page());
      final (container, _) = await mount(
        tester,
        adapter,
        ordinary: RecordStatus.uploading,
        directId: _id,
        extra: _workspace(),
      );
      expect(
        container.read(recordNotifierProvider).selectedWorkspaceId,
        _oldId,
      );
      expect(
        container.read(recordNotifierProvider).status,
        RecordStatus.uploading,
      );
      expect(
        find.textContaining('Сначала завершите активную запись'),
        findsOneWidget,
      );
    },
  );

  testWidgets('pending anonymous start cannot accept a new workspace', (
    tester,
  ) async {
    final adapter = ScriptedAdapter()
      ..enqueue(200, _detail())
      ..enqueue(200, []);
    final (container, router) = await mount(tester, adapter);
    final pending = Completer<void>();
    final start = container
        .read(recordNotifierProvider.notifier)
        .runStartOperation(() => pending.future);
    await tester.tap(find.text('Новая запись'));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/workspaces/$_id');
    pending.complete();
    await start;
  });

  testWidgets(
    'Record uses the same workspace create form with error and retry',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _page())
        ..enqueue(503, {'error': 'unavailable'})
        ..enqueue(200, _detail());
      final (container, _) = await mount(tester, adapter, directId: 'bad-id');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Created');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Сервис временно недоступен.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(recordNotifierProvider).selectedWorkspaceId, _id);
      expect(container.read(recordNotifierProvider).errorMessage, isNull);
      expect(adapter.requests.map((r) => r.method), ['GET', 'POST', 'POST']);
    },
  );

  testWidgets('actual authenticated router passes detail workspace to Record', (
    tester,
  ) async {
    String segment(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${segment({'alg': 'HS256'})}.${segment({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': '22222222-2222-4222-8222-222222222222', 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.fixture';
    const storage = SecureStorage();
    await storage.saveToken(token);
    final adapter = ScriptedAdapter()
      ..enqueue(200, _page())
      ..enqueue(200, _detail())
      ..enqueue(200, []);
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        secureStorageProvider.overrideWithValue(storage),
        recordCaptureFactoryProvider.overrideWithValue(
          (_) => MicrophoneCapture(isMacOS: true),
        ),
      ],
    );
    final router = container.read(routerProvider);
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      dio.close(force: true);
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    router.go('/workspaces/$_id');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новая запись'));
    await tester.pumpAndSettle();
    expect(container.read(recordNotifierProvider).selectedWorkspaceId, _id);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['workspaceId'],
      _id,
    );
    expect(tester.takeException(), isNull);
    await container.read(authNotifierProvider.notifier).logout();
    await tester.pumpAndSettle();
  });
}
