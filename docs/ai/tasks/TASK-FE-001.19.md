---
id: TASK-FE-001.19
plan: PLAN-FE-001
title: "Добавить V2 multipart upload client и accepted DTO"
status: review
owner: /root/record_data
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.07", "TASK-FE-001.18"]
backend_tasks: ["TASK-002.16", "TASK-002.22", "TASK-002.37"]
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "lib/features/record/data/v2_upload_api.dart"
  - "lib/features/record/data/dto/upload_accepted_dto.dart"
  - "test/features/record/v2_upload_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.19.md"
planned_paths:
  - "lib/features/record/data/v2_upload_api.dart"
  - "lib/features/record/data/dto/upload_accepted_dto.dart"
  - "test/features/record/v2_upload_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.19: Добавить V2 multipart upload client и accepted DTO

## Goal

Точный V2 client; текущие consumers переключаются в .23/.24, старые клиенты удаляются в .33.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Два legacy клиента возвращают только audio_id либо session/audio, без job/version/status URL.

**Целевое:** Точный V2 client; текущие consumers переключаются в .23/.24, старые клиенты удаляются в .33.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.07](TASK-FE-001.07.md), [TASK-FE-001.18](TASK-FE-001.18.md).
Backend traceability: TASK-002.16, TASK-002.22, TASK-002.37
API: U01, U02.

## Этап и решение — 2026-11-02

Нужна: действующие V2 multipart/202/idempotency; без автоматического reprocess.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Оба POST /ingest/v2/audio/upload[/anonymous] посылают JWT, один сохранённый Idempotency-Key, audio и допустимые multipart поля.
- [x] Парсятся audio_id/job_id/processing_version/status_url и nullable session_id; 202 означает accepted; ни grant_id, ни progress из ответа не выдумываются.
- [x] 409 не порождает новый ключ автоматически; 429 учитывает Retry-After при наличии, 400/502/503/non-JSON и lost response различаются.
- [x] Upload не выполняется повторно из build и не падает из-за общего JSON Content-Type; progress — только sent bytes.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer проверил реализацию и исправления F01/F02. Открытых замечаний нет. [REVIEW-FE-001.19-01](../reviews/REVIEW-FE-001.19-01.md)

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

Data client принимает общий authenticated Dio и immutable `UploadOptions` из .18.
Он выполняет один явный POST за вызов, без scheduler/retry/storage/providers/UI.
Реальные UI consumers переключаются только в .23/.24; отсутствие повторов из
Widget.build проверено здесь как отсутствие UI binding в client, не UI smoke.
Caller выставляет `hasRecoverableUpload=true` только после durable сохранения
тех же bytes/options/key; default false, automatic replay отсутствует.

## Verification

Cwd всех команд — `/Users/verliiar/Desktop_application`. Проверки 2026-11-03,
macOS arm64, подготовленный `.dart_tool/codex-tools/flutter` Flutter 3.41.3 /
Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`, существующий Dio 5.9.2.
Тесты используют настоящий общий Dio/auth interceptor с synthetic storage и
transport adapter, который потребляет реальный multipart stream без сети.
SDK/pins/dependencies/lock-файл не менялись; .01/.02 не переоткрывались.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true .dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/v2_upload_api_test.dart test/features/record/wav_validator_test.dart --reporter expanded` | Установленный SDK/cache, runner с local socket access | Регрессии V2 client/options/preflight после исправлений F01/F02 | 90 tests passed, exit 0. 45 upload и 45 WAV/options | PASS | Synthetic HTTP/OS storage. Fixture 1 MiB проверяет чтение по частям. Backend, capture и ресурсные пределы 1 GiB не проверены |
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/record/data/v2_upload_api.dart lib/features/record/data/dto/upload_accepted_dto.dart test/features/record/v2_upload_api_test.dart` | Тот же SDK/cache | Scoped Dart без diagnostic | No issues found, exit 0 | PASS | Три новых файла .19 |
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub` | Тот же SDK/cache | Сохранена общая диагностика | Exit 1, 13 прежних `prefer_const_constructors` info вне .19 в main_shell.dart (2), audio_ingest_api.dart (4), label_speakers_modal.dart (3), record_screen.dart (4) | FAIL | Общий прогон до исправлений F01/F02. После исправлений повторён scoped analyze |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/record/data/v2_upload_api.dart lib/features/record/data/dto/upload_accepted_dto.dart test/features/record/v2_upload_api_test.dart` | Тот же Dart | Формат новых файлов | 3 files, 0 changed, exit 0 | PASS | Чужие файлы не форматировались |
| `git diff --check -- docs/ai/tasks/TASK-FE-001.18.md docs/ai/tasks/TASK-FE-001.19.md`; `git diff --no-index --check /dev/null <new-file>` для каждого из трёх новых .19 Dart-файлов; полный read/diff и local links | Git/Python, без staging | Scope/whitespace/links согласованы | Whitespace diagnostics нет; все ссылки карточек существуют | PASS | .18 менялась только для фиксации завершённого review по поручению coordinator; no-index exit 1 означает новый файл |
| Read-only сверка U01/U02: application/upload_v2.go, db/upload_v2.go/statusURL, presentation/handler/upload_v2_handler.go, contracts/api/openai.yml | Backend `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` | Wire/202/nullability/errors соответствуют текущему source | Сверены multipart/mixed/key, 202 IDs, relative status URL, 400/409/429/503 | PASS | Статическая сверка, не HTTP/runtime/deployment receipt |
| Real gateway/backend upload, journal/restart, UI Start/Stop/double-submit, macOS/Linux capture/build | Не входит в назначенные data paths | Проверить соответствующими задачами .20/.23/.24 и platform/E2E | Не запускалось | NOT RUN | Нет provider/UI wiring, backend writes или real credentials; transport cancellation не равен server cancel |
| Независимая проверка исправлений [REVIEW-FE-001.19-01](../reviews/REVIEW-FE-001.19-01.md) | Reviewer `/root/results_contracts`, не автор diff | Повторная проверка F01/F02 | Reviewed/complete, оба замечания закрыты. Повторены 90 тестов, scoped analyze и format | PASS | Приёмка пользователя остаётся отдельным решением |

История проверок до финального PASS: первый targeted test/analyze был FAIL по
неподдержанному методу CancelToken и двум test lints; после сверки установленного
Dio исправлено на `isCancelled/cancelError`. Следующий test run: 39 PASS, один FAIL
в equality assertion `MapEntry`; сравнение исправлено по значениям полей. Первый
завершённый прогон дал 86 PASS. После исправлений F01/F02 прошли 90 тестов и scoped
analyze, как указано выше.

## Result

2026-11-03: data scope реализован, status `review`, принятия пользователем нет.
Изменены три новых Dart-файла и эта карточка:

- `lib/features/record/data/v2_upload_api.dart`: общий authenticated Dio, строго
  U01/U02, явный multipart Content-Type с boundary вместо общего JSON, audio/wav
  part с basename и file stream, существующие workspace_id/language/mixed и exact
  Idempotency-Key. Перед POST вызывается actual-byte WAV preflight из .18.
  Один вызов — максимум один POST; fresh FormData создаётся для каждого явно
  вызванного replay, ключ не генерируется и не меняется, 409 не обходится.
- `lib/features/record/data/dto/upload_accepted_dto.dart`: обязательные
  audio_id/job_id/processing_version/status_url и обязательный nullable session_id.
  Source-backed UUID/relative URL проверяются, session mode соответствует endpoint;
  нет выдуманного ready/grant/progress. 202 — только accepted reference.
- `test/features/record/v2_upload_api_test.dart`: 45 tests покрывают оба endpoint,
  общий JWT и JSON override, filename/stream/chunks/byte progress, malformed/null
  DTO, HTTP/non-JSON/ошибочно помеченные JSON bodies, 409/Retry-After/lost response,
  pre/in-flight cancellation и явно выбранный replay с прежним ключом.

F01 исправлен на HTTP границе .19. Ключ с символами вне печатного ASCII и
внутреннего TAB вызывает безопасную локальную ошибку до чтения файла и запроса.
Допустимый ключ отправляется буквально. F02 исправлен чтением исходных bytes и
строгим декодированием UTF-8 только для 202. Общий mapper получает bytes остальных
ответов и сохраняет статус и Retry-After при повреждённом теле. Четыре новых
регрессии проверяют эти сценарии и точность допустимого Unicode в версии обработки.
Timeout/network/security/cancel различимы. Durable replay hint разрешён только
явным caller-флагом после journal; никакого automatic retry/server cancel нет.
Source может измениться после preflight: сохранение/identity/recovery journal .20
и backend validation не заменены этим client. Реальный lost-response recovery,
provider/UI wiring и реальный backend/model E2E не подтверждены synthetic tests.
Scoped checks PASS, full analyze FAIL с 13 прежними info вне scope сохранён.
Независимая проверка исправлений завершена, открытых замечаний нет. Карточка
остаётся в `review`. [REVIEW-FE-001.19-01](../reviews/REVIEW-FE-001.19-01.md)
