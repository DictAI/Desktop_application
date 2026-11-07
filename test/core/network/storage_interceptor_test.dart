import 'dart:typed_data';

import 'package:dict_ai/core/network/auth_interceptor.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingSecrets implements SecretStore {
  bool failRead = true;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('synthetic hidden storage error');
    return key == 'jwt_token' ? 'synthetic-token' : null;
  }

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('denied');
  @override
  Future<void> delete(String key) async => throw StateError('denied');
}

class _Preferences implements LegacyPreferences {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls++;
    return ResponseBody.fromString('{}', 401);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final readFailure in [true, false]) {
    test('storage failure completes Dio; read failure=$readFailure', () async {
      final secrets = _FailingSecrets()..failRead = readFailure;
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.invalid'));
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        AuthInterceptor(
          SecureStorage(secrets: secrets, preferences: _Preferences()),
        ),
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get('/protected').timeout(const Duration(seconds: 2)),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'safe storage failure',
            isA<AppException>(),
          ),
        ),
      );
      expect(adapter.calls, readFailure ? 0 : 1);
    });
  }
}
