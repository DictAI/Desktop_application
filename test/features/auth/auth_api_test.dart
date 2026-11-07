import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/data/auth_api.dart';
import 'package:dict_ai/features/auth/data/dto/login_request.dart';
import 'package:dict_ai/features/auth/data/dto/register_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ScriptedAdapter adapter;
  late Dio dio;
  late AuthApi api;
  const storage = SecureStorage();

  setUp(() {
    resetStorageFakes();
    FlutterSecureStorage.setMockInitialValues({
      'jwt_token': 'synthetic-current-token',
    });
    adapter = ScriptedAdapter();
    dio = createDio(baseUrl: 'https://example.invalid', storage: storage)
      ..httpClientAdapter = adapter;
    api = AuthApi(dio);
  });
  tearDown(() {
    dio.close(force: true);
    resetStorageFakes();
  });

  test(
    'login sends exact wire data and receives token without storing it',
    () async {
      adapter.enqueue(200, {'token': 'synthetic-new-token'});
      final response = await api.login(
        const LoginRequest(
          email: ' Owner@example.invalid ',
          password: '  пароль  ',
        ),
      );
      expect(response.token, 'synthetic-new-token');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/login');
      expect(request.data, {
        'email': ' Owner@example.invalid ',
        'password': '  пароль  ',
      });
      expect(request.headers['Authorization'], isNull);
      expect(await storage.getToken(), 'synthetic-current-token');
    },
  );

  test(
    'register consumes 200 message; no invented user_id or auto-login',
    () async {
      adapter.enqueue(200, {'message': 'user registered successfully'});
      await api.register(
        const RegisterRequest(email: 'owner@example.invalid', password: 'яяяя'),
      );
      expect(adapter.requests.single.data, {
        'email': 'owner@example.invalid',
        'password': 'яяяя',
      });
      expect(adapter.requests.single.headers['Authorization'], isNull);
      expect(adapter.requests.single.path, '/auth/register');
      expect(await storage.getToken(), 'synthetic-current-token');
    },
  );

  test('refresh posts JSON object with current JWT and parses token', () async {
    adapter.enqueue(200, {'token': 'synthetic-refreshed-token'});
    expect((await api.refresh()).token, 'synthetic-refreshed-token');
    final request = adapter.requests.single;
    expect(request.path, '/auth/refresh');
    expect(request.data, <String, dynamic>{});
    expect(request.contentType, Headers.jsonContentType);
    expect(request.headers['Authorization'], 'Bearer synthetic-current-token');
  });

  test(
    'account methods use new_password/new_email, 201, and existing JWT',
    () async {
      adapter.enqueue(201, {'message': 'password changed successfully'});
      adapter.enqueue(201, {'message': 'email changed successfully'});
      await api.changePassword('  new password  ');
      await api.changeEmail('new@example.invalid');
      expect(adapter.requests.map((r) => r.path), [
        '/auth/change-password',
        '/auth/change-email',
      ]);
      expect(adapter.requests.map((r) => r.data), [
        {'new_password': '  new password  '},
        {'new_email': 'new@example.invalid'},
      ]);
      expect(
        adapter.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer synthetic-current-token',
        ),
        isTrue,
      );
    },
  );

  for (final status in [400, 401, 403, 404, 409, 429, 500]) {
    test(
      'auth error $status maps safely from text, no raw backend reason',
      () async {
        adapter.enqueue(
          status,
          'sensitive backend error',
          contentType: 'text/plain',
        );
        await expectLater(
          api.login(
            const LoginRequest(
              email: 'owner@example.invalid',
              password: 'synthetic',
            ),
          ),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.statusCode, 'status', status)
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('sensitive')),
                ),
          ),
        );
      },
    );
  }

  final invalid = <Object?>[
    null,
    [],
    {},
    {'access_token': 'wrong field'},
    {'token': null},
    {'token': ''},
    {'token': '  '},
    {'token': 12},
  ];
  for (var i = 0; i < invalid.length; i++) {
    test('malformed token response $i fails explicitly', () async {
      adapter.enqueue(200, invalid[i]);
      await expectLater(
        api.refresh(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  }

  test(
    'malformed message and wrong successful status are not accepted',
    () async {
      adapter.enqueue(200, {'token': 'not a registration response'});
      adapter.enqueue(200, {'message': 'wrong status'});
      await expectLater(
        api.register(
          const RegisterRequest(
            email: 'owner@example.invalid',
            password: 'synthetic',
          ),
        ),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        api.changeEmail('new@example.invalid'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
}
