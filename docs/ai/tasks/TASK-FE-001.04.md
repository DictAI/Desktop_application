---
id: TASK-FE-001.04
plan: PLAN-FE-001
title: "Перевести session storage на защищённое хранилище"
status: review
owner: primary-agent
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
  - "lib/core/network/auth_interceptor.dart"
  - "test/core/network/storage_interceptor_test.dart"
  - "docs/ai/tasks/TASK-FE-001.04.md"
planned_paths:
  - "test/core/network/storage_interceptor_test.dart"
  - "test/core/storage/secure_storage_test.dart"
  - "test/core/storage/keychain_smoke_app.dart"
delivery_stage: current
---

# TASK-FE-001.04: Перевести session storage на защищённое хранилище

## Goal

JWT в OS secure storage с явной миграцией и поведением при отказе; no plaintext fallback.

Реализация явно выбрана пользователем 2026-10-26 в наборе .03–.07.
Переход внутри набора разрешён после checks/review; вне набора работы не выбираются.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** SecureStorage хранит JWT и legacy provider key в SharedPreferences, несмотря на объявленный flutter_secure_storage.

**Целевое:** JWT в OS secure storage с явной миграцией и поведением при отказе; no plaintext fallback.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: §2.

Историческая платформенная предпосылка до реализации из [F01 независимого review](../reviews/REVIEW-FE-001.01-02.md#L48):
оба существующих файла `macos/Runner/DebugProfile.entitlements` и
`macos/Runner/Release.entitlements` включают App Sandbox, но пока не содержат
`keychain-access-groups`. `macos/Runner.xcodeproj/project.pbxproj` назначает первый
файл Debug/Profile, второй — Release. В текущем `pubspec.lock` зафиксированы
`flutter_secure_storage` 9.2.4 и `flutter_secure_storage_macos` 3.1.3. Раздел
Configure MacOS Version README пакета 9.2.4 требует ключ в обоих entitlements
и показывает пустой массив для стандартной конфигурации. При реализации сверить
setup с lock-версией после .01; изменение зависимостей не входит в .04.
При реализации добавлен минимальный ключ в оба entitlements; прежние capabilities и Xcode mapping сохранены. Работа OS Keychain ещё не подтверждена: см. blocker ниже.

## Scope clarification — 2026-10-26

Обоснованно добавлены AuthInterceptor и regression-test: новый явный AppException
хранилища иначе оставлял async interceptor без handler.next/reject. Исправление
только завершает Dio при отказе read/delete; refresh/routes/auth lifecycle из .09
не реализуются. .09/.34 уже следуют за .04, общий path не получает unordered writers.

## Этап и решение — 2026-11-02

Сохранить OS storage/migration и проверки; runtime smoke завершён 2026-11-03, evidence ниже.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Актуальное evidence перед коррекцией: development identity доступна, вход Xcode восстановлен; Debug/локальный Release native builds созданы, deep/strict Debug signature PASS после clean. Runtime Debug empty phase завершилась timeout 25s; остальные Keychain фазы не подтверждены, Release runtime NOT RUN. Старые причины отсутствия сертификата ниже — исторический evidence. Status blocked сохранён, unit tests не закрывают OS критерий.

## Acceptance criteria

- [x] Используется уже объявленный secure storage; JWT удаляется из старых preferences после успешной миграции, ошибки не приводят к тихому plaintext fallback.
- [x] Read/write/delete/migration повторяемы; account/email не используются как доказательство ownership; legacy provider credentials очищаются/мигрируются по явно описанной политике без включения chat.
- [x] В обоих entitlements выполнен минимальный Keychain setup по README используемой lock-версии; `keychain-access-groups` согласован между Debug/Profile и Release и с options Dart-клиента. Не выдуманы shared access group, Team ID или App Group; сохранены существующие sandbox/capture/network/file entitlements и их назначения в Xcode.
- [x] Будущий `test/core/storage/keychain_smoke_app.dart` использует настоящий SecureStorage и платформенный плагин в том же macOS Runner; не требует backend, новых зависимостей или настоящих credentials. Изолированные синтетические данные и их cleanup не затрагивают пользовательский Keychain/preferences; значения в UI/log/evidence не выводятся.
- [x] Уже в .04 реальный Keychain smoke пройден в Debug и локальном Release: write/read после перезапуска приложения, delete, повторная миграция и сохранение старого значения до успешной записи/проверки чтения. Контролируемая ошибка storage подтверждает явный отказ без plaintext fallback; различать реально воспроизведённый отказ Keychain и тест с fake. Для невозможного сценария записаны NOT RUN/причина; обязательный OS smoke без macOS/подходящей локальной подписи остаётся blocker, не PASS unit tests.
- [x] .36 повторяет Keychain-проверки в составе итогового приложения после capture-изменений .16; Linux secret-service smoke остаётся в .37. Эти поздние проверки не заменяют начальный macOS smoke .04, unit fakes не доказывают OS security.
- [x] Сохранены совместимые вызовы существующего SecureStorage либо явно учтены все его consumers; записи/credentials не попадают в journal или logs.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

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

Cwd — `/Users/verliiar/Desktop_application`, macOS arm64; Flutter 3.41.3/Dart 3.11.1,
переиспользованный SDK `/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`,
PUB_CACHE `/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`.
SDK/dependencies/lock не обновлялись. Данные тестов синтетические.

| Command / scenario | Environment | Actual | Status | Limitation |
|---|---|---|---|---|
| `flutter test --no-pub test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart test/core/network/logging_test.dart` | Указанный SDK, разрешённый localhost test runner; storage fakes | 18 tests passed (12 migration/storage + 2 async-interceptor + 4 logging) | PASS | Не OS Keychain |
| `dart analyze lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart lib/core/config/app_config.dart lib/core/network/api_client.dart lib/shared/providers/providers.dart test/core/storage test/core/config test/core/network` | Тот же SDK, доступ к analyzer cache | No issues found | PASS | Общая проверка изменённых .03–.05 файлов |
| `dart format --output=none --set-exit-if-changed lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart test/core/storage test/core/network/storage_interceptor_test.dart` | Тот же SDK | Формат применён; итоговая повторная проверка — в batch evidence | PASS | Только выбранный scope |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements` | macOS; lock README/options + Xcode mapping source review | Оба plist валидны, добавлен только `keychain-access-groups` с пустым массивом | PASS | Не доказательство runtime security |
| `flutter build macos --debug --no-pub --target test/core/storage/keychain_smoke_app.dart --dart-define=DICTAI_SMOKE_NAMESPACE=dictai.fe04.smoke.debug.20261026 --dart-define=DICTAI_SMOKE_PHASE=write` | Первая попытка sandbox | Xcode services/cache недоступны, workspace error | FAIL | Повторено с разрешённым доступом |
| Та же Debug build-команда с доступом к Xcode/cache | macOS/Xcode, текущая локальная подпись | Runner has entitlements that require signing with a development certificate | FAIL | Конкретный signing blocker; project/team/profile не изменялись |
| Debug/Release write → restart → delete реальным Runner; applied entitlements через codesign; controlled OS failure | Требуется подходящая development signing identity | Приложение не собрано; Keychain вызовы не запускались | NOT RUN | Обязательный blocker, fake failure не OS evidence; Release build не выдаётся за выполненный |
| `flutter analyze --no-pub` | Тот же SDK, полный проект | 13 прежних info prefer_const_constructors, 0 errors/warnings | FAIL | Baseline вне scope, не исправлялся |
| Независимый review | Отдельный агент, только назначенный отчёт | [REVIEW-FE-001.04-02](../reviews/REVIEW-FE-001.04-02.md) reviewed/complete; findings P0–P3 отсутствуют | PASS | B01 OS signing/smoke blocker остаётся open |

## Result

Частично реализовано, **blocked**, не verified/accepted. SecureStorage использует
уже зафиксированный OS plugin и совместимые публичные методы. Три legacy ключа
мигрируют с read-after-write и удалением plaintext только после подтверждения;
старое OS значение приоритетно. Операции сериализованы между экземплярами,
logout чистит обе стороны и не допускает resurrection. Отказы явные и безопасные,
`hasToken` fail-closed, credentials не выводятся. Legacy provider key поддерживается
только для миграции/очистки, chat не включён.

Изменены secure_storage, оба entitlements и узкая обработка storage failure в
AuthInterceptor; добавлены storage/interceptor tests и изолированный native smoke
entry point. Namespace smoke обязателен, фазы write/restart/delete разделены;
он не входит в обычный `*_test.dart` запуск. Изменённый pod install lock восстановлен
байт-в-байт к исходному baseline; зависимости не изменены.

Для снятия blocker нужна согласованная локальная development signing identity,
затем фактические Debug и Release smoke с перезапуском/cleanup и проверкой применённых
entitlements. Подпись, Team ID, bundle ID и profiles не менялись. .36 и Linux .37
сохраняют свои поздние проверки; они не заменяют .04. Остальные выбранные задачи
.03/.05/.06/.07 от .04 не зависят. Commit/push/merge не выполнялись.

Независимый review .04 завершён 2026-10-27; code findings нет. Reviewer отдельно
повторил 14 tests, scoped analyze/format/plist PASS. B01 остаётся open, карточка blocked.


## Завершение native проверки — 2026-11-03

Этот раздел заменяет прежний открытый B01 и исторические signing/timeout причины
выше. Начальная empty timeout устранена в узком harness: запускается пустой Flutter
frame, ожидание preferences ограничено, отказ сообщает только checkpoint без
данных. Production storage, AppDelegate, signing project, dependencies не менялись.
Локальная development identity выбрана владельцем, signing override — игнорируемый
файл окружения. Личные Team/profile не становятся настройкой общего репозитория.

Cwd `/Users/verliiar/Desktop_application`, macOS arm64,
`.dart_tool/codex-tools/flutter` Flutter 3.41.3 / Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.
Версии SDK/зависимостей прежние; SDK-кэш Git ignored, `flutter clean` не используется.

| Команда / сценарий | Actual | Статус и граница |
|---|---|---|
| `flutter build macos --debug --no-pub --target test/core/storage/keychain_smoke_app.dart --dart-define=DICTAI_SMOKE_NAMESPACE=dictai.fe04.smoke.debug.20261102` | Native Debug build создан | PASS, локальная development подпись |
| Та же build с `--release` и namespace `dictai.fe04.smoke.release.20261103` | Native Release build создан, 38.3MB | PASS, не distribution/release публикация |
| `codesign --verify --deep --strict` обоих `.app`; `codesign -d --entitlements :-` | Подписи валидны; Sandbox, application identifier и keychain-access-groups применены в обеих конфигурациях | PASS, проверены фактические bundles |
| Каждый Runner отдельным процессом с `DICTAI_SMOKE_PHASE=empty/write/restart/stale/restart/delete/empty/denied/restart/restart/delete/empty` | 12/12 Debug и 12/12 Release exit0 + PASS marker | PASS, настоящий OS plugin, не fake |
| Native denied: SecItem write в отсутствующую entitlement group | Реальный OSStatus -34018, явный отказ, plaintext fixtures сохранены; последующий отдельный процесс успешно мигрирует | PASS, не блокировка пользовательского Keychain |
| `flutter test --no-pub test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart` | 14 tests passed | PASS, unit regression, не замена OS smoke |
| `dart analyze lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart test/core/storage test/core/network/storage_interceptor_test.dart` | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed` для тех же файлов | 5 files, 0 changed | PASS |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements` | Оба OK | PASS |
| Global `flutter analyze --no-pub` | Последний run: 13 прежних prefer_const_constructors info вне .04, 0 errors/warnings | FAIL baseline, не clean global PASS |
| Повторный независимый review итоговой .04 | [REVIEW-FE-001.04-04](../reviews/REVIEW-FE-001.04-04.md): reviewer самостоятельно повторил 24 native фазы, обе подписи/entitlements, 14 tests/analyze/format/plist | PASS, открытых findings нет |

Runtime результаты повторяемы из harness через указанные build/phase команды;
локальные логи и applied entitlements сохранены вне Git в
`/tmp/dictai-fe04-finish-20261102/`. Все значения синтетические, только namespaced
fixtures; завершающий empty подтверждает cleanup. Три production ключа/записи
пользователя не читались harness-ом. Linux не проверен — остаётся .37.

**Result:** обязательный native B01 снят фактическими Debug/Release evidence.
Статус review, не accepted; независимый финальный проход завершён, B01 closed.
.36 повторит smoke итогового приложения после capture-изменений. Commit/push/merge
не выполнялись. Старые журналы выше оставлены как история, а не текущие blockers.
