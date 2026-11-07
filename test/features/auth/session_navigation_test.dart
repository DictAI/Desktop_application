import 'dart:convert';

import 'package:dict_ai/app.dart';
import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/data/auth_api.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

String jwt(
  DateTime expiration, {
  String owner = 'fixture-owner',
  String issuer = 'dictai-auth-v2',
}) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'HS256'})}.${segment({'iss': issuer, 'aud': 'dictai-user', 'user_id': owner, 'exp': expiration.millisecondsSinceEpoch ~/ 1000})}.fixture';
}

class _FailingKeychain implements SecretStore {
  final values = <String, String>{};
  bool failTokenWrite = false;
  bool failAfterTokenWrite = false;
  String? failDelete;

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    final token = key.endsWith('::jwt_token');
    if (token && failTokenWrite) throw StateError('keychain write failed');
    values[key] = value;
    if (token && failAfterTokenWrite) throw StateError('confirmation lost');
  }

  @override
  Future<void> delete(String key) async {
    if (key.split('::').last == failDelete) {
      throw StateError('keychain delete failed');
    }
    values.remove(key);
  }
}

class _FailingLegacy implements LegacyPreferences {
  bool failTokenDelete = false;
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {
    if (failTokenDelete && key.endsWith('::jwt_token')) {
      throw StateError('legacy cleanup failed');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SecureStorage();
  final now = DateTime.utc(2026, 11, 3, 12);
  final token = jwt(now.add(const Duration(hours: 1)));
  final renewed = jwt(now.add(const Duration(days: 7)));
  setUp(resetStorageFakes);

  Dio client(
    ScriptedAdapter adapter, {
    Future<void> Function()? onUnauthorized,
    SecureStorage secureStorage = storage,
  }) {
    final dio = createDio(
      baseUrl: 'https://fixture.invalid',
      storage: secureStorage,
      onUnauthorized: onUnauthorized,
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return dio;
  }

  AuthNotifier notifier(Dio dio) {
    final auth = AuthNotifier(AuthApi(dio), storage, now: () => now);
    addTearDown(auth.dispose);
    return auth;
  }

  test(
    'stale 401 cannot delete a new session with a byte-identical JWT',
    () async {
      var notifications = 0;
      final adapter = ScriptedAdapter();
      final first = adapter.defer();
      final dio = client(
        adapter,
        onUnauthorized: () async {
          notifications++;
        },
      );
      await storage.saveToken(token);
      final request = dio.get('/meetings/results');
      final rejected = expectLater(request, throwsA(isA<DioException>()));
      await adapter.firstRequest.future;
      await storage.deleteToken();
      await storage.saveEmail('new@example.invalid');
      await storage.saveToken(token);
      first.complete(ScriptedAdapter.reply(401, {'error': 'unauthorized'}));
      await rejected;
      expect(await storage.getToken(), token);
      expect(await storage.getEmail(), 'new@example.invalid');
      expect(notifications, 0);
    },
  );

  test('matched 401 deletes credentials and notifies once', () async {
    var notifications = 0;
    final adapter = ScriptedAdapter()..enqueue(401, {'error': 'unauthorized'});
    final dio = client(
      adapter,
      onUnauthorized: () async {
        notifications++;
      },
    );
    await storage.saveToken(token);
    await storage.saveEmail('owner@example.invalid');
    await expectLater(
      dio.get('/meetings/results'),
      throwsA(isA<DioException>()),
    );
    expect(await storage.getToken(), isNull);
    expect(await storage.getEmail(), isNull);
    expect(notifications, 1);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'login 401 does not consume existing credential or send caller JWT',
    () async {
      var notifications = 0;
      final adapter = ScriptedAdapter()
        ..enqueue(401, {'error': 'wrong password'});
      final dio = client(
        adapter,
        onUnauthorized: () async {
          notifications++;
        },
      );
      await storage.saveToken(token);
      await expectLater(
        dio.post(
          '/auth/login',
          options: Options(headers: {'authorization': 'Bearer fixture'}),
        ),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(await storage.getToken(), token);
      expect(notifications, 0);
    },
  );

  for (final invalid in [
    jwt(now),
    jwt(now.add(const Duration(days: 1)), issuer: 'old'),
    'malformed',
  ]) {
    test(
      'expired/old/malformed credential is removed without refresh (${invalid.length})',
      () async {
        final adapter = ScriptedAdapter();
        final auth = notifier(client(adapter));
        await storage.saveToken(invalid);
        expect(await auth.hasValidSession(), isFalse);
        expect(await storage.getToken(), isNull);
        await auth.refreshSession();
        expect(adapter.requests, isEmpty);
      },
    );
  }

  test(
    'valid refresh is single-flight and preserves the login identity',
    () async {
      final adapter = ScriptedAdapter();
      final response = adapter.defer();
      final auth = notifier(client(adapter));
      await storage.saveToken(token);
      final refresh = auth.refreshSession();
      await adapter.firstRequest.future;
      await auth.refreshSession();
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/auth/refresh');
      expect(adapter.requests.single.data, <String, dynamic>{});
      expect(adapter.requests.single.headers['Authorization'], 'Bearer $token');
      response.complete(ScriptedAdapter.reply(200, {'token': renewed}));
      await refresh;
      expect(await storage.getToken(), renewed);
    },
  );

  test(
    'refresh cannot overwrite a new credential with identical previous bytes',
    () async {
      final adapter = ScriptedAdapter();
      final response = adapter.defer();
      final auth = notifier(client(adapter));
      await storage.saveToken(token);
      final refresh = auth.refreshSession();
      await adapter.firstRequest.future;
      await storage.deleteToken();
      await storage.saveToken(token);
      response.complete(ScriptedAdapter.reply(200, {'token': renewed}));
      await refresh;
      expect(await storage.getToken(), token);
    },
  );

  test(
    'logout supersedes late login, duplicate login emits one POST',
    () async {
      final adapter = ScriptedAdapter();
      final response = adapter.defer();
      final auth = notifier(client(adapter));
      var callbacks = 0;
      Future<void> login() => auth.login(
        email: 'owner@example.invalid',
        password: 'fixture',
        onSuccess: () {
          callbacks++;
        },
      );
      final pending = login();
      await adapter.firstRequest.future;
      await login();
      expect(adapter.requests, hasLength(1));
      await auth.logout();
      response.complete(ScriptedAdapter.reply(200, {'token': token}));
      await pending;
      expect(callbacks, 0);
      expect(await storage.getToken(), isNull);
      expect(await storage.getEmail(), isNull);
    },
  );

  test(
    'retry clears login error and register retains signed-out state',
    () async {
      final adapter = ScriptedAdapter()
        ..enqueue(401, {'error': 'wrong password'});
      final auth = notifier(client(adapter));
      await auth.login(
        email: 'owner@example.invalid',
        password: 'fixture',
        onSuccess: () => fail('invalid login'),
      );
      expect(auth.state.errorMessage, isNotNull);
      final reply = adapter.defer();
      var registered = false;
      final pending = auth.register(
        email: 'owner@example.invalid',
        password: 'яяяя',
        onSuccess: () {
          registered = true;
        },
      );
      expect(auth.state.errorMessage, isNull);
      expect(auth.state.status, AuthStatus.loading);
      reply.complete(ScriptedAdapter.reply(200, {'message': 'registered'}));
      await pending;
      expect(registered, isTrue);
      expect(await storage.getToken(), isNull);
    },
  );

  test(
    'failed logout keeps retained JWT out of future HTTP requests',
    () async {
      final keys = _FailingKeychain();
      final legacy = _FailingLegacy();
      final session = SecureStorage(
        secrets: keys,
        preferences: legacy,
        namespace: 'logout-failure',
      );
      final adapter = ScriptedAdapter()
        ..enqueue(401, {'error': 'unauthorized'});
      final dio = client(adapter, secureStorage: session);
      final auth = AuthNotifier(AuthApi(dio), session, now: () => now);
      addTearDown(auth.dispose);
      await session.saveToken(token);
      legacy.failTokenDelete = true;
      await auth.logout();
      expect(auth.state.status, AuthStatus.error);
      expect(keys.values.values, contains(token));
      expect(await session.readCredential(), isNull);
      expect(await auth.hasValidSession(), isFalse);
      await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));
      expect(adapter.requests.single.headers['Authorization'], isNull);
    },
  );

  test(
    'matched 401 notifies even when deleting stored credentials fails',
    () async {
      final keys = _FailingKeychain();
      final session = SecureStorage(
        secrets: keys,
        preferences: _FailingLegacy(),
        namespace: '401-cleanup-failure',
      );
      final adapter = ScriptedAdapter()
        ..enqueue(401, {'error': 'unauthorized'});
      var notified = false;
      final dio = client(
        adapter,
        secureStorage: session,
        onUnauthorized: () async {
          notified = true;
          throw StateError('listener disposed');
        },
      );
      await session.saveEmail('owner@example.invalid');
      await session.saveToken(token);
      keys.failDelete = 'user_email';
      await expectLater(
        dio.get('/protected').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()),
      );
      expect(notified, isTrue);
      expect(session.credentialCleanupPending, isTrue);
      expect(await session.readCredential(), isNull);
    },
  );

  test('partial login stays closed until complete successful retry', () async {
    final keys = _FailingKeychain();
    final legacy = _FailingLegacy()..failTokenDelete = true;
    final session = SecureStorage(
      secrets: keys,
      preferences: legacy,
      namespace: 'partial-login',
    );
    final adapter = ScriptedAdapter()
      ..enqueue(200, {'token': token})
      ..enqueue(200, {'token': token});
    final auth = AuthNotifier(
      AuthApi(client(adapter, secureStorage: session)),
      session,
      now: () => now,
    );
    addTearDown(auth.dispose);
    var logins = 0;
    Future<void> login() => auth.login(
      email: 'owner@example.invalid',
      password: 'fixture',
      onSuccess: () {
        logins++;
      },
    );
    await login();
    expect(keys.values.values, contains(token));
    expect(auth.state.status, AuthStatus.error);
    expect(await auth.hasValidSession(), isFalse);
    expect(logins, 0);
    legacy.failTokenDelete = false;
    await login();
    expect(auth.state.status, AuthStatus.success);
    expect(await auth.hasValidSession(), isTrue);
    expect(logins, 1);
  });

  testWidgets(
    'unchanged token after failed Keychain renewal still expires on its timer',
    (tester) async {
      final keys = _FailingKeychain();
      final session = SecureStorage(
        secrets: keys,
        preferences: _FailingLegacy(),
        namespace: 'failed-renewal',
      );
      final clock = tester.binding.clock;
      final oldToken = jwt(
        clock.now().add(const Duration(minutes: 5, seconds: 3)),
      );
      final newToken = jwt(clock.now().add(const Duration(days: 7)));
      final adapter = ScriptedAdapter()..enqueue(200, {'token': newToken});
      final auth = AuthNotifier(
        AuthApi(client(adapter, secureStorage: session)),
        session,
        now: clock.now,
      );
      addTearDown(auth.dispose);
      await session.saveToken(oldToken);
      expect(await auth.hasValidSession(), isTrue);
      keys.failTokenWrite = true;
      await tester.pump(const Duration(seconds: 4));
      expect(adapter.requests, hasLength(1));
      expect(await session.getToken(), oldToken);
      await tester.pump(const Duration(minutes: 5));
      expect(await session.getToken(), isNull);
      expect(auth.state.status, AuthStatus.expired);
    },
  );

  test(
    'uncertain renewal write fails closed instead of publishing changed JWT',
    () async {
      final keys = _FailingKeychain();
      final session = SecureStorage(
        secrets: keys,
        preferences: _FailingLegacy(),
        namespace: 'uncertain-renewal',
      );
      final adapter = ScriptedAdapter()..enqueue(200, {'token': renewed});
      final auth = AuthNotifier(
        AuthApi(client(adapter, secureStorage: session)),
        session,
        now: () => now,
      );
      addTearDown(auth.dispose);
      await session.saveToken(token);
      keys.failAfterTokenWrite = true;
      await auth.refreshSession();
      expect(keys.values.values, contains(renewed));
      expect(auth.state.status, AuthStatus.error);
      expect(await session.readCredential(), isNull);
      expect(await auth.hasValidSession(), isFalse);
    },
  );

  testWidgets(
    'failed proactive renewal attempts once and still expires locally',
    (tester) async {
      final adapter = ScriptedAdapter()..enqueue(503, {'error': 'unavailable'});
      final auth = AuthNotifier(
        AuthApi(client(adapter)),
        storage,
        now: tester.binding.clock.now,
      );
      addTearDown(auth.dispose);
      final deadline = tester.binding.clock.now().add(
        const Duration(minutes: 5, seconds: 3),
      );
      final initialToken = jwt(deadline);
      await storage.saveToken(initialToken);
      expect(await auth.hasValidSession(), isTrue);
      await tester.pump(const Duration(seconds: 4));
      expect(adapter.requests, hasLength(1));
      expect(await storage.getToken(), initialToken);
      expect(await auth.hasValidSession(), isTrue);
      await tester.pump(const Duration(minutes: 5));
      expect(await storage.getToken(), isNull);
      expect(auth.state.status, AuthStatus.expired);
      expect(adapter.requests, hasLength(1));
    },
  );

  testWidgets(
    'actual router leaves Workspaces after matched 401 and guards Record/Results',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
          ),
        ],
      );
      final dio = container.read(dioProvider);
      final adapter = ScriptedAdapter()
        ..enqueue(200, {
          'data': [],
          'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
        });
      dio.httpClientAdapter = adapter;
      final router = container.read(routerProvider);
      router.go('/workspaces');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        dio.close(force: true);
      });
      await storage.saveToken(
        jwt(DateTime.now().add(const Duration(hours: 1))),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/workspaces');
      adapter.enqueue(401, {'error': 'unauthorized'});
      final rejected = expectLater(
        dio.get('/protected'),
        throwsA(isA<DioException>()),
      );
      await tester.pumpAndSettle();
      await rejected;
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        find.text('Срок действия сессии истёк. Войдите снова.'),
        findsOneWidget,
      );
      for (final path in ['/record', '/results']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/login');
      }
      expect(adapter.requests.where((r) => r.path == '/auth/refresh'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
