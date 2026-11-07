---
id: TASK-FE-001.39
plan: PLAN-FE-001
title: "Подтвердить тестовый backend и закрыть контрактные вопросы доступа"
status: blocked
owner: unassigned
priority: P0
readiness_category: A
phase: "5"
depends_on: ["TASK-FE-001.38"]
backend_tasks: ["TASK-002.16", "TASK-002.24", "TASK-002.28", "TASK-002.37"]
api_contracts: ["§9", "W03", "W06", "U05", "U06"]
blocked_by: ["Нет согласованного test-origin/operator env/accounts и подтверждения runtime prerequisites.", "Не урегулированы workspace access/security вопросы; нет отдельной backend задачи, которая автоматически обещает их исправить."]
scope:
  - "docs/testing/BACKEND_CONTRACT_GATE.ru.md"
  - "docs/ai/tasks/TASK-FE-001.39.md"
planned_paths:
  - "docs/testing/BACKEND_CONTRACT_GATE.ru.md"
delivery_stage: current
---

# TASK-FE-001.39: Подтвердить тестовый backend и закрыть контрактные вопросы доступа

## Goal

Принятое описание тестового окружения, актуального SHA и границ первого batch API без самовольных backend fixes.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Base URL/TLS/PKI/model runtime и правила workspace доступа не подтверждены; grant discovery отсутствует.

**Целевое:** Принятое описание тестового окружения, актуального SHA и границ первого batch API без самовольных backend fixes.

**Категория A.** Текущая verification задача; status blocked связан со стендом/host/security evidence, а не отсутствием будущего API.
FE prerequisites: [TASK-FE-001.38](TASK-FE-001.38.md).
Backend traceability: TASK-002.16, TASK-002.24, TASK-002.28, TASK-002.37
API: §9, W03, W06, U05, U06.

### Блокировки и разблокировка

- Нет согласованного test-origin/operator env/accounts и подтверждения runtime prerequisites.
- Не урегулированы workspace access/security вопросы; нет отдельной backend задачи, которая автоматически обещает их исправить.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Текущий внешний gate: test-origin/accounts/PKI/runtime/access, а не отсутствие будущего names API.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Есть разрешённый isolated test-origin/accounts/PKI/operator и evidence существующих runtime prerequisites; секреты вне Git.
- [ ] Действующие routes/DTO/actual SHA и workspace access/security semantics сверены; реальные ограничения зафиксированы, backend не исправляется frontend-ом.
- [ ] Read/save назначения и именованные документы не требуются для текущего contract gate; их готовность отдельно в future .43/.50/.51.
- [ ] Grant discovery/cancel/live/spec-only meetings не добавляются в текущий scope. Backend quality/staging evidence не выдумывается.
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
