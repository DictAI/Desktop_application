import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/app.dart';
import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/shell/main_shell.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/results/presentation/results_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

const _content = Key('route-content');
const _workspaceId = '22222222-2222-4222-8222-222222222222';
const _ownerId = '11111111-1111-4111-8111-111111111111';

class _NavigationAdapter extends ScriptedAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final workspace = {
      'workspace_id': _workspaceId,
      'owner_user_id': _ownerId,
      'name': 'Mobile workspace',
      'created_at': '2026-11-16T12:00:00Z',
    };
    if (options.method != 'GET') {
      throw StateError('Unexpected mutation in navigation test');
    }
    return ScriptedAdapter.reply(200, switch (options.path) {
      '/workspaces/' => {
        'data': [workspace],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
      },
      '/workspaces/$_workspaceId' => workspace,
      '/workspaces/$_workspaceId/participants' => [],
      '/meetings/results' => {
        'data': [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      },
      _ => throw StateError('Unexpected path ${options.path}'),
    });
  }
}

void main() {
  setUp(resetStorageFakes);

  Future<GoRouter> mount(
    WidgetTester tester, {
    double width = 375,
    double height = 812,
    TargetPlatform platform = TargetPlatform.iOS,
    String location = '/record',
    double textScale = 1,
    double keyboard = 0,
    bool Function()? canLeaveRecord,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const Center(child: Text('Signed out')),
        ),
        ShellRoute(
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/record',
              onExit: (_) => canLeaveRecord?.call() ?? true,
              builder: (_, __) => const SizedBox.expand(key: _content),
            ),
            GoRoute(
              path: '/workspaces',
              builder: (_, __) => const SizedBox.expand(key: _content),
              routes: [
                GoRoute(
                  path: ':workspaceId',
                  builder: (_, state) => Center(
                    key: _content,
                    child: Text(state.pathParameters['workspaceId']!),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/results',
              builder: (_, __) => const SizedBox.expand(key: _content),
            ),
          ],
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark.copyWith(platform: platform),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.fromLTRB(0, 47, 0, keyboard > 0 ? 0 : 34),
              viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
              viewInsets: EdgeInsets.only(bottom: keyboard),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> select(WidgetTester tester, int index) async {
    await tester.tap(find.byType(NavigationDestination).at(index));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('iOS bottom tabs fit width $width and safe areas', (
      tester,
    ) async {
      final router = await mount(tester, width: width);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.byTooltip('Log out'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
      expect(selected(tester), 0);
      final content = tester.getRect(find.byKey(_content));
      final bar = tester.getRect(find.byType(NavigationBar));
      expect(content.left, 0);
      expect(content.width, width);
      expect(content.top, greaterThanOrEqualTo(47 + kToolbarHeight));
      expect(content.bottom, lessThanOrEqualTo(bar.top));
      expect(bar.bottom, 812);
      final destination = tester.getRect(find.byIcon(Icons.mic_rounded));
      expect(destination.bottom, lessThanOrEqualTo(812 - 34));

      for (final (index, path) in [
        (1, '/workspaces'),
        (2, '/results'),
        (0, '/record'),
      ]) {
        await select(tester, index);
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(selected(tester), index);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'iOS keeps bottom tabs in landscape with keyboard and large text',
    (tester) async {
      await mount(tester, width: 932, height: 430, textScale: 2, keyboard: 160);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Log out'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(_content)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );
      await select(tester, 2);
      expect(selected(tester), 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reselecting tabs preserves workspace path, query and extra', (
    tester,
  ) async {
    final router = await mount(tester, location: '/record?workspaceId=fixture');
    final extra = Object();
    router.go('/record?workspaceId=fixture', extra: extra);
    await tester.pumpAndSettle();
    await select(tester, 0);
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'workspaceId': 'fixture',
    });
    expect(router.routerDelegate.currentConfiguration.extra, same(extra));

    router.go('/workspaces/fixture');
    await tester.pumpAndSettle();
    expect(selected(tester), 1);
    await select(tester, 1);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workspaces/fixture',
    );
    expect(find.text('fixture'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/workspaces');
    expect(selected(tester), 1);
    expect(find.byType(BackButton), findsNothing);
    router.go('/workspaces/fixture');
    await tester.pumpAndSettle();
    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/workspaces');
    expect(selected(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejected route exit keeps Record selected until guard allows it',
    (tester) async {
      var allow = false;
      var exits = 0;
      final router = await mount(
        tester,
        canLeaveRecord: () {
          exits++;
          return allow;
        },
      );
      await select(tester, 2);
      expect(exits, 1);
      expect(router.routeInformationProvider.value.uri.path, '/record');
      expect(selected(tester), 0);
      allow = true;
      await select(tester, 2);
      expect(exits, 2);
      expect(router.routeInformationProvider.value.uri.path, '/results');
      expect(selected(tester), 2);
    },
  );

  testWidgets('mobile logout clears credentials and leaves the shell', (
    tester,
  ) async {
    const storage = SecureStorage();
    await storage.saveEmail('fixture@example.invalid');
    await storage.saveToken('fixture-token');
    final router = await mount(tester);
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(await storage.getToken(), isNull);
    expect(await storage.getEmail(), isNull);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide desktop keeps sidebar; narrow window uses bottom tabs', (
    tester,
  ) async {
    await mount(tester, width: 1280, platform: TargetPlatform.macOS);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Log out'), findsOneWidget);
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(selected(tester), 2);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('actual mobile app crosses feature routes at width $width', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.binding.setSurfaceSize(Size(width, 812));
      const storage = SecureStorage();
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('dictai-ios-navigation-'),
      );
      String encode(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      await storage.saveToken(
        '${encode({'alg': 'HS256'})}.${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': _ownerId, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture',
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
          ),
          batchApplicationSupportDirectoryProvider.overrideWithValue(
            () async => directory!,
          ),
        ],
      );
      final adapter = _NavigationAdapter();
      final dio = container.read(dioProvider)..httpClientAdapter = adapter;
      final router = container.read(routerProvider)..go('/workspaces');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        dio.close(force: true);
        await tester.runAsync(() => directory!.delete(recursive: true));
        debugDefaultTargetPlatformOverride = null;
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      expect(selected(tester), 1);
      await tester.tap(find.text('Mobile workspace'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/workspaces/$_workspaceId',
      );
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.text('Новая запись'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.queryParameters, {
        'workspaceId': _workspaceId,
      });
      expect(
        container.read(recordNotifierProvider).selectedWorkspaceId,
        _workspaceId,
      );
      expect(selected(tester), 0);
      expect(find.text('Also capture system audio'), findsNothing);

      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pump();
      final session = (await tester.runAsync(
        () => container.read(batchSessionProvider.future),
      ))!;
      var loaded = false;
      for (var attempt = 0; attempt < 100; attempt++) {
        // The shell can restore the journal before Results mounts. Advance
        // widget-zone callbacks as well as real filesystem work on each turn.
        await tester.pump(const Duration(milliseconds: 10));
        final state = container.read(resultsNotifierProvider(session));
        if (!state.page.isLoading && !state.uploads.isLoading) {
          loaded = true;
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(
        loaded,
        isTrue,
        reason: 'Results did not load its page and journal',
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/results');
      expect(selected(tester), 2);
      expect(
        adapter.requests.where((r) => r.path == '/meetings/results'),
        hasLength(1),
      );
      expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Sign In'), findsNWidgets(2));
      expect(await storage.getToken(), isNull);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
