import 'dart:async';

import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_detail_screen.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_notifier.dart';
import 'package:dict_ai/features/workspace/presentation/workspaces_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _id = '11111111-1111-4111-8111-111111111111';
Map<String, Object> _workspace(String name, {String id = _id}) => {
  'workspace_id': id,
  'owner_id': '22222222-2222-4222-8222-222222222222',
  'name': name,
  'created_at': '2026-10-24T09:00:00Z',
};
Map<String, Object> _page(List<Object> workspaces) => {
  'data': workspaces,
  'pagination': {
    'page': 1,
    'limit': 20,
    'total': workspaces.length,
    'total_pages': workspaces.isEmpty ? 0 : 1,
  },
};

Future<ProviderContainer> _mount(
  WidgetTester tester,
  ScriptedAdapter adapter, {
  bool detail = false,
}) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  final router = GoRouter(
    initialLocation: detail ? '/workspaces/$_id' : '/workspaces',
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/workspaces',
            builder: (_, __) => const WorkspacesScreen(),
          ),
          GoRoute(
            path: '/workspaces/:workspaceId',
            builder: (_, state) => WorkspaceDetailScreen(
              workspaceId: state.pathParameters['workspaceId']!,
            ),
          ),
        ],
      ),
    ],
  );
  await tester.binding.setSurfaceSize(const Size(1280, 900));
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
  return container;
}

Future<void> _menu(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Workspace actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'create validates and retains input after an API failure for real retry',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _page([]))
        ..enqueue(503, {'error': 'unavailable'})
        ..enqueue(200, _workspace('Q'));
      await _mount(tester, adapter);
      await tester.tap(find.text('New Workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(
        find.text('Введите название рабочего пространства.'),
        findsOneWidget,
      );
      expect(adapter.requests, hasLength(1));
      await tester.enterText(find.byType(TextFormField), ' Q ');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Сервис временно недоступен.'), findsNWidgets(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        ' Q ',
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Q'), findsOneWidget);
      expect(adapter.requests.map((r) => r.method), ['GET', 'POST', 'POST']);
      expect(adapter.requests.last.data, {'name': 'Q'});
    },
  );

  testWidgets(
    'create is single-flight and blocks close until response arrives',
    (tester) async {
      final adapter = ScriptedAdapter()..enqueue(200, _page([]));
      final deferred = adapter.defer();
      await _mount(tester, adapter);
      await tester.tap(find.text('New Workspace'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Meeting');
      await tester.tap(find.text('Create'));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Create'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      for (var i = 0; i < 20 && adapter.requests.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(adapter.requests, hasLength(2));
      deferred.complete(ScriptedAdapter.reply(200, _workspace('Meeting')));
      await tester.pumpAndSettle();
      expect(find.text('Meeting'), findsOneWidget);
    },
  );

  testWidgets(
    'rename uses the canonical server name and keeps the workspace grid',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _page([_workspace('Before')]))
        ..enqueue(403, {'error': 'only workspace owner can update workspace'})
        ..enqueue(200, _workspace('Server title'));
      final container = await _mount(tester, adapter);
      await _menu(tester, 'Rename');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Before',
      );
      await tester.enterText(find.byType(TextFormField), 'Requested title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Недостаточно прав для этого действия.'),
        findsNWidgets(2),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Server title'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
      expect(
        container.read(workspacesNotifierProvider).workspaces.single.name,
        'Server title',
      );
      expect(adapter.requests.last.path, '/workspaces/$_id');
      expect(adapter.requests.last.data, {'name': 'Requested title'});
    },
  );

  testWidgets(
    'delete requires confirmation and describes only workspace/contacts',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _page([_workspace('Meeting')]))
        ..enqueue(200, {'message': 'workspace deleted successfully'});
      await _mount(tester, adapter);
      await _menu(tester, 'Delete');
      expect(
        find.textContaining(
          'does not promise deletion of recordings or results',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      await _menu(tester, 'Delete');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No workspaces yet'), findsOneWidget);
      expect(find.byType(WorkspaceDetailScreen), findsNothing);
      expect(adapter.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'GET /workspaces/',
        'DELETE /workspaces/$_id',
      ]);
    },
  );

  testWidgets(
    'delete failure retains workspace and confirmation supports retry',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _page([_workspace('Meeting')]))
        ..enqueue(503, {'error': 'unavailable'})
        ..enqueue(200, {'message': 'workspace deleted successfully'});
      await _mount(tester, adapter);
      await _menu(tester, 'Delete');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Meeting'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No workspaces yet'), findsOneWidget);
    },
  );

  testWidgets(
    'detail rename updates loaded list and current Record selection without extra fetch',
    (tester) async {
      const recorder = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final events = <MethodChannel>[];
      messenger.setMockMethodCallHandler(recorder, (call) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'com.llfbandit.record/events/${call.arguments['recorderId']}',
          );
          events.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          return null;
        }
        if (call.method == 'hasPermission') return false;
        if (call.method == 'dispose') return null;
        fail('Unexpected recorder method ${call.method}');
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(recorder, null);
        for (final event in events) {
          messenger.setMockMethodCallHandler(event, null);
        }
      });
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace('Before'))
        ..enqueue(200, [])
        ..enqueue(200, _page([_workspace('Before')]))
        ..enqueue(200, _workspace('Canonical'));
      final container = await _mount(tester, adapter, detail: true);
      container.read(workspacesNotifierProvider);
      final record = container.read(recordNotifierProvider.notifier);
      record.selectWorkspace(_id, 'Before');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Request');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Canonical'), findsOneWidget);
      expect(
        container.read(workspacesNotifierProvider).workspaces.single.name,
        'Canonical',
      );
      expect(
        container.read(recordNotifierProvider).selectedWorkspaceName,
        'Canonical',
      );
      expect(adapter.requests, hasLength(4));
    },
  );

  testWidgets('list load error retries without claiming missing backend API', (
    tester,
  ) async {
    final adapter = ScriptedAdapter()
      ..enqueue(503, {'error': 'unavailable'})
      ..enqueue(200, _page([_workspace('Recovered')]));
    await _mount(tester, adapter);
    expect(find.text('Сервис временно недоступен.'), findsOneWidget);
    expect(find.textContaining('not implemented'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });

  for (final create in [false, true]) {
    test(
      'late initial list preserves other workspaces after ${create ? 'create' : 'rename'}',
      () async {
        const otherId = '55555555-5555-4555-8555-555555555555';
        const createdId = '66666666-6666-4666-8666-666666666666';
        final adapter = ScriptedAdapter();
        final load = adapter.defer();
        adapter.enqueue(
          200,
          _workspace('Updated', id: create ? createdId : _id),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
          ..httpClientAdapter = adapter;
        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(dio)],
        );
        addTearDown(() {
          container.dispose();
          dio.close(force: true);
        });
        final notifier = container.read(workspacesNotifierProvider.notifier);
        await adapter.firstRequest.future;
        if (create) {
          await notifier.create('Updated');
        } else {
          await notifier.rename(_id, 'Updated');
        }
        final loaded = Completer<WorkspacesState>();
        final subscription = container.listen(workspacesNotifierProvider, (
          _,
          state,
        ) {
          if (state.status == WorkspacesStatus.loaded && !loaded.isCompleted) {
            loaded.complete(state);
          }
        });
        addTearDown(subscription.close);
        load.complete(
          ScriptedAdapter.reply(
            200,
            _page([_workspace('Old'), _workspace('Other', id: otherId)]),
          ),
        );
        final state = await loaded.future;
        expect(
          state.workspaces.map((ws) => ws.name),
          create ? ['Updated', 'Old', 'Other'] : ['Updated', 'Other'],
        );
        expect(
          state.workspaces.map((ws) => ws.workspaceId).toSet(),
          create ? {createdId, _id, otherId} : {_id, otherId},
        );
        expect(adapter.requests.map((r) => r.method), [
          'GET',
          create ? 'POST' : 'PUT',
        ]);
      },
    );
  }

  test(
    'late initial list cannot restore a deleted workspace or lose unrelated entries',
    () async {
      const otherId = '55555555-5555-4555-8555-555555555555';
      final adapter = ScriptedAdapter();
      final load = adapter.defer();
      adapter.enqueue(200, {'message': 'workspace deleted successfully'});
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(() {
        container.dispose();
        dio.close(force: true);
      });
      final notifier = container.read(workspacesNotifierProvider.notifier);
      await adapter.firstRequest.future;
      expect(await notifier.delete(_id), isTrue);
      final loaded = Completer<WorkspacesState>();
      final subscription = container.listen(workspacesNotifierProvider, (
        _,
        state,
      ) {
        if (state.status == WorkspacesStatus.loaded && !loaded.isCompleted) {
          loaded.complete(state);
        }
      });
      addTearDown(subscription.close);
      load.complete(
        ScriptedAdapter.reply(
          200,
          _page([_workspace('Deleted'), _workspace('Other', id: otherId)]),
        ),
      );
      expect((await loaded.future).workspaces.map((ws) => ws.workspaceId), [
        otherId,
      ]);
    },
  );

  test(
    'list rename during detail reload completes loading with canonical name and contacts',
    () async {
      final contact = {
        'participant_id': '77777777-7777-4777-8777-777777777777',
        'workspace_id': _id,
        'name': 'Contact',
        'email': 'contact@example.invalid',
      };
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace('Before'))
        ..enqueue(200, [])
        ..enqueue(200, _page([_workspace('Before')]));
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(() {
        container.dispose();
        dio.close(force: true);
      });
      final initialDetail = Completer<void>();
      final detailSubscription = container.listen(
        workspaceDetailProvider(_id),
        (_, state) {
          if (state.status == DetailStatus.loaded &&
              !initialDetail.isCompleted) {
            initialDetail.complete();
          }
        },
      );
      addTearDown(detailSubscription.close);
      await initialDetail.future;
      final initialList = Completer<void>();
      final listSubscription = container.listen(workspacesNotifierProvider, (
        _,
        state,
      ) {
        if (state.status == WorkspacesStatus.loaded &&
            !initialList.isCompleted) {
          initialList.complete();
        }
      });
      addTearDown(listSubscription.close);
      await initialList.future;
      final response = adapter.defer();
      adapter.enqueue(200, _workspace('Canonical'));
      adapter.enqueue(200, [contact]);
      final reloading = container
          .read(workspaceDetailProvider(_id).notifier)
          .load();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests.last.method, 'GET');
      expect(
        await container
            .read(workspacesNotifierProvider.notifier)
            .rename(_id, 'Requested'),
        isNotNull,
      );
      expect(
        container.read(workspaceDetailProvider(_id)).status,
        DetailStatus.loading,
      );
      response.complete(ScriptedAdapter.reply(200, _workspace('Old snapshot')));
      await reloading;
      final detail = container.read(workspaceDetailProvider(_id));
      expect(detail.status, DetailStatus.loaded);
      expect(detail.workspace!.name, 'Canonical');
      expect(detail.participants.single.name, 'Contact');
      expect(
        container.read(workspacesNotifierProvider).workspaces.single.name,
        'Canonical',
      );
    },
  );
}
