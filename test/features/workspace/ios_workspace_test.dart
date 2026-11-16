import 'dart:convert';

import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/auth/data/auth_api.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/workspace/data/dto/workspace_dto.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_detail_screen.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_notifier.dart';
import 'package:dict_ai/features/workspace/presentation/workspaces_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _contactId = '33333333-3333-4333-8333-333333333333';
Map<String, Object> _workspace([String name = 'Mobile workspace']) => {
  'workspace_id': _id,
  'owner_id': '22222222-2222-4222-8222-222222222222',
  'name': name,
  'created_at': '2026-11-16T09:00:00Z',
};
Map<String, Object> _page(List<Object> items) => {
  'data': items,
  'pagination': {
    'page': 1,
    'limit': 20,
    'total': items.length,
    'total_pages': items.isEmpty ? 0 : 1,
  },
};
Map<String, Object> _contact(String name, String email) => {
  'participant_id': _contactId,
  'workspace_id': _id,
  'name': name,
  'email': email,
};

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': '44444444-4444-4444-8444-444444444444', 'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

void main() {
  setUp(resetStorageFakes);

  Future<(ProviderContainer, GoRouter)> mount(
    WidgetTester tester,
    ScriptedAdapter adapter, {
    Size size = const Size(375, 812),
    bool detail = false,
    double scale = 1,
    double keyboard = 0,
    bool settle = true,
  }) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final auth = AuthNotifier(AuthApi(dio), const SecureStorage());
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authNotifierProvider.overrideWith((_) => auth),
      ],
    );
    final router = GoRouter(
      initialLocation: detail ? '/workspaces/$_id' : '/workspaces',
      routes: [
        ShellRoute(
          builder: (_, __, child) => Scaffold(body: SafeArea(child: child)),
          routes: [
            GoRoute(
              path: '/workspaces',
              builder: (_, __) => const WorkspacesScreen(),
            ),
            GoRoute(
              path: '/workspaces/:id',
              builder: (_, state) => WorkspaceDetailScreen(
                workspaceId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/record',
              builder: (_, state) =>
                  Text('Recording ${state.uri.queryParameters['workspaceId']}'),
            ),
          ],
        ),
      ],
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      dio.close(force: true);
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (container, router);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets(
      'workspace list and keyboard create dialog fit $width with large text',
      (tester) async {
        final adapter = ScriptedAdapter()
          ..enqueue(
            200,
            _page([_workspace('A long workspace name for a small iPhone')]),
          )
          ..enqueue(200, _workspace('Created on phone'));
        final (container, _) = await mount(
          tester,
          adapter,
          size: Size(width, 740),
          scale: 2,
          keyboard: 220,
        );
        await tapVisible(tester, find.text('New Workspace'));
        final input = find.widgetWithText(TextFormField, 'Workspace name');
        await tester.ensureVisible(input);
        await tester.enterText(input, 'Created on phone');
        await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Create'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          container.read(workspacesNotifierProvider).workspaces.first.name,
          'Created on phone',
        );
        expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail contacts can be added, edited and removed on narrow landscape',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace('Workspace with a longer name'))
        ..enqueue(200, [])
        ..enqueue(
          200,
          _contact('A long contact name', 'long-contact@example.invalid'),
        )
        ..enqueue(200, _contact('Updated contact', 'updated@example.invalid'))
        ..enqueue(200, {'message': 'removed'});
      final (container, _) = await mount(
        tester,
        adapter,
        detail: true,
        size: const Size(640, 375),
        scale: 1.5,
        keyboard: 100,
      );
      await tapVisible(tester, find.text('Add'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'A long contact name',
      );
      await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Email address'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'long-contact@example.invalid',
      );
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Add'));
      await tapVisible(tester, find.byTooltip('Edit contact'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Updated contact',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'updated@example.invalid',
      );
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Save'));
      expect(
        container.read(workspaceDetailProvider(_id)).participants.single.email,
        'updated@example.invalid',
      );
      await tapVisible(tester, find.byTooltip('Remove contact'));
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Remove'));
      expect(
        container.read(workspaceDetailProvider(_id)).participants,
        isEmpty,
      );
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'GET',
        'POST',
        'PUT',
        'DELETE',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'contact actions and form remain reachable on a 320px iPhone with text scale two',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace('A long mobile workspace name'))
        ..enqueue(200, [
          _contact(
            'A contact with a long name',
            'long-contact-address@example.invalid',
          ),
        ]);
      await mount(
        tester,
        adapter,
        detail: true,
        size: const Size(320, 568),
        scale: 2,
        keyboard: 160,
      );
      await tapVisible(tester, find.byTooltip('Edit contact'));
      expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Email address'),
        findsOneWidget,
      );
      await tapVisible(tester, find.widgetWithText(TextButton, 'Cancel'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(adapter.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small iPhone shows error retry and empty state with large text',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(503, {'error': 'unavailable'})
        ..enqueue(200, _page([]));
      await mount(tester, adapter, size: const Size(320, 568), scale: 2);
      expect(find.text('Сервис временно недоступен.'), findsOneWidget);
      await tapVisible(tester, find.text('Retry'));
      expect(find.text('No workspaces yet'), findsOneWidget);
      expect(adapter.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile workspace rename and new recording preserve typed workspace context',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(200, _workspace('Renamed on phone'));
      final (container, router) = await mount(
        tester,
        adapter,
        detail: true,
        size: const Size(320, 740),
        scale: 2,
      );
      await tapVisible(tester, find.text('Rename'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Workspace name'),
        'Renamed on phone',
      );
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Save'));
      expect(
        container.read(workspaceDetailProvider(_id)).workspace!.name,
        'Renamed on phone',
      );
      await tapVisible(tester, find.text('Новая запись'));
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['workspaceId'],
        _id,
      );
      final selected =
          router.routerDelegate.currentConfiguration.extra as WorkspaceDto;
      expect(selected.workspaceId, _id);
      expect(selected.name, 'Renamed on phone');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout drops a late workspace response and next login loads only the new session',
    (tester) async {
      final adapter = ScriptedAdapter();
      final pending = adapter.defer();
      final (container, _) = await mount(tester, adapter, settle: false);
      final original = container.read(workspacesNotifierProvider.notifier);
      await container.read(authNotifierProvider.notifier).logout();
      pending.complete(
        ScriptedAdapter.reply(
          200,
          _page([_workspace('Previous account data')]),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(workspacesNotifierProvider).workspaces, isEmpty);
      await original.load();
      expect(adapter.requests, hasLength(1));
      adapter.enqueue(200, {'token': _token()});
      adapter.enqueue(200, _page([_workspace('New account data')]));
      await tester.runAsync(
        () => container
            .read(authNotifierProvider.notifier)
            .login(
              email: 'new@example.invalid',
              password: 'fixture',
              onSuccess: () {},
            ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(workspacesNotifierProvider.notifier),
        isNot(same(original)),
      );
      expect(
        container.read(workspacesNotifierProvider).workspaces.single.name,
        'New account data',
      );
      expect(find.text('Previous account data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'external unauthorized event clears workspace state and drops a pending response',
    (tester) async {
      final adapter = ScriptedAdapter();
      final pending = adapter.defer();
      final (container, _) = await mount(tester, adapter, settle: false);
      container.read(sessionNotifierProvider).invalidate();
      pending.complete(
        ScriptedAdapter.reply(200, _page([_workspace('Old session data')])),
      );
      await tester.pumpAndSettle();
      expect(container.read(workspacesNotifierProvider).workspaces, isEmpty);
      expect(find.text('Old session data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout before detail arrives prevents fetching old contacts with a new session',
    (tester) async {
      final adapter = ScriptedAdapter();
      final pending = adapter.defer();
      final (container, _) = await mount(
        tester,
        adapter,
        detail: true,
        settle: false,
      );
      await container.read(authNotifierProvider.notifier).logout();
      pending.complete(
        ScriptedAdapter.reply(200, _workspace('Previous account data')),
      );
      await tester.pumpAndSettle();
      final state = container.read(workspaceDetailProvider(_id));
      expect(state.workspace, isNull);
      expect(state.participants, isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout dismisses a contact dialog and ignores its pending mutation response',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, []);
      final pending = adapter.defer();
      final (container, _) = await mount(tester, adapter, detail: true);
      await tapVisible(tester, find.text('Add'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Private contact',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'private@example.invalid',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();
      await container.read(authNotifierProvider.notifier).logout();
      await tester.pump();
      pending.complete(
        ScriptedAdapter.reply(
          200,
          _contact('Private contact', 'private@example.invalid'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Private contact'), findsNothing);
      expect(
        container.read(workspaceDetailProvider(_id)).participants,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
