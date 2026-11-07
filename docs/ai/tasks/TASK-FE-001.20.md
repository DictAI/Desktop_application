---
id: TASK-FE-001.20
plan: PLAN-FE-001
title: "Сохранить upload identity и job references для восстановления"
status: review
owner: primary-agent
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.04", "TASK-FE-001.19"]
backend_tasks: ["TASK-002.13", "TASK-002.16", "TASK-002.22", "TASK-002.37"]
api_contracts: ["U01", "U02", "R01", "R03"]
blocked_by: []
scope:
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/record/data/dto/pending_upload.dart"
  - "test/features/record/pending_upload_store_test.dart"
  - "docs/ai/tasks/TASK-FE-001.20.md"
planned_paths:
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/record/data/dto/pending_upload.dart"
  - "test/features/record/pending_upload_store_test.dart"
delivery_stage: current
---

# TASK-FE-001.20: Сохранить upload identity и job references для восстановления

## Goal

Owner-scoped atomic journal: immutable source/options/key до acceptance, job metadata после.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Upload/job state только в RAM, temp paths и один audio_id теряются при restart.

**Целевое:** Owner-scoped atomic journal: immutable source/options/key до acceptance, job metadata после.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.04](TASK-FE-001.04.md), [TASK-FE-001.19](TASK-FE-001.19.md).
Backend traceability: TASK-002.13, TASK-002.16, TASK-002.22, TASK-002.37
API: U01, U02, R01, R03.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: durable upload recovery; убрать assignment drafts и обязательство нового пакета.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] До 202 Results показывает локальную отправку отдельно; после сохранённого 202 восстанавливается polling job. Local ID не объявляется audio/job ID.
- [x] Recovery повторяет те же bytes/options/key; app-owned source фиксируется до HTTP, утрата/изменение запрещают blind retry.
- [x] Journal хранит owner namespace/input identity/accepted IDs, без JWT/password/transcript и без drafts пользовательских имён.
- [x] 409 сохраняется как conflict, deployment revisions не обходятся новым ключом автоматически.
- [x] Schema version/atomic write/corrupt-entry recovery/quota/cleanup относятся только к реальному durable upload; generic storage framework не добавляется.
- [x] Используются существующие SDK/зависимости. Новые packages/SDK updates не являются способом обойти проверку; необходимость отдельного изменения dependency требует отдельного обоснования/разрешения.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

Раздельные local ID и server references, сохранение исходов и ветка poll-only
проверены на уровне журнала. Показ записи в Results и запуск polling относятся
к .25/.27, поэтому первый критерий остаётся открытым.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Исключение для checksum dependency отменено. Pubspec/lock не входят в scope; необходимость нового пакета требует отдельного согласования вне этой карточки, без автоматического изменения dependencies.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

Journal привязан к одному canonical owner UUID и поколению авторизованной
сессии. `isCurrentSession` проверяется перед выдачей данных, вызовом upload и
коммитом pending/accepted/conflict. **.23/.24/.34 должны синхронно отменять
`CancelToken` прежней сессии до публикации нового владельца и JWT.** Каждый
`submit` получает такой токен. Проверка поколения в store защищает локальные
чтения и коммит, а отмена токена нужна для разрыва уже начатого вызова `.19` до
того, как его общий Dio сможет отправить JWT другой сессии. Сквозная проверка
этого порядка относится к интеграции.

Папка `dictai-pending-v1/<owner UUID>` находится в Application Support. Запись
сначала формируется в staging directory. WAV и JSON сбрасываются на диск до
rename каталога. Исход `202` или `409` сохраняется через временный JSON и atomic
rename в том же каталоге. После коммита `202` app-owned WAV доступен для cleanup.
При неудачном коммите исходный pending и его копия остаются для recovery.

В одном isolate очередь владельца сериализует операции разных экземпляров
store, а per-entry guard исключает одновременную отправку. Неблокирующие advisory
locks дополняют защиту между сотрудничающими процессами. Owner lock освобождается
на время HTTP, поэтому Results сможет читать журнал во время отправки. Модель
рассчитана на приложение с одним isolate, который меняет журнал. Advisory locks
и atomic rename не защищают от внешнего вмешательства в файлы, гонки внешнего
писателя после проверки перед POST или отключения питания. SDK flush и rename
не дают здесь гарантии fsync каталога.

Квота по умолчанию составляет 64 записи и 2 GiB сохранённого аудио на владельца.
Один WAV ограничен 1 GiB, JSON envelope ограничен 16 KiB. Повреждённые записи и
неочищенные staging copies учитываются при расчёте места. `prepare` и `cleanup`
очищают оставшиеся staging files и копии уже принятых отправок. Для освобождения
записи после завершения job lifecycle предусмотрен `forgetAccepted`. Pending и
conflict сохраняются без автоматического вытеснения.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 и
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`. Для Flutter test/analyze
использован `PUB_CACHE=/Users/verliiar/.pub-cache`. Авторский test run выполнялся
с `CI=true FLUTTER_SUPPRESS_ANALYTICS=true`. Проверены существующие SDK и lockfile.

| Command / scenario | Expected | Actual / status / граница |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/pending_upload_store_test.dart test/features/record/v2_upload_api_test.dart test/features/record/wav_validator_test.dart --reporter expanded` | Journal, multipart и WAV regressions | PASS, exit 0, 110 tests. Из них 20 для .20 и 90 для .18/.19 |
| Повтор scoped .20 coordinator от 2026-11-04 | Сохранённый diff проходит проверки после возобновления | PASS, 20 tests. Лог `/tmp/dictai-resume-20261103/journal20-resume.log` |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/record/data/pending_upload_store.dart lib/features/record/data/dto/pending_upload.dart test/features/record/pending_upload_store_test.dart` | Анализ трёх Dart-файлов .20 | PASS, No issues found. Coordinator также подтвердил scoped analyze |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed` по тем же трём Dart paths | Проверка финального формата | PASS, 3 files, 0 changed |
| `git diff --check -- docs/ai/tasks/TASK-FE-001.20.md`, `git diff --no-index --check /dev/null <file>` по каждому из трёх новых Dart-файлов, local links и scope | Whitespace/ссылки и выбранные пути | PASS, whitespace diagnostics отсутствуют. Exit 1 у no-index означает новый файл |
| Read-only сверка `services/audio-ingest-service/internal/infrastructure/db/upload_v2.go` | Idempotency учитывает исходные bytes, options и revisions | PASS, source на backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. Сверка исходников, без запросов к backend |
| Независимые `REVIEW-FE-001.20-01` и `REVIEW-FE-001.20-02` | Полный diff и повтор F01 | PASS, новый reviewer `/root/review20_resume` независимо подтвердил исправление F01, 112 tests, analyze/format. Старый partial report сохранён |
| Общий analyze, живой gateway, многопроцессная и power-loss проверка, полный перезапуск приложения, Linux smoke, UI и смена авторизованной сессии через .23/.24/.34 | Проверки уровня приложения и платформы | NOT RUN. Unit tests переоткрывают журнал в новом экземпляре store на том же host и используют реальные небольшие файлы и подменённый HTTP transport |

## Result

2026-11-04. Data scope реализован и передан на review.

- `lib/features/record/data/pending_upload_store.dart` сохраняет отдельный WAV
  и фиксированные options/key до вызова .19. Explicit submit проверяет размер
  и SHA-256 сохранённой копии. При потере ответа остаются исходные bytes/key.
  `409` фиксируется как conflict. Сохранённый `202` возвращает прежний job
  reference для polling, а owned copy удаляется только после записи outcome.
  Исходный файл пользователя остаётся на месте.
- `lib/features/record/data/dto/pending_upload.dart` задаёт versioned entry с
  owner/local ID, options, размером, SHA-256 и отдельным U01/U02 receipt. SHA-256
  в JSON envelope выявляет повреждение метаданных, даже если изменившийся ключ
  всё ещё образует валидный JSON. Смена owner scope исключает доступ к чужим
  записям через методы store.
- `test/features/record/pending_upload_store_test.dart` проверяет оба пути U01/U02,
  точные replay bytes/options/key, same-size mutation, отсутствующий файл,
  symlink, повреждённый JSON, отказ receipt commit, session guards, повторные
  вызовы, квоту и cleanup. Digest fixtures сверены с Python `hashlib.sha256`
  на границах padding и для файла из нескольких блоков чтения.

SHA-256 реализован узко для сравнения WAV и метаданных средствами Dart SDK.
Копирование и хеширование WAV идут в worker isolate блоками до 64 KiB.
Backend отдельно сравнивает SHA-256, поля обработки и deployment revisions.
Хеши журнала служат проверкой целостности, а не аутентификацией файлов или
заменой server idempotency. [FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)

110 связанных тестов, повтор 20 тестов coordinator, scoped analyze и format
прошли. Независимый повторный review .20-02 завершён, открытых findings нет. Приёмка пользователя отсутствует.


## Review delta — 2026-11-05

Primary-agent принимает .20 для узкого исправления F01. Перед публикацией данных
журнала текущая сессия повторно проверяется после всех awaited lock/descriptor
cleanup. Сохранённый HTTP outcome и общая схема остаются прежними.

2026-11-06. Независимый [REVIEW-FE-001.20-02](../reviews/REVIEW-FE-001.20-02.md)
подтвердил F01 как исправленный. 22 journal tests и 90 связанных .18/.19 — PASS.
Final session guard расположен после awaited cleanup, подтверждён двумя регрессиями.
Results/polling UI остаётся в .25/.27, интеграция отмены сессии в .23/.24/.34.
