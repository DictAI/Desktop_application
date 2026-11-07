import 'dart:typed_data';

import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _private = 'SYNTHETIC_PRIVATE_BODY_NAME_TOKEN';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final ResponseBody Function(RequestOptions) reply;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => reply(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    resetStorageFakes();
    await const SecureStorage().saveToken(_private);
  });
  for (final policy in [
    (enabled: false, debug: true),
    (enabled: true, debug: false),
    (enabled: true, debug: true),
  ]) {
    test('sensitive payloads never enter diagnostics: $policy', () async {
      final logs = <String>[];
      final dio = createDio(
        baseUrl: 'https://gateway.example.invalid',
        storage: const SecureStorage(),
        enableNetworkDiagnostics: policy.enabled,
        isDebugBuild: policy.debug,
        diagnosticSink: logs.add,
      );
      addTearDown(() => dio.close(force: true));
      dio.httpClientAdapter = _Adapter(
        (options) => ResponseBody.fromString(
          '{"transcript":"$_private","name":"$_private"}',
          options.extra['fail'] == true ? 500 : 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'set-cookie': [_private],
            'x-request-id': [_private],
          },
        ),
      );
      await dio.post(
        '/auth/login',
        queryParameters: {'email': _private},
        data: {'password': _private},
        options: Options(headers: {'Cookie': _private}),
      );
      await dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'assignment_name': _private,
          'audio': MultipartFile.fromBytes([
            1,
            2,
            3,
          ], filename: '$_private.wav'),
        }),
      );
      await dio.get(
        '/$_private/auth/login',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $_private'},
        ),
      );
      await expectLater(
        dio.post(
          '/auth/login',
          data: {'name': _private},
          options: Options(extra: {'fail': true}),
        ),
        throwsA(isA<DioException>()),
      );
      dio.httpClientAdapter = _Adapter(
        (options) => throw DioException(
          requestOptions: options,
          error: _private,
          message: _private,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(dio.get('/auth/login'), throwsA(isA<DioException>()));

      expect(logs.join(), isNot(contains(_private)));
      expect(logs.join(), isNot(contains('Authorization')));
      expect(logs.join(), isNot(contains('gateway.example.invalid')));
      if (!policy.enabled || !policy.debug) {
        expect(logs, isEmpty);
      } else {
        expect(logs.first, '[HTTP] request id=1 method=POST');
        expect(logs[1], '[HTTP] response id=1 status=200');
        expect(logs, contains('[HTTP] error id=4 status=500'));
        expect(logs, contains('[HTTP] error id=5 status=none'));
      }
    });
  }

  test('a failing diagnostic sink cannot break HTTP', () async {
    final dio = createDio(
      baseUrl: 'https://gateway.example.invalid',
      storage: const SecureStorage(),
      enableNetworkDiagnostics: true,
      diagnosticSink: (_) => throw StateError('synthetic sink failure'),
    );
    addTearDown(() => dio.close(force: true));
    dio.httpClientAdapter = _Adapter((_) => ResponseBody.fromString('{}', 200));
    expect((await dio.get('/auth/login')).statusCode, 200);
  });
}
