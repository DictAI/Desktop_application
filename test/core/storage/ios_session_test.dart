import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

// This exercises production SecureStorage through the plugin channel on the
// host. It does not simulate iOS or inspect native protection attributes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> nativeValues;
  late List<MethodCall> calls;
  late SecureStorage storage;
  late String namespace;
  String? deniedMethod;
  var sequence = 0;

  setUp(() {
    nativeValues = {};
    calls = [];
    deniedMethod = null;
    namespace = 'dictai.ios.session.test.${sequence++}';
    storage = SecureStorage(namespace: namespace);
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == deniedMethod) {
        throw PlatformException(
          code: 'synthetic_denied',
          message: 'SYNTHETIC_PRIVATE_PLATFORM_DETAIL',
          details: 'SYNTHETIC_PRIVATE_PLATFORM_DETAIL',
        );
      }
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = args['key'] as String;
      expect(key, startsWith('$namespace::'));
      switch (call.method) {
        case 'read':
          return nativeValues[key];
        case 'write':
          nativeValues[key] = args['value'] as String;
          return null;
        case 'delete':
          nativeValues.remove(key);
          return null;
        default:
          fail('Unexpected secure storage channel operation');
      }
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'channel migration verifies all native values before removing legacy',
    () async {
      final fixtures = {
        'jwt_token': 'synthetic-token',
        'user_email': 'smoke@example.invalid',
        'anthropic_api_key': 'synthetic-provider',
      };
      SharedPreferences.setMockInitialValues({
        for (final entry in fixtures.entries)
          '$namespace::${entry.key}': entry.value,
      });

      expect(await storage.getToken(), fixtures['jwt_token']);
      expect(await storage.getEmail(), fixtures['user_email']);
      expect(await storage.getAnthropicKey(), fixtures['anthropic_api_key']);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in fixtures.entries) {
        expect(nativeValues['$namespace::${entry.key}'], entry.value);
        expect(prefs.containsKey('$namespace::${entry.key}'), isFalse);
      }
      expect(calls.where((call) => call.method == 'write'), hasLength(3));
    },
  );

  test(
    'native read denial cannot expose a retained plaintext credential',
    () async {
      SharedPreferences.setMockInitialValues({
        '$namespace::jwt_token': 'synthetic-legacy-token',
      });
      deniedMethod = 'read';

      await expectLater(
        storage.getToken(),
        throwsA(
          isA<AppException>().having(
            (error) => error.toString(),
            'sanitized native failure',
            isNot(contains('SYNTHETIC_PRIVATE_PLATFORM_DETAIL')),
          ),
        ),
      );
      expect(await storage.hasToken(), isFalse);
      expect(nativeValues, isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          '$namespace::jwt_token',
        ),
        'synthetic-legacy-token',
      );
    },
  );

  test(
    'failed native migration write preserves legacy for a verified retry',
    () async {
      SharedPreferences.setMockInitialValues({
        '$namespace::jwt_token': 'synthetic-legacy-token',
      });
      deniedMethod = 'write';
      await expectLater(storage.getToken(), throwsA(isA<AppException>()));
      expect(nativeValues, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('$namespace::jwt_token'),
        'synthetic-legacy-token',
      );

      deniedMethod = null;
      expect(await storage.getToken(), 'synthetic-legacy-token');
      expect(prefs.containsKey('$namespace::jwt_token'), isFalse);
      expect(nativeValues['$namespace::jwt_token'], 'synthetic-legacy-token');
    },
  );

  test(
    'new storage instance reads channel state and logout removes all account keys',
    () async {
      await storage.saveToken('synthetic-token');
      await storage.saveEmail('smoke@example.invalid');
      await storage.saveAnthropicKey('synthetic-provider');
      final restarted = SecureStorage(namespace: namespace);
      expect(await restarted.getToken(), 'synthetic-token');
      expect(await restarted.getEmail(), 'smoke@example.invalid');

      await restarted.deleteToken();
      expect(nativeValues, isEmpty);
      expect(await storage.readCredential(), isNull);
      expect(await storage.getEmail(), isNull);
      expect(await storage.getAnthropicKey(), isNull);
      expect(
        calls
            .where((call) => call.method == 'delete')
            .map((call) => (call.arguments as Map)['key']),
        unorderedEquals([
          '$namespace::jwt_token',
          '$namespace::user_email',
          '$namespace::anthropic_api_key',
        ]),
      );
    },
  );

  test(
    '401 with native deletion denied closes session before another request',
    () async {
      await storage.saveToken('synthetic-token');
      final adapter = ScriptedAdapter()
        ..enqueue(401, {'error': 'unauthorized'})
        ..enqueue(200, <String, dynamic>{});
      var invalidations = 0;
      final dio = createDio(
        baseUrl: 'https://gateway.example.invalid',
        storage: storage,
        onUnauthorized: () async {
          invalidations++;
        },
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      deniedMethod = 'delete';

      await expectLater(
        dio.get('/protected'),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'native cleanup failure',
            isA<AppException>(),
          ),
        ),
      );
      expect(invalidations, 1);
      expect(nativeValues['$namespace::jwt_token'], 'synthetic-token');
      expect(await storage.readCredential(), isNull);
      await dio.get('/protected');
      expect(
        adapter.requests.first.headers['Authorization'],
        'Bearer synthetic-token',
      );
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );

      deniedMethod = null;
      await storage.deleteToken();
      expect(nativeValues, isEmpty);
      expect(storage.credentialCleanupPending, isFalse);
    },
  );
}
