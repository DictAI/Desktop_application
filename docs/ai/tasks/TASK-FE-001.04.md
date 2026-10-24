---
id: TASK-FE-001.04
plan: PLAN-FE-001
title: "Перевести session storage на защищённое хранилище"
status: draft
owner: unassigned
priority: P0
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01"]
backend_tasks: []
api_contracts: ["§2"]
blocked_by: []
scope:
  - "lib/core/storage/secure_storage.dart"
  - "macos/Runner/DebugProfile.entitlements"
  - "macos/Runner/Release.entitlements"
  - "test/core/storage/secure_storage_test.dart"
  - "test/core/storage/keychain_smoke_app.dart"
  - "docs/ai/tasks/TASK-FE-001.04.md"
planned_paths:
  - "test/core/storage/secure_storage_test.dart"
  - "test/core/storage/keychain_smoke_app.dart"
---

# TASK-FE-001.04: Перевести session storage на защищённое хранилище

## Goal

JWT в OS secure storage с явной миграцией и поведением при отказе; no plaintext fallback.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** SecureStorage хранит JWT и legacy provider key в SharedPreferences, несмотря на объявленный flutter_secure_storage.

**Целевое:** JWT в OS secure storage с явной миграцией и поведением при отказе; no plaintext fallback.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: §2.

Платформенная предпосылка из [F01 независимого review](../reviews/REVIEW-FE-001.01-02.md#L48):
оба существующих файла `macos/Runner/DebugProfile.entitlements` и
`macos/Runner/Release.entitlements` включают App Sandbox, но пока не содержат
`keychain-access-groups`. `macos/Runner.xcodeproj/project.pbxproj` назначает первый
файл Debug/Profile, второй — Release. В текущем `pubspec.lock` зафиксированы
`flutter_secure_storage` 9.2.4 и `flutter_secure_storage_macos` 3.1.3. Раздел
Configure MacOS Version README пакета 9.2.4 требует ключ в обоих entitlements
и показывает пустой массив для стандартной конфигурации. При реализации сверить
setup с lock-версией после .01; изменение зависимостей не входит в .04.
Это описание будущей реализации: текущие entitlements не изменены.

## Acceptance criteria

- [ ] Используется уже объявленный secure storage; JWT удаляется из старых preferences после успешной миграции, ошибки не приводят к тихому plaintext fallback.
- [ ] Read/write/delete/migration повторяемы; account/email не используются как доказательство ownership; legacy provider credentials очищаются/мигрируются по явно описанной политике без включения chat.
- [ ] В обоих entitlements выполнен минимальный Keychain setup по README используемой lock-версии; `keychain-access-groups` согласован между Debug/Profile и Release и с options Dart-клиента. Не выдуманы shared access group, Team ID или App Group; сохранены существующие sandbox/capture/network/file entitlements и их назначения в Xcode.
- [ ] Будущий `test/core/storage/keychain_smoke_app.dart` использует настоящий SecureStorage и платформенный плагин в том же macOS Runner; не требует backend, новых зависимостей или настоящих credentials. Изолированные синтетические данные и их cleanup не затрагивают пользовательский Keychain/preferences; значения в UI/log/evidence не выводятся.
- [ ] Уже в .04 реальный Keychain smoke пройден в Debug и локальном Release: write/read после перезапуска приложения, delete, повторная миграция и сохранение старого значения до успешной записи/проверки чтения. Контролируемая ошибка storage подтверждает явный отказ без plaintext fallback; различать реально воспроизведённый отказ Keychain и тест с fake. Для невозможного сценария записаны NOT RUN/причина; обязательный OS smoke без macOS/подходящей локальной подписи остаётся blocker, не PASS unit tests.
- [ ] .36 повторяет Keychain-проверки в составе итогового приложения после capture-изменений .16; Linux secret-service smoke остаётся в .37. Эти поздние проверки не заменяют начальный macOS smoke .04, unit fakes не доказывают OS security.
- [ ] Сохранены совместимые вызовы существующего SecureStorage либо явно учтены все его consumers; записи/credentials не попадают в journal или logs.
- [ ] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Оба entitlements уже существуют, поэтому входят в scope, но не в planned_paths.
Writer Keychain setup — implementer .04; следующий writer тех же файлов — .16
только для capture, с сохранением Keychain-настройки. Существующая цепочка
.04 → .15 → .16 задаёт порядок; одновременная запись .04/.16 запрещена.
.36 — проверка итогового приложения, не writer entitlements. Дополнительный
depends_on для уже существующего транзитивного порядка не нужен.

Минимальный Keychain setup — единственное разрешённое этой задачей расширение
platform entitlements. Не менять project.pbxproj, bundle ID, signing team,
provisioning profiles, distribution/notarization или другие capabilities.
Smoke entry point — будущий узкий ручной harness, а не integration_test framework
или новая архитектура: реальные plugin/storage вызовы, изолированные тестовые
ключи, cleanup и только безопасные PASS/FAIL-индикаторы. Он не входит в обычный
`*_test.dart` запуск. Если для запуска нужны неподтверждённые signing/host условия,
зафиксировать blocker и передать владельцу, не менять их вне scope.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior сверх описанного Keychain setup
либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/core/storage/secure_storage_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements`; сравнение plist и Xcode CODE_SIGN_ENTITLEMENTS | macOS; после выбранной реализации .04 | Оба plist валидны; минимальный Keychain setup согласован с lock README/options; прежние права и Debug/Profile/Release mapping сохранены | Не запускалось | NOT RUN | Lint/source review не доказывает работу Keychain; Xcode project только для чтения |
| `flutter run -d macos --debug --target test/core/storage/keychain_smoke_app.dart` | Реальный macOS host, SDK после .01, существующая подходящая локальная подпись, изолированные synthetic fixtures | Настоящий плагин: write/read, restart/read, delete, migration/retry и error path; отсутствие plaintext fallback и утечки значений | Не запускалось | NOT RUN | Harness пока planned; нет backend-вызовов. Если реальный отказ не воспроизводим безопасно, записать отдельно NOT RUN; fake failure не объявлять OS evidence |
| `flutter run -d macos --release --target test/core/storage/keychain_smoke_app.dart`; проверка entitlements реально собранного Runner через `codesign -d --entitlements :- <app>` | Тот же macOS host и разрешённая локальная среда; `<app>` — фактический .app из этого запуска | Тот же storage smoke в Release, фактически применённые entitlements проверены для обеих сборок; результаты отдельно по конфигурациям | Не запускалось | NOT RUN | Нельзя заменять Release smoke Debug; отсутствие локальной signing-возможности — blocker, не разрешение менять подпись или выпускать приложение |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
