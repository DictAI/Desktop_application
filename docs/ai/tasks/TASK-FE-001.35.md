---
id: TASK-FE-001.35
plan: PLAN-FE-001
title: "Покрыть batch-пути unit/widget regression suite"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "4"
depends_on: ["TASK-FE-001.12", "TASK-FE-001.13", "TASK-FE-001.23", "TASK-FE-001.24", "TASK-FE-001.29", "TASK-FE-001.31", "TASK-FE-001.32", "TASK-FE-001.34", "TASK-FE-001.48", "TASK-FE-001.49"]
backend_tasks: ["TASK-002.17"]
api_contracts: ["A01–A03", "W01–W09", "U01–U04", "R01–R05"]
blocked_by: []
scope:
  - "test/journeys/batch_journey_test.dart"
  - "test/journeys/batch_failure_test.dart"
  - "test/journeys/batch_restart_test.dart"
  - "docs/testing/BATCH_MATRIX.ru.md"
  - "docs/ai/tasks/TASK-FE-001.35.md"
planned_paths:
  - "test/journeys/batch_journey_test.dart"
  - "test/journeys/batch_failure_test.dart"
  - "test/journeys/batch_restart_test.dart"
  - "docs/testing/BATCH_MATRIX.ru.md"
delivery_stage: current
---

# TASK-FE-001.35: Покрыть batch-пути unit/widget regression suite

## Goal

Детерминированная пользовательская regression matrix по fake backend/capture/storage.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Нет сквозных проверок state/навигации, existing widget_test пуст.

**Целевое:** Детерминированная пользовательская regression matrix по fake backend/capture/storage.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.12](TASK-FE-001.12.md), [TASK-FE-001.13](TASK-FE-001.13.md), [TASK-FE-001.23](TASK-FE-001.23.md), [TASK-FE-001.24](TASK-FE-001.24.md), [TASK-FE-001.29](TASK-FE-001.29.md), [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.32](TASK-FE-001.32.md), [TASK-FE-001.34](TASK-FE-001.34.md), [TASK-FE-001.48](TASK-FE-001.48.md), [TASK-FE-001.49](TASK-FE-001.49.md).
Backend traceability: TASK-002.17
API: A01–A03, W01–W09, U01–U04, R01–R05.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: regression текущих сценариев с test fixtures действующих API; без demo naming suite.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Journeys текущего реального wire: Stop/leave continue/confirm, pre-Start options, workspace→Record, canonical→transcript, background notice/Results restart, Play/Pause/seek, exports/delete/logout.
- [ ] Все Speaker labels остаются backend labels; в видимом UI отсутствуют rename/contact assignment/save/Skip и runtime mock бизнес-данных.
- [ ] Изолированные HTTP/hardware fakes допускаются только в tests существующих контрактов; future naming mock/model/draft suite не создаётся.
- [ ] Покрыты lost upload/replay409, offline/backoff429/502/503, terminal202, no_speech, transcript+summary failed, artifact503/document404/incomplete original и owner isolation.
- [ ] NOT RUN native/model/live API не выдаётся за PASS тестов; CI/golden redesign не входят.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| `flutter test test/journeys/batch_journey_test.dart test/journeys/batch_failure_test.dart test/journeys/batch_restart_test.dart` | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
