import 'package:dict_ai/app.dart';
import 'package:dict_ai/core/router/app_router.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Real App, router and auth notifier. Only IO boundaries are replaced.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester,
  ScriptedAdapter adapter,
) async {
  resetStorageFakes();
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(const SecureStorage()),
      dioProvider.overrideWithValue(dio),
    ],
  );
  final router = container.read(routerProvider);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    dio.close(force: true);
    resetStorageFakes();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return container;
}
