---
id: TASK-FE-001.32
plan: PLAN-FE-001
title: "Согласовать delete/tombstone и очистку локального состояния"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.27", "TASK-FE-001.28", "TASK-FE-001.31", "TASK-FE-001.48"]
backend_tasks: ["TASK-002.15", "TASK-002.20", "TASK-002.27", "TASK-002.37"]
api_contracts: ["R02", "R03", "U03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "test/features/results/deletion_test.dart"
  - "docs/ai/tasks/TASK-FE-001.32.md"
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
planned_paths:
  - "test/features/results/deletion_test.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
delivery_stage: current
---

# TASK-FE-001.32: Согласовать delete/tombstone и очистку локального состояния

## Goal

Удаление скрывает все версии audio в UI и прекращает polling/локальное восстановление.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Delete из списка существует, но не координирует detail/job/journal и сообщает ошибочный STUB message.

**Целевое:** Удаление скрывает все версии audio в UI и прекращает polling/локальное восстановление.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.48](TASK-FE-001.48.md).
Backend traceability: TASK-002.15, TASK-002.20, TASK-002.27, TASK-002.37
API: R02, R03, U03.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: R02→Results и cleanup реального player/cache/polls; не создавать cleanup несуществующих drafts.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] После подтверждённого R02 — Results; ошибка не имитирует delete/navigation success.
- [ ] Остановлены реальный player/polls, удалены owned cache/jobs/notices; поздние события не воскрешают result. Stores/editors назначений не создаются ради cleanup.
- [ ] Hide/tombstone не выдаётся за cancel/physical destruction; 204/repeat/404/401/500 обработаны.
- [ ] Удаление только owned inventory, не выбранный пользовательский WAV; source cleanup API/profile SQL/backend retention не добавляются.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| `flutter test test/features/results/deletion_test.dart` | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
