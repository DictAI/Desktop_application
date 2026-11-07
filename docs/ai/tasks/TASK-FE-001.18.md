---
id: TASK-FE-001.18
plan: PLAN-FE-001
title: "Проверять WAV/лимиты и формировать upload options"
status: review
owner: /root/record_data
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.06", "TASK-FE-001.07"]
backend_tasks: ["TASK-002.02", "TASK-002.08", "TASK-002.16"]
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "lib/features/record/data/wav_validator.dart"
  - "lib/features/record/data/dto/upload_options.dart"
  - "test/features/record/wav_validator_test.dart"
  - "docs/ai/tasks/TASK-FE-001.18.md"
planned_paths:
  - "lib/features/record/data/wav_validator.dart"
  - "lib/features/record/data/dto/upload_options.dart"
  - "test/features/record/wav_validator_test.dart"
delivery_stage: current
---

# TASK-FE-001.18: Проверять WAV/лимиты и формировать upload options

## Goal

Bounded preflight и typed options без выдуманных расширений backend.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Picker допускает любое audio, локального byte/duration/format gate нет.

**Целевое:** Bounded preflight и typed options без выдуманных расширений backend.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.02, TASK-002.08, TASK-002.16
API: U01, U02.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Это окончательное решение, заменяющее прежнюю неопределённость момента выбора параметров. Wire language/mixed не меняется.

## Этап и решение — 2026-11-02

Нужна: WAV preflight и immutable options по U01/U02.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Исторически работа остановлена на коррекцию плана с двумя непроверенными файлами.
После независимого review коррекции и явного продолжения current-плана завершён
data scope этой карточки; actual evidence ниже от 2026-11-03. UI binding в .23/.24
ещё не реализован и этими unit-проверками не подтверждается.

## Acceptance criteria

- [ ] Workspace/без workspace, mic/system и language/mixed проверены и snapshot options выбран до Start; активная запись не меняет параметры отправки. Для выбранного WAV параметры валидируются до upload.
- [x] Проверяются RIFF fmt/data, PCM/float bit depths, 8–192 kHz, 1–8 channels, >0 duration, ≤7200 s и ≤1,073,741,824 bytes; MIME/extension недостаточны.
- [x] Чтение header/chunks не загружает 1 GiB в RAM; boundary tests используют управляемые tiny fixtures/limits без ложного real-scale evidence.
- [x] ru/en/auto и mixed=true с пустым language; workspace обязателен только ordinary, idempotency input фиксируется.
- [ ] Пользователь видит требования к WAV; автоматическое универсальное MP3/M4A transcoding не добавляется.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и ограничения зафиксированы в [REVIEW-FE-001.18-01](../reviews/REVIEW-FE-001.18-01.md). Actionable findings нет; `accepted` не выставлен.

Открытые cross-task критерии: immutable data snapshot, локальные mic/system/import
параметры и безопасный текст `WavValidator.requirements` уже есть и проверены.
Выбор/блокировка UI до Start, вызов preflight перед HTTP и показ требований
пользователю принадлежат .23/.24; эта карточка их не закрывает unit-тестом модели.
Независимый review завершён, приёмка пользователя отсутствует.

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

## Verification

Cwd всех команд — `/Users/verliiar/Desktop_application`. Среда: macOS arm64,
подготовленный `.dart_tool/codex-tools/flutter` Flutter 3.41.3 / Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache`; зависимости/lock/SDK pins не менялись.
Проверки выполнялись 2026-11-03, без backend HTTP-запросов.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/wav_validator_test.dart` | Подготовленный SDK; runner с доступом к local socket/cache | WAV metadata/границы/options/errors проверены | 45 tests passed, exit 0 | PASS | Маленький реальный файл и sparse source fixtures; не физический 1 GiB/2-hour capture и не upload/E2E |
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/record/data/wav_validator.dart lib/features/record/data/dto/upload_options.dart test/features/record/wav_validator_test.dart` | Тот же SDK/cache | Нет diagnostic в .18 Dart scope | No issues found, exit 0 | PASS | Только три новых Dart-файла |
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub` | Тот же SDK/cache | Общая диагностика сохранена явно | Exit 1: 13 `prefer_const_constructors` info вне .18: main_shell.dart (2), прежний audio_ingest_api.dart (4), label_speakers_modal.dart (3), record_screen.dart (4) | FAIL | Посторонние файлы не исправлялись; глобальный PASS не заявляется |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/record/data/wav_validator.dart lib/features/record/data/dto/upload_options.dart test/features/record/wav_validator_test.dart` | Тот же Dart | Формат трёх новых файлов | 3 files, 0 changed, exit 0 | PASS | Не форматировались чужие файлы |
| `git diff --check -- docs/ai/tasks/TASK-FE-001.18.md`; `git diff --no-index --check /dev/null <new-file>` для каждого из трёх новых Dart-файлов; полный read/diff scope | Git, без staging | Scope и whitespace без diagnostics | Нет whitespace diagnostics; untracked проверены отдельно | PASS | No-index exit 1 для нового файла означает diff, не whitespace failure |
| Source comparison: backend `upload_wav.go`, `upload_v2.go`, application `upload_v2.go`; `git -C /Users/verliiar/phiziks_pr rev-parse HEAD` | Backend read-only | Текущий WAV/options контракт совпадает со snapshot | HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; ограничения сверены | PASS | Статическая сверка, не runtime test/deployment receipt |
| Start/Stop/upload UI, показ WAV requirements, mic/system capture, Linux/macOS platform build/smoke | UI/capture не входят в назначенные data paths | Проверить при интеграции .23/.24 и capture tasks | Не запускалось | NOT RUN | Этот diff не меняет UI/platform/permissions; data tests не заменяют реальные capture/HTTP проверки |
| Независимый [REVIEW-FE-001.18-01](../reviews/REVIEW-FE-001.18-01.md) | Reviewer `/root/review_workspace_contracts`, не автор .18 | Проверены code/tests/card, findings сохранены | Reviewed/complete; повторены 45 tests/targeted analyze/format, actionable findings нет | PASS | UI Start/requirements/preflight binding остаются cross-task .23/.24; review не accepted |

## Result

2026-11-03, data scope реализован и передан на независимый review, `accepted`
не выставлен. Изменены только три новых Dart-файла и эта карточка:

- `lib/features/record/data/wav_validator.dart`: actual-byte RIFF/WAVE preflight,
  один fmt/data, padding/chunk bounds, PCM/IEEE-float, byteRate/blockAlign/frames,
  положительная duration, точные 1 GiB/7200 s gates. `RandomAccessFile` закрывается
  через finally; parser читает по 12/8/16 bytes и пропускает payload по offsets.
  `WavSource` — узкая seekable IO-граница для этого parser и deterministic tests,
  не runtime business mock. OS paths/details не возвращаются в сообщениях UI.
- `lib/features/record/data/dto/upload_options.dart`: immutable workspace/owner-only,
  ru/en/auto/mixed, exact idempotency key и local mic/system/import snapshot.
  Дополнительного wire нет: только workspace_id/language/mixed, key отдельно
  для будущего HTTP header. Workspace принимает canonical UUID из server DTO,
  uppercase нормализуется; key считается по UTF-8 bytes (1–128), не обрезается.
- `test/features/record/wav_validator_test.dart`: 45 meaningful cases, включая
  malformed RIFF/chunks/formats/metadata, допустимые PCM/float boundary values,
  safe errors, frozen inputs, Unicode whitespace и UTF-8 key boundaries.
  Виртуальные 1 GiB/7200 s fixtures хранят 44/52 header bytes и измеряют bounded
  чтения; они не доказывают реальные RAM/disk/capture на таком объёме.

Targeted test/analyze/format и whitespace PASS. Общий analyze FAIL по 13 info вне
scope; они не скрыты и не исправлены. Независимый [review](../reviews/REVIEW-FE-001.18-01.md)
завершён без actionable findings; его ограничения сохранены. UI Start,
показ WAV требований и вызов preflight/upload остаются .23/.24; API upload .19
не начинался. Файл может измениться после preflight, поэтому этот результат не
заменяет проверку/фиксацию source identity journal и backend validation.
Новых dependencies/platform permissions/backend writes/commit/push/merge нет.
Основание приёмки отсутствует; review не означает accepted.
