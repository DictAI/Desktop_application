---
id: TASK-FE-001.25
plan: PLAN-FE-001
title: "Организовать lifecycle polling и восстановление accepted jobs"
status: review
owner: primary-agent
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.09", "TASK-FE-001.14", "TASK-FE-001.20", "TASK-FE-001.21", "TASK-FE-001.22"]
backend_tasks: ["TASK-002.13", "TASK-002.15", "TASK-002.16", "TASK-002.22"]
api_contracts: ["R01", "R03", "R04", "U03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/processing_recovery_test.dart"
  - "docs/ai/tasks/TASK-FE-001.25.md"
  - "lib/features/results/data/speech_status_api.dart"
  - "lib/features/results/data/canonical_api.dart"
planned_paths:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "test/features/results/processing_recovery_test.dart"
delivery_stage: current
---

# TASK-FE-001.25: Организовать lifecycle polling и восстановление accepted jobs

## Goal

Один bounded in-flight poll на job с generation fencing/backoff и owner-scoped restart recovery.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Periodic timers anonymous/results могут перекрываться, теряют filters и не сохраняют job identity; failed иногда не останавливает ожидание.

**Целевое:** Один bounded in-flight poll на job с generation fencing/backoff и owner-scoped restart recovery.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.14](TASK-FE-001.14.md), [TASK-FE-001.20](TASK-FE-001.20.md), [TASK-FE-001.21](TASK-FE-001.21.md), [TASK-FE-001.22](TASK-FE-001.22.md).
Backend traceability: TASK-002.13, TASK-002.15, TASK-002.16, TASK-002.22
API: R01, R03, R04, U03.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: реальное polling/restart, canonical и summary независимо; без editor intent.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] После transcript ready tracker получает R04 нужного audio/job/session generation; canonical-ready не ждёт summary.
- [x] Навигация не вызывается из poll/build. .48 показывает transcript/notice по текущему контексту; assignment/Skip/editor events отсутствуют.
- [x] Poll не перекрывается; failed/cancelled/expired/deleted завершают ожидание, summary pending имеет независимый lifecycle.
- [x] Restart accepted job восстанавливается по journal/R01(job_id), без повторного upload; чужие/deleted jobs не воскрешаются.
- [x] Offline/429/502/503 имеют bounded backoff; late reply/logout/dispose/401 изолированы. Нет фиктивного progress/stage/ETA или reprocess/cancel.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Уточнение scope 2026-11-06: двум существующим read-клиентам .21/.22 нужен
необязательный Dio CancelToken для прекращения polling при dispose/смене сессии.
Изменение совместимо с прежними callers и не меняет HTTP-контракт. Без него можно
отбросить late reply, но нельзя отменить ожидающий HTTP read. Проверки проходят
через существующие client tests и новый processing_recovery_test. Оба API-файла
пишет implementer .25 после завершённых независимых .21/.22, параллельных writers нет.

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

2026-11-06, cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter
3.41.3 / Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`, `--no-pub`.

| Command / scenario | Actual | Status / limitation |
|---|---|---|
| `flutter test --no-pub test/features/results/processing_recovery_test.dart test/features/results/speech_status_api_test.dart test/features/results/canonical_api_test.dart --reporter expanded` | 113 tests, exit 0, из них 29 новых lifecycle/recovery | PASS, финальный независимый .25-02 |
| `flutter analyze --no-pub` по пяти production Dart paths карточки и новому test | No issues found | PASS scoped |
| `dart format --output=none --set-exit-if-changed` по шести Dart paths | 6 files, 0 changed | PASS |
| Initial test/analyze | Fixture обычной отправки не содержала workspace_id, braces/const lint в новом scope | FAIL → исправлено, финальный полный test run PASS |
| New files + tracked diff/whitespace/local links | Paths конкретны, deleted voice API не воссоздан | PASS |
| Независимый REVIEW-FE-001.25-01 | /root/review_snapshot_platform, не автор | PASS, .25-02 reviewed/complete |
| Real gateway/restart приложения и сквозной UI logout | Не запускались | NOT RUN, .23/.24/.27/.34/.36–.40 |

## Result

Реализованы session-bound ProcessingNotifier, PendingJobStore и общие providers.
Journal .20 остаётся единственным durable хранилищем acceptance receipt. При restart
из него восстанавливаются точные audio/job/version/session references. Текущая R01
page может дополнять recovery через `restore(results: ...)`, её job_id фиксируется,
processing version уточняется первым R03. Отсутствие записи на странице не означает
удаление. Непринятые local drafts не запускают HTTP processing reads и не POSTятся.

На job выполняется один read cycle, одновременно до четырёх jobs. Следующий timer
запускается только после завершения. R03 и optional U03 проверяют identity/version,
R04 дополнительно canonical owner. Только валидный canonical даёт ready. Summary
pending опрашивается независимо, summary failed не закрывает доступный transcript.
202, failed/cancelled/expired, unknown и artifact unavailable различаются.
Для offline/429/502/503 предусмотрен bounded backoff, manual refresh — только GET.
404 останавливает ожидание и сохраняет receipt, не объявляя удаление подтверждённым.

CancelToken передан существующим R03/U03/R04-клиентам без изменения wire.
`stopSession()` синхронно отменяет timers/requests и очищает state. Late replies,
removed audio и прежнее поколение не публикуют данные. Подтверждённое R02 удаление
позволяет подавить все jobs audio и очистить только accepted receipts, не pending WAV.
Provider dispose тоже отменяет чтения. Навигации, editor/names, fake progress/ETA,
reprocess/cancel endpoint и второй persistence слой нет.

Caller .23/.24/.27 обязан держать один ProcessingSession на логическую сессию,
передавать текущую owner/generation guard и вызвать stopSession до публикации нового
аккаунта/JWT. Сквозной session cleanup проверяет .34. Эта задача добавляет tracker,
не заявляет готовность ещё не подключённых экранов, платформ или deployment.
Приёмка пользователя остаётся отдельной.

Уточнение по backend TTL 2026-11-06: U03 истекает независимо от j.state,
а owner-authorized R03/R04 не требуют живой anonymous session. Поэтому tracker
сначала проверяет R03 и готовый canonical, U03 использует только для ещё pending
результата. Expired не блокирует уже доступный transcript при restart с receipt/R01.
Две дополнительные регрессии подтверждают это и отсутствие ложной ready по U03.
Истечение TTL original audio обрабатывается отдельно по реальному U04 outcome.

2026-11-07. Независимый [REVIEW-FE-001.25-02](../reviews/REVIEW-FE-001.25-02.md)
завершён. Поздний 401 старой credential оставляет обновлённую сессию доступной
для ручного GET. 403/404 после ready очищают canonical/status в памяти,
сохраняя durable receipt. Временный 503 сохраняет доступный ранее текст и
применяет backoff. Все три ветки и stale 401 проверены. Открытых findings нет.
