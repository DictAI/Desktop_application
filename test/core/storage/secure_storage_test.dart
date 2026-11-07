import 'dart:async';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Memory implements SecretStore, LegacyPreferences {
  final values = <String, String>{};
  bool failRead = false,
      failWrite = false,
      failDelete = false,
      dropWrite = false;
  Completer<void>? writing;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('SYNTHETIC_PRIVATE_PLATFORM_DETAIL');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await writing?.future;
    if (failWrite) throw StateError('SYNTHETIC_PRIVATE_PLATFORM_DETAIL');
    if (!dropWrite) values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('SYNTHETIC_PRIVATE_PLATFORM_DETAIL');
    values.remove(key);
  }
}

void main() {
  late _Memory secrets, legacy;
  late SecureStorage storage;
  setUp(() {
    secrets = _Memory();
    legacy = _Memory();
    storage = SecureStorage(secrets: secrets, preferences: legacy);
  });
  test(
    'migrates all known credentials only after verified OS writes',
    () async {
      legacy.values.addAll({
        'jwt_token': 'synthetic-token',
        'user_email': 'owner@example.invalid',
        'anthropic_api_key': 'synthetic-provider',
      });
      expect(await storage.getToken(), 'synthetic-token');
      expect(await storage.getEmail(), 'owner@example.invalid');
      expect(await storage.getAnthropicKey(), 'synthetic-provider');
      expect(legacy.values, isEmpty);
      expect(secrets.writes, 3);
      await storage.getToken();
      expect(secrets.writes, 3);
    },
  );
  test('secure value wins over stale legacy after lost response', () async {
    legacy.values['jwt_token'] = 'old';
    secrets.values['jwt_token'] = 'new';
    expect(await storage.getToken(), 'new');
    expect(legacy.values, isEmpty);
    expect(secrets.writes, 0);
  });
  test(
    'failed write keeps original; retry is possible without plaintext fallback',
    () async {
      legacy.values['jwt_token'] = 'old';
      secrets.failWrite = true;
      await expectLater(
        storage.getToken(),
        throwsA(
          isA<AppException>().having(
            (e) => e.toString(),
            'safe',
            isNot(contains('PRIVATE_PLATFORM')),
          ),
        ),
      );
      expect(legacy.values['jwt_token'], 'old');
      expect(await storage.hasToken(), isFalse);
      secrets.failWrite = false;
      expect(await storage.getToken(), 'old');
      expect(legacy.values, isEmpty);
    },
  );
  test('a silently lost write never deletes legacy', () async {
    legacy.values['jwt_token'] = 'old';
    secrets.dropWrite = true;
    await expectLater(storage.getToken(), throwsA(isA<AppException>()));
    expect(legacy.values['jwt_token'], 'old');
  });
  test(
    'OS read failure does not return plaintext or crash router probe',
    () async {
      legacy.values['jwt_token'] = 'old';
      secrets.failRead = true;
      await expectLater(storage.getToken(), throwsA(isA<AppException>()));
      expect(await storage.hasToken(), isFalse);
      expect(legacy.values['jwt_token'], 'old');
    },
  );
  test(
    'failed legacy removal reports failure; retry keeps verified new value',
    () async {
      legacy.values['jwt_token'] = 'old';
      legacy.failDelete = true;
      await expectLater(storage.saveToken('new'), throwsA(isA<AppException>()));
      expect(secrets.values['jwt_token'], 'new');
      expect(legacy.values['jwt_token'], 'old');
      legacy.failDelete = false;
      expect(await storage.getToken(), isNull);
      await storage.saveToken('new');
      expect(await storage.getToken(), 'new');
      expect(legacy.values, isEmpty);
    },
  );
  test(
    'save read verify failure preserves legacy and error is explicit',
    () async {
      legacy.values['jwt_token'] = 'old';
      secrets.dropWrite = true;
      await expectLater(storage.saveToken('new'), throwsA(isA<AppException>()));
      expect(legacy.values['jwt_token'], 'old');
    },
  );
  test(
    'logout is repeatable and clears provider credential without resurrection',
    () async {
      await storage.saveToken('synthetic-token');
      await storage.saveEmail('owner@example.invalid');
      await storage.saveAnthropicKey('synthetic-provider');
      legacy.values['jwt_token'] = 'stale';
      await storage.deleteToken();
      await storage.deleteToken();
      expect(await storage.hasToken(), isFalse);
      expect(await storage.getEmail(), isNull);
      expect(await storage.getAnthropicKey(), isNull);
      expect(legacy.values, isEmpty);
      expect(secrets.values, isEmpty);
    },
  );
  test(
    'failed logout deletion remains explicit and safely retryable',
    () async {
      secrets.values['jwt_token'] = 'new';
      legacy.values['jwt_token'] = 'stale';
      secrets.failDelete = true;
      await expectLater(storage.deleteToken(), throwsA(isA<AppException>()));
      expect(legacy.values, isEmpty);
      secrets.failDelete = false;
      await storage.deleteToken();
      expect(await storage.hasToken(), isFalse);
    },
  );
  test('migration and later logout are serialized across instances', () async {
    legacy.values['jwt_token'] = 'old';
    final gate = Completer<void>();
    secrets.writing = gate;
    final read = storage.getToken();
    final other = SecureStorage(secrets: secrets, preferences: legacy);
    final logout = other.deleteToken();
    gate.complete();
    expect(await read, 'old');
    await logout;
    expect(await other.getToken(), isNull);
  });
  test('namespace isolates smoke fixtures from production values', () async {
    legacy.values['jwt_token'] = 'production-synthetic';
    final smoke = SecureStorage(
      secrets: secrets,
      preferences: legacy,
      namespace: 'test',
    );
    await smoke.saveToken('smoke-synthetic');
    await smoke.deleteToken();
    expect(legacy.values['jwt_token'], 'production-synthetic');
    expect(secrets.values, isEmpty);
  });
  test(
    'provider delete removes old and new copies without activating chat',
    () async {
      legacy.values['anthropic_api_key'] = 'old';
      await storage.deleteAnthropicKey();
      expect(await storage.getAnthropicKey(), isNull);
    },
  );
}
