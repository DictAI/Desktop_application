---
id: REVIEW-FE-001.19-01
task_ids: ["TASK-FE-001.19"]
reviewer: /root/results_contracts
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.19-01

## Scope

2026-11-03. Независимый reviewer `/root/results_contracts`. Проверены три новых
файла `lib/features/record/data/v2_upload_api.dart`,
`lib/features/record/data/dto/upload_accepted_dto.dart`,
`test/features/record/v2_upload_api_test.dart` и карточка .19. База frontend
HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c`, текущий рабочий diff. Рецензент
пишет только этот зарезервированный отчёт. Backend read-only, HEAD
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`.

Сверены U01/U02 OpenAPI, V2 routes/handlers, application validation, DB
idempotency/fingerprint и генерация IDs/status URL. Прочитаны .18 preflight/options,
общий gateway/Dio/auth .05, mapper .07 и зависимости .19 в карточке и PLAN.

## Findings

| ID / priority | File | Impact | Evidence | Recommendation | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `lib/features/record/data/v2_upload_api.dart:51` | Локально допустимый ключ может остановить нативную отправку до POST с общей ошибкой некорректного ответа. | `.18 UploadOptions` допускает ключи в UTF-8 по backend validation. Pinned Dio 5.9.2 вызывает `HttpClientRequest.headers.set` напрямую. Dart 3.11.1 `_HttpParser._isValueChar` отклоняет не-ASCII и управляющие значения. Независимый loopback probe подтвердил отказ Latin-1, Cyrillic и управляющего символа до send. ASCII и внутренний TAB получили HTTP 204. | Проверить допустимость native HTTP header в .19 до IO и вернуть безопасную локальную ValidationException. Передаваемый ключ сохранять буквально. Проверить отсутствие POST у отклонённого ключа. | fixed |
| F02 / P2 | `lib/features/record/data/v2_upload_api.dart:50` | Повреждённый UTF-8 в `processing_version` может записаться как принятый job reference с другой версией. | `ResponseType.plain` в установленном FusedTransformer декодирует с `allowMalformed: true`. Независимый probe с текущим DTO и байтом `0xff` внутри JSON поля HTTP 202 подтвердил успешный parse с U+FFFD в версии. Строгий `utf8.decode` отклоняет тот же payload. Backend валидирует UTF-8 версии перед принятием. | Получать response bytes и строго декодировать UTF-8 при 202 перед разбором JSON. Передавать error bytes существующему mapper, который уже их поддерживает. Проверить malformed 202 и сохранение фактических non-2xx статусов. | fixed |

Карточка .19 в строке ожидаемого review на момент начала указывала прежнего
назначенного reviewer. Координатор зарезервировал отчёт для `/root/results_contracts`.
После исправлений карточка указывает фактического reviewer и ссылается на этот отчёт.

## Verification

Самостоятельные проверки в `/Users/verliiar/Desktop_application`, macOS 26.2 arm64,
Flutter 3.41.3 и Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`. Тестовый порт использовался локально.

| Проверка | Результат | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/record/v2_upload_api_test.dart test/features/record/wav_validator_test.dart` | 86 tests passed, exit 0 | PASS. Scripted transport проверяет реальный multipart stream и общий JWT interceptor, но не native header encoder. |
| `flutter analyze --no-pub lib/features/record/data/v2_upload_api.dart lib/features/record/data/dto/upload_accepted_dto.dart test/features/record/v2_upload_api_test.dart` | No issues found | PASS. Scoped Dart. |
| `dart format --output=none --set-exit-if-changed` по тем же трём путям | 3 files, 0 changed | PASS. |
| `git diff --check -- docs/ai/tasks/TASK-FE-001.19.md` и полный new-file diff | Whitespace diagnostics отсутствуют | PASS. |
| Standalone Dart HttpClient/HttpServer loopback probe с синтетическими ключами | ASCII и внутренний TAB отправлены, Latin-1/Cyrillic/control отвергнуты в `headers.set` | PASS воспроизведения F01. Реальный HTTP encoder pinned SDK. |
| Standalone Dart probe с Dio 5.9.2, scripted 202 и текущим UploadAcceptedDto | Plain decode подставил U+FFFD. Strict decode исходных bytes вызвал FormatException | PASS воспроизведения F02. |
| Backend source, card deps и PLAN DAG | U01/U02, JWT policy, фиксированные routes, multipart metadata, accepted fields, error codes сверены | PASS сверки исходников. |
| Live gateway, server idempotent replay, journal/restart, UI, платформенные сборки и capture | Не запускались | NOT RUN. Входят в отдельные задачи. |
| Общий `flutter analyze --no-pub` | Reviewer не повторял. Карточка автора сохраняет FAIL по 13 прежним info вне .19 | NOT RUN reviewer. |

SHA-256 первого прохода.

- `v2_upload_api.dart` `3859e4cbde847ff77421af2cd6aff78e1d220752b0c20cac91123845db80c9a0`
- `upload_accepted_dto.dart` `c0295b696a15ea1f9c1ab22fba162734ba553c358d246d3e9c4f5dcaf7c2d78f`
- `v2_upload_api_test.dart` `b57de560de5203873a4a20f5f4f7b3b79ee69ced0096af59c3ef72f5d0e17d71`

## Delta review

F01 исправлен в `v2_upload_api.dart:30`. Клиент проверяет печатный ASCII и
внутренний TAB до файлового IO. Прямой регрессионный тест проверяет локальную
ValidationException и отсутствие запроса. Допустимый ключ со вставленными TAB
и пробелом сохраняется в заголовке буквально. Backend validation .18 остаётся
самостоятельной проверкой сохранённых options.

F02 исправлен в `v2_upload_api.dart:58` и `v2_upload_api.dart:67`. Dio возвращает
исходные байты. HTTP 202 проходит строгий UTF-8 decode до JSON и DTO. Тесты
подтвердили отказ на исходном примере повреждённого 202, сохранение корректной
Unicode версии и сохранение HTTP 429/Retry-After при повреждённом теле ошибки.

Независимый повтор тестов .19 и .18 прошёл, 90/90. Scoped analyze и format
прошли, whitespace и восемь ссылок карточки проверены. Новых или открытых
findings по рассмотренному diff нет.

SHA-256 проверенного кода после исправлений.

- `v2_upload_api.dart` `c148d046a9b6a95226f6028102a45dd6ce0ecb05e95fcc7683454a2771500855`
- `upload_accepted_dto.dart` `c0295b696a15ea1f9c1ab22fba162734ba553c358d246d3e9c4f5dcaf7c2d78f`
- `v2_upload_api_test.dart` `d622e71b126051fddddf43dd4209fd871225f7f0b688a9796a3e7b8f8b5ea619`

## Strengths and residual risk

Один вызов создаёт один POST. Явный replay заново открывает файл и строит multipart
с тем же ключом и параметрами. Workspace и owner-only paths, session nullability,
UUID и связь status URL с audio подтверждены. Tests покрывают file preflight,
streamed file part, sent-byte progress, Retry-After, cancellation и 401 cleanup.
Результат preflight относится к прочитанной версии файла. Сохранение неизменяемого
source и durable recovery проверяются в .20. Независимый review завершён.
Приёмка остаётся решением владельца.
