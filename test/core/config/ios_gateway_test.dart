import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/workspace/data/workspace_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

final class _TlsFailureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw DioException(
      requestOptions: options,
      error: const HandshakeException('SYNTHETIC_PRIVATE_TLS_DETAIL'),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetStorageFakes);

  test(
    'HTTPS IP origin preserves explicit port and normal authenticated dispatch',
    () async {
      final config = AppConfig.parse(apiBaseUrl: 'https://192.0.2.25:8443');
      const storage = SecureStorage(namespace: 'ios-gateway-ip');
      await storage.saveToken('synthetic-token');
      final adapter = ScriptedAdapter()..enqueue(200, <String, dynamic>{});
      final dio = createDio(
        baseUrl: config.baseUrl,
        storage: storage,
        appConfig: config,
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await dio.get('/probe');
      expect(adapter.requests.single.uri.origin, 'https://192.0.2.25:8443');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic-token',
      );
      expect(adapter.requests.single.followRedirects, isFalse);
    },
  );

  for (final origin in [
    'http://192.0.2.25:8000',
    'http://development-mac.local:8000',
  ]) {
    test(
      'debug loopback opt-in cannot allow a Mac LAN HTTP endpoint: $origin',
      () {
        expect(
          () =>
              AppConfig.parse(apiBaseUrl: origin, allowInsecureLocalhost: true),
          throwsFormatException,
        );
      },
    );
  }

  test(
    'TLS failure stays a security error without retry, downgrade or logout',
    () async {
      const storage = SecureStorage(namespace: 'ios-gateway-tls');
      await storage.saveToken('synthetic-token');
      final adapter = _TlsFailureAdapter();
      var invalidations = 0;
      final dio = createDio(
        baseUrl: 'https://gateway.example.invalid',
        storage: storage,
        onUnauthorized: () async {
          invalidations++;
        },
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));

      await expectLater(
        WorkspaceApi(dio).getWorkspaces(),
        throwsA(
          isA<ApiFailure>()
              .having(
                (error) => error.kind,
                'category',
                ApiFailureKind.transportSecurity,
              )
              .having(
                (error) => error.toString(),
                'sanitized TLS detail',
                isNot(contains('SYNTHETIC_PRIVATE_TLS_DETAIL')),
              ),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.scheme, 'https');
      expect(invalidations, 0);
      expect(await storage.getToken(), 'synthetic-token');
    },
  );
}
