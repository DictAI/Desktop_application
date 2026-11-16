import 'dart:convert';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/auth/presentation/login_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

Finder _field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': 'login-fixture', 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

void main() {
  setUp(resetStorageFakes);

  Future<({GoRouter router, ScriptedAdapter adapter})> mount(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double textScale = 1,
    double keyboard = 0,
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    await tester.binding.setSurfaceSize(size);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
      ],
    );
    final adapter = ScriptedAdapter();
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/record',
          builder: (_, __) => const Scaffold(body: Text('Authenticated route')),
        ),
      ],
    );
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
          theme: AppTheme.dark.copyWith(platform: platform),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: 47, bottom: keyboard > 0 ? 0 : 34),
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
    return (router: router, adapter: adapter);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('forms and validation scroll above keyboard at width $width', (
      tester,
    ) async {
      final fixture = await mount(
        tester,
        size: Size(width, 812),
        textScale: 2,
        keyboard: 280,
      );
      await tapVisible(tester, find.byType(ElevatedButton));
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      await tapVisible(tester, find.text('Sign Up'));
      expect(find.text('Create Account'), findsOneWidget);
      expect(_field('Confirm Password'), findsOneWidget);
      await tapVisible(tester, find.byType(ElevatedButton));
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      final button = tester.getRect(find.byType(ElevatedButton));
      expect(button.left, greaterThanOrEqualTo(16));
      expect(button.right, lessThanOrEqualTo(width - 16));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(fixture.adapter.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('landscape signup keeps confirmation and submit reachable', (
    tester,
  ) async {
    await mount(
      tester,
      size: const Size(812, 375),
      keyboard: 150,
      textScale: 2,
    );
    await tapVisible(tester, find.text('Sign Up'));
    await tester.ensureVisible(_field('Confirm Password'));
    await tester.enterText(_field('Confirm Password'), 'mismatch');
    await tapVisible(tester, find.byType(ElevatedButton));
    expect(find.text('Passwords do not match'), findsOneWidget);
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(ElevatedButton)).bottom,
      lessThanOrEqualTo(375 - 150),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sign in submits unchanged credentials and navigates on success',
    (tester) async {
      final fixture = await mount(tester, keyboard: 280);
      fixture.adapter.enqueue(200, {'token': _token()});
      await tester.enterText(_field('Email'), ' owner@example.invalid ');
      await tester.enterText(_field('Password'), '短');
      await tapVisible(tester, find.byType(ElevatedButton));
      expect(fixture.router.routeInformationProvider.value.uri.path, '/record');
      expect(find.text('Authenticated route'), findsOneWidget);
      expect(fixture.adapter.requests.single.path, '/auth/login');
      expect(fixture.adapter.requests.single.data, {
        'email': 'owner@example.invalid',
        'password': '短',
      });
      expect(await const SecureStorage().getToken(), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signup keeps UTF-8 byte validation and returns to sign in', (
    tester,
  ) async {
    final fixture = await mount(tester, textScale: 2, keyboard: 280);
    await tapVisible(tester, find.text('Sign Up'));
    await tester.enterText(_field('Email'), 'new@example.invalid');
    await tester.enterText(_field('Password'), 'яяя');
    await tester.enterText(_field('Confirm Password'), 'яяя');
    await tapVisible(tester, find.byType(ElevatedButton));
    expect(
      find.text('Password must be at least 8 UTF-8 bytes'),
      findsOneWidget,
    );
    expect(fixture.adapter.requests, isEmpty);
    await tester.enterText(_field('Password'), 'яяяя');
    await tester.enterText(_field('Confirm Password'), 'яяяя');
    fixture.adapter.enqueue(200, {'message': 'registered'});
    await tapVisible(tester, find.byType(ElevatedButton));
    expect(fixture.adapter.requests.single.path, '/auth/register');
    expect(fixture.adapter.requests.single.data, {
      'email': 'new@example.invalid',
      'password': 'яяяя',
    });
    expect(_field('Confirm Password'), findsNothing);
    expect(
      tester.widget<TextFormField>(_field('Email')).controller!.text,
      'new@example.invalid',
    );
    expect(fixture.router.routeInformationProvider.value.uri.path, '/login');
    expect(await const SecureStorage().getToken(), isNull);
    expect(find.text('Account created. Please sign in.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading disables submit and tab changes clear the server error',
    (tester) async {
      final fixture = await mount(tester, textScale: 2, keyboard: 280);
      final response = fixture.adapter.defer();
      await tester.enterText(_field('Email'), 'owner@example.invalid');
      await tester.enterText(_field('Password'), 'fixture');
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(
        ScriptedAdapter.reply(401, {'error': 'wrong password'}),
      );
      await tester.pumpAndSettle();
      expect(fixture.adapter.requests, hasLength(1));
      expect(
        find.text('Не удалось войти. Проверьте email и пароль.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Sign Up'));
      expect(
        find.text('Не удалось войти. Проверьте email и пароль.'),
        findsNothing,
      );
      await tapVisible(tester, find.text('Sign In').first);
      expect(
        tester.widget<TextFormField>(_field('Email')).controller!.text,
        'owner@example.invalid',
      );
      expect(
        tester.widget<TextFormField>(_field('Password')).controller!.text,
        'fixture',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fields and password controls expose accessible labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester);
    expect(find.bySemanticsLabel(RegExp('Email')), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel(RegExp('Password')), findsAtLeastNWidgets(1));
    await tapVisible(tester, find.byTooltip('Show password'));
    expect(find.byTooltip('Hide password'), findsOneWidget);
    final password = find.descendant(
      of: _field('Password'),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    await tapVisible(tester, find.text('Sign Up'));
    expect(find.byTooltip('Show confirmation password'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('desktop retains a centered constrained form', (tester) async {
    await mount(
      tester,
      size: const Size(1280, 800),
      platform: TargetPlatform.macOS,
    );
    final field = tester.getRect(_field('Email'));
    expect(field.width, lessThan(440));
    expect(field.center.dx, 640);
    expect(find.text('Dict AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
