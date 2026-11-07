---
id: TASK-FE-001.38
plan: PLAN-FE-001
title: "Подготовить opt-in интеграционный harness и требования к стенду"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "4"
depends_on: ["TASK-FE-001.19", "TASK-FE-001.21", "TASK-FE-001.22", "TASK-FE-001.26", "TASK-FE-001.30", "TASK-FE-001.34", "TASK-FE-001.35"]
backend_tasks: ["TASK-002.14", "TASK-002.15", "TASK-002.16", "TASK-002.17", "TASK-002.22", "TASK-002.24", "TASK-002.28", "TASK-002.30", "TASK-002.37"]
api_contracts: ["§9", "A01–A03", "W01–W09", "U01–U04", "R01–R05"]
blocked_by: []
scope:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/BACKEND_INTEGRATION.ru.md"
  - "docs/ai/tasks/TASK-FE-001.38.md"
planned_paths:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/BACKEND_INTEGRATION.ru.md"
delivery_stage: current
---

# TASK-FE-001.38: Подготовить opt-in интеграционный harness и требования к стенду

## Goal

Harness готов с synthetic fixtures и явным opt-in, без запуска на неподтверждённом endpoint.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Нет тестового gateway config или opt-in интеграционного сценария; наличие IP в providers не даёт разрешения писать в production.

**Целевое:** Harness готов с synthetic fixtures и явным opt-in, без запуска на неподтверждённом endpoint.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.19](TASK-FE-001.19.md), [TASK-FE-001.21](TASK-FE-001.21.md), [TASK-FE-001.22](TASK-FE-001.22.md), [TASK-FE-001.26](TASK-FE-001.26.md), [TASK-FE-001.30](TASK-FE-001.30.md), [TASK-FE-001.34](TASK-FE-001.34.md), [TASK-FE-001.35](TASK-FE-001.35.md).
Backend traceability: TASK-002.14, TASK-002.15, TASK-002.16, TASK-002.17, TASK-002.22, TASK-002.24, TASK-002.28, TASK-002.30, TASK-002.37
API: §9, A01–A03, W01–W09, U01–U04, R01–R05.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: opt-in harness существующих HTTP; не добавлять будущие wire probes/новый test framework.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Opt-in harness проверяет только существующие A/W/U/R API и текущий canonical/Speaker N/export; никаких будущих assignments/named-export probes.
- [ ] Checklist: разрешённые origin/TLS/accounts, V2 gate, models/artifacts/migrations/NATS/mTLS/LLM/Typst/SMTP — конфигурация, не новые frontend API.
- [ ] Network writes только при явных test-origin/credentials/разрешении finite synthetic jobs; default NOT RUN/SKIP не PASS.
- [ ] Exact bytes/status/ownership и cleanup существующим R02, без обещания physical delete; новый integration_test framework не требуется.
- [ ] Functional probes отделены от backend quality/staging/production evidence; секреты и фикстуры реальных записей не сохраняются.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| Предусмотренные scope проверки текущих реальных сценариев/host/стенда | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
