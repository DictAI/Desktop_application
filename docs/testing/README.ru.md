# Проверки frontend без внешних сервисов

Из корня репозитория с SDK, совместимым с pubspec.yaml/lock:

```sh
flutter test --no-pub test/widget_test.dart
flutter test --no-pub test/core
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed test/widget_test.dart test/support
```

`--no-pub` предполагает подготовленные зависимости. Используйте существующий lock,
не обновляйте packages/SDK для обхода ошибки. У sandbox runner может отсутствовать
разрешение localhost socket; это ограничение окружения, не PASS теста.

[test_app.dart](../../test/support/test_app.dart) запускает настоящий App, GoRouter
и AuthNotifier. Riverpod overrides заменяют только `dioProvider` и
`secureStorageProvider`. Официальные `FlutterSecureStorage.setMockInitialValues`
и `SharedPreferences.setMockInitialValues` сбрасывают in-memory plugin state до
и после сценария; настоящие preferences/Keychain не открываются. Используется
совместимый публичный SecureStorage без зависимости тестовой основы от его
новых внутренних migration interfaces. Для проверки storage failure используйте
узкие fakes из [storage tests](../../test/core/storage/secure_storage_test.dart).

[fakes.dart](../../test/support/fakes.dart) содержит ScriptedAdapter: запросы
получают только заранее заданные JSON/text/bytes/status responses. Пустая очередь
и обращение после close завершаются ошибкой; реальная сеть не используется.
`defer()` возвращает Completer для точного выбора момента ответа. Закрытие adapter
не стирает уже выданные ответы: это позволяет воспроизводить late completion;
оно не имитирует гарантированную отмену HTTP. Запросы хранятся только в памяти
теста, не печатайте credentials из них. Все fixtures — синтетические.

FakeCapture — тестовая управляемая граница start/stop/dispose с синтетическими
байтами. Она не подключает существующий RecordNotifier к оборудованию и не
утверждает контракт будущего capture service. Его интеграция и platform tests
принадлежат задачам .15–.17. Пока app smoke остаётся на unauthenticated routes,
чтобы не запускать текущий RecordNotifier, устройство, plugin capture или процессы.

WidgetTester.pump(Duration) управляет виртуальным временем Timer; задержанный
polling/ответ после dispose показаны в [widget_test.dart](../../test/widget_test.dart).
Не используйте реальные sleep и pumpAndSettle при бесконечном polling/loading.
Router и ProviderContainer освобождаются после unmount; Dio закрывается. Новых
test dependencies нет. Не используйте реальные ключи, аудиозаписи или домашние
пути; fixture.invalid и /fixture/* — только тестовые адреса, не новые API.

Эти тесты проверяют изоляцию и текущие app/auth boundaries. Они не доказывают
полноту auth lifecycle (.09), DTO клиентов, запись звука, polling продукта,
работу backend, OS Keychain или Linux Secret Service. Native smoke .04 отдельно
описан в [карточке](../ai/tasks/TASK-FE-001.04.md) и может оставаться заблокированным
подписью даже при зелёных unit/widget tests. Различайте baseline analyze findings
в неизменённых файлах и новые ошибки изменённого scope; фиксируйте оба результата.
