import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    requests.add(o);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'synthetic-token'});
    SharedPreferences.setMockInitialValues({'jwt_token': 'synthetic-token'});
  });
  tearDown(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  for (final value in [
    '',
    'http://remote.example.invalid',
    'https://a.example.invalid/path',
    'https://user:synthetic@a.example.invalid',
    'https://a.example.invalid?token=synthetic',
    'https://a.example.invalid#f',
    'ftp://a.example.invalid',
    '//a.example.invalid',
    ' https://a.example.invalid',
  ]) {
    test('invalid gateway origin is rejected: $value', () {
      expect(
        () => AppConfig.parse(apiBaseUrl: value, allowInsecureLocalhost: true),
        throwsFormatException,
      );
    });
  }
  test(
    'localhost HTTP requires explicit debug opt-in; simulated release denies',
    () {
      expect(
        () => AppConfig.parse(apiBaseUrl: 'http://localhost:8000'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.parse(
          apiBaseUrl: 'http://localhost:8000',
          allowInsecureLocalhost: true,
          isDebugBuild: false,
        ),
        throwsFormatException,
      );
      expect(
        AppConfig.parse(
          apiBaseUrl: 'http://localhost:8000',
          allowInsecureLocalhost: true,
        ).baseUrl,
        'http://localhost:8000',
      );
      expect(
        AppConfig.parse(
          apiBaseUrl: 'https://EXAMPLE.invalid:443/',
          enableNetworkDiagnostics: true,
          isDebugBuild: false,
        ).networkDiagnostics,
        isFalse,
      );
    },
  );

  for (final url in [
    'https://other.example.invalid/p',
    '//other.example.invalid/p',
    'http://gateway.example.invalid/p',
    'https://gateway.example.invalid:8443/p',
    'https://user:synthetic@gateway.example.invalid/p',
  ]) {
    test('foreign URL blocked before dispatch: $url', () async {
      final dio = createDio(
        baseUrl: 'https://gateway.example.invalid',
        storage: const SecureStorage(),
      );
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get(url),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'policy',
            isA<GatewayPolicyException>(),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    });
  }
  test(
    'same-origin relative/absolute calls retain AuthInterceptor and bounded policies',
    () async {
      final dio = createDio(
        baseUrl: 'https://gateway.example.invalid',
        storage: const SecureStorage(),
      );
      final adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await dio.get('/meetings/results');
      await dio.post(
        '/ingest/v2/audio/upload',
        data: FormData.fromMap({
          'audio': MultipartFile.fromBytes([1, 2]),
        }),
      );
      await dio.get(
        'https://gateway.example.invalid:443/ingest/v2/audio/a/original',
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      expect(
        adapter.requests.map((o) => o.headers['Authorization']),
        everyElement('Bearer synthetic-token'),
      );
      expect(adapter.requests[0].receiveTimeout, const Duration(seconds: 30));
      expect(adapter.requests[1].sendTimeout, const Duration(minutes: 15));
      expect(adapter.requests[1].receiveTimeout, const Duration(minutes: 15));
      expect(adapter.requests[2].receiveTimeout, const Duration(minutes: 15));
      expect(
        adapter.requests.every(
          (o) => !o.followRedirects && o.maxRedirects == 0,
        ),
        isTrue,
      );
      adapter.status = 500;
      await expectLater(
        dio.post('/ingest/v2/audio/upload'),
        throwsA(isA<DioException>()),
      );
      expect(
        adapter.requests.length,
        4,
        reason: 'No automatic replay of a POST',
      );
    },
  );
  test(
    'actual loopback redirect cannot forward JWT to another origin',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await origin.close(force: true);
        await target.close(force: true);
      });
      int targetRequests = 0;
      target.listen((r) {
        targetRequests++;
        r.response.statusCode = 200;
        r.response.close();
      });
      String? originAuth;
      origin.listen((r) {
        originAuth = r.headers.value('authorization');
        r.response.statusCode = 302;
        r.response.headers.set(
          'location',
          'http://127.0.0.1:${target.port}/target',
        );
        r.response.close();
      });
      final config = AppConfig.parse(
        apiBaseUrl: 'http://127.0.0.1:${origin.port}',
        allowInsecureLocalhost: true,
      );
      final dio = createDio(
        baseUrl: config.baseUrl,
        appConfig: config,
        storage: const SecureStorage(),
      );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get('/source', options: Options(followRedirects: true)),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'no redirect',
            302,
          ),
        ),
      );
      expect(originAuth, 'Bearer synthetic-token');
      expect(targetRequests, 0);
    },
  );
}
