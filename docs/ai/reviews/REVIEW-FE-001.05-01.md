---
id: REVIEW-FE-001.05-01
task_ids: ["TASK-FE-001.05"]
reviewer: /root/review_foundation_batch
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.05-01

## Delta review

После первого прохода coordinator заменил test storage fixture .05: убраны
`SecretStore`/`LegacyPreferences`, `_Values` и injection из .04. Использованы
официальные FlutterSecureStorage/SharedPreferences mock APIs с reset в setUp и
tearDown и совместимый `const SecureStorage()`. Скрытая compile-связь теста .05
с новыми интерфейсами .04 удалена, declared dependencies .05 не расширялись.
Reviewer самостоятельно прочитал весь обновлённый test, повторил 21 tests — PASS,
analyze/format изменённого test — PASS. Порядок policy перед storage подтверждён
source review; актуальные tests проверяют отсутствие dispatch/forwarding, счётчик
storage reads после delta не используется и не заявляется test evidence.

## Scope

2026-10-27. Независимый reviewer `/root/review_foundation_batch`, не писавший
реализацию, завершил полный review TASK-FE-001.05. Единственная запись reviewer —
этот заранее зарезервированный отчёт.

Проверены `lib/core/config/app_config.dart`, `lib/core/network/api_client.dart`,
`lib/shared/providers/providers.dart`, `test/core/config/app_config_test.dart`,
`docs/development/ENVIRONMENT.ru.md`, delta `.vscode/launch.json` и
`.vscode/launch.example.json`, delta карточки .05. База — frontend HEAD
`80959cc10eacabf45fbf461dbe596030e4e7277c`, manifest и snapshot `before/` в
`/tmp/dictai-foundation-03-07-20261026/`; результат .03 сопоставлен с предыдущим
независимым проходом этого reviewer. Полный scoped diff и все новые файлы прочитаны.

AGENTS/WORKFLOW, architecture, PLAN-FE-001, актуальный выбор/реестр уже прочитаны;
карточка .05 проверена в текущем состоянии. Dio URI composition pinned 5.9.2,
consumers upload/download и backend API snapshot использованы как контекст.
Для launch delta проверены локальные schema Dart-Code 3.144.0 и Flutter DAP source.
Принятые .01/.02 не переоткрывались: проверен только относящийся к .05 local-HTTP
opt-in и текущая передача публичных defines. .06/.07, settings и backend вне review.

## Findings

Actionable findings P0–P3 в назначенном scope не обнаружены. Открытых findings нет.

Подтверждено по текущему коду:

- AppConfig требует явный origin без embedded credentials/path/query/fragment,
  ограничивает scheme и port, не содержит скрытого fallback адреса. Configuration
  errors имеют фиксированные безопасные сообщения. HTTP loopback доступен только
  при явном opt-in и одновременно `kDebugMode`/debug-policy; release/profile guard
  нельзя обойти параметром `isDebugBuild: true`.
- AppConfig входит в общую provider composition, все существующие backend API
  продолжают получать общий Dio. Origin guard расположен перед AuthInterceptor,
  поэтому при foreign scheme/host/effective port JWT даже не читается из storage.
  Scheme-relative/backslash/userInfo URLs запрещены. Сравнение основано на том же
  `options.uri`, который составляет Dio для отправки запроса.
- Redirects принудительно выключены на каждом request, включая caller override;
  отдельный локальный интеграционный тест использует настоящий HTTP adapter,
  получает JWT первым fixture server и подтверждает отсутствие target requests.
- Connect/ordinary/upload/download timeout classes согласованы с карточкой и
  документацией. Multipart и V2 upload получают 15 минут send/receive;
  bytes/stream/documents/original — длинный receive, status — обычный deadline.
  Auto retries/replay/refresh, CA bypass или прямые storage/model endpoints
  этим изменением не вводятся. Proxy timeout не объявляется преодолённым.
- .03 logging сохранён: default off, compile guard, только numeric local ID,
  method/status; auth headers, URL, payload и raw errors не добавлены в output.
  Config `HTTP_DIAGNOSTICS` передаётся через provider только для debug.
- Launch delta содержит публичный debug local opt-in; инструкция описывает
  обязательный API_BASE_URL, PKI, отсутствие retries и границы будущего streaming.
  Verification честно различает local fixtures, baseline analyzer и real deployment.

## Verification

Самостоятельно reviewer, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Использованы прежние SDK/cache .01: Flutter 3.41.3/Dart 3.11.1,
`/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`,
`PUB_CACHE=/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`.
Повторной проверки или изменения toolchain/dependency pins .01/.02 не было.

| Проверка | Actual | Статус / предел |
|---|---|---|
| `flutter test --no-pub test/core/config/app_config_test.dart test/core/network/logging_test.dart` | 21 tests passed, exit 0, повторено после fixture delta | PASS; 17 config/policy + 4 logging regression, official storage mocks |
| Настоящий loopback redirect test в том же запуске | Origin получил synthetic Bearer, target requests=0 даже при `followRedirects: true` | PASS; два ephemeral локальных сервера, без backend |
| `dart analyze lib/core/config/app_config.dart lib/core/network/api_client.dart lib/shared/providers/providers.dart test/core/config/app_config_test.dart` | No issues found, exit 0 | PASS; selected scope |
| `dart format --output=none --set-exit-if-changed lib/core/config/app_config.dart lib/core/network/api_client.dart lib/shared/providers/providers.dart test/core/config/app_config_test.dart` | 4 files, 0 changed | PASS |
| Delta: `dart analyze test/core/config/app_config_test.dart`; `dart format --output=none --set-exit-if-changed test/core/config/app_config_test.dart` | No issues found; 1 file, 0 changed | PASS после замены fixture; остальные .05 source не менялись |
| Scoped tracked `git diff --check` и new-file no-index whitespace | Diagnostics нет | PASS |
| Полные source/test/docs delta, JSON parse обоих launch, local links карточки | Оба JSON валидны; все 9 links разрешаются после создания отчёта | PASS |
| Global `flutter analyze --no-pub` | По evidence автора 13 прежних info, 0 errors/warnings | FAIL baseline; reviewer не повторял |
| Live gateway/TLS/private CA, Linux/macOS application builds | Не запускались | NOT RUN; local redirect fixture не deployment evidence |

## Strengths and residual risk

Проверки сочетают чистую валидацию конфигурации, fake HTTP/official storage mocks
с assertion «не отправлять запрос» и настоящий loopback redirect regression. Policy повторно
применяет ограничения к каждому запросу и сохраняет существующий auth pipeline.

Release-deny тест моделирует выключенную debug-policy в debug runner; compile-time
guard дополнительно проверен по source, native release build не выполнялся.
Timeout assertions подтверждают конфигурацию, не скорость большого upload/download
и не готовность proxy/gateway. Внешняя PKI и deployment остаются непроверенными;
Keychain signing blocker .04 и прежний global analyze baseline этим review
не снимаются. Отсутствие URL означает явный config error при создании клиента,
пользовательский экран настройки окружения не входит в .05.

Review завершён для текущего diff; он не устанавливает accepted. Реализацию,
карточки и план reviewer не менял; commit/push/merge/release не выполнялись.
