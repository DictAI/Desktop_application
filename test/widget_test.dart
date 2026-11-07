import 'dart:async';
import 'dart:typed_data';

import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('real app guards protected routes without HTTP or hardware', (
    tester,
  ) async {
    final adapter = ScriptedAdapter();
    final container = await pumpTestApp(tester, adapter);
    final router = container.read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Dict AI'), findsOneWidget);
    router.go('/results');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(adapter.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form validation does not send an invalid request', (
    tester,
  ) async {
    final adapter = ScriptedAdapter();
    await pumpTestApp(tester, adapter);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('delayed 401 reaches real auth state and login error UI', (
    tester,
  ) async {
    final adapter = ScriptedAdapter();
    final response = adapter.defer();
    final container = await pumpTestApp(tester, adapter);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'person@example.invalid');
    await tester.enterText(fields.at(1), 'synthetic-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await _pumpUntil(tester, () => adapter.requests.isNotEmpty);
    expect(container.read(authNotifierProvider).status, AuthStatus.loading);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(adapter.requests.single.path, '/auth/login');
    response.complete(ScriptedAdapter.reply(401, {'error': 'fixture'}));
    await _pumpUntil(
      tester,
      () => container.read(authNotifierProvider).status == AuthStatus.error,
    );
    await tester.pumpAndSettle();
    expect(container.read(authNotifierProvider).status, AuthStatus.error);
    expect(
      find.text('Не удалось войти. Проверьте email и пароль.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'adapter supplies text errors and binary responses without sockets',
    () async {
      final adapter = ScriptedAdapter()
        ..enqueue(500, '<html>fixture</html>', contentType: 'text/html')
        ..enqueue(
          200,
          Uint8List.fromList([0, 255, 1]),
          contentType: 'audio/wav',
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await expectLater(
        dio.get<Object>('/fixture/error'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.data,
            'text body',
            '<html>fixture</html>',
          ),
        ),
      );
      final bytes = await dio.get<List<int>>(
        '/fixture/bytes',
        options: Options(responseType: ResponseType.bytes),
      );
      expect(bytes.data, [0, 255, 1]);
      expect(adapter.requests, hasLength(2));
    },
  );

  testWidgets('virtual polling stops on dispose and late reply is harmless', (
    tester,
  ) async {
    final adapter = ScriptedAdapter();
    final lateReply = adapter.defer();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(MaterialApp(home: _PollingProbe(dio)));
    await tester.pump(const Duration(seconds: 1));
    expect(adapter.requests, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(adapter.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    lateReply.complete(ScriptedAdapter.reply(200, {'fixture': true}));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(adapter.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('capture fake permits controlled late stop without native IO', () async {
    final capture = FakeCapture();
    await capture.start();
    final stop = capture.stop();
    capture.dispose();
    capture.stopped.complete(Uint8List.fromList([1, 2, 3]));
    expect(await stop, [1, 2, 3]);
    expect(capture.starts, 1);
    expect(capture.stops, 1);
    await expectLater(capture.start(), throwsStateError);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 20 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    ready(),
    isTrue,
    reason: 'Expected fake operation within 20 virtual frames',
  );
}

/// Harness for exercising fake timing/disposal; no backend contract is implied.
class _PollingProbe extends StatefulWidget {
  const _PollingProbe(this.dio);
  final Dio dio;
  @override
  State<_PollingProbe> createState() => _PollingProbeState();
}

class _PollingProbeState extends State<_PollingProbe> {
  late final Timer _timer;
  bool _busy = false;
  String _label = 'waiting';
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_busy) return;
      _busy = true;
      try {
        await widget.dio.get<Object>('/fixture/status');
        if (mounted) setState(() => _label = 'received');
      } finally {
        _busy = false;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(_label);
}
