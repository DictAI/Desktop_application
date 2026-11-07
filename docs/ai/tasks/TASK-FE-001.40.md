---
id: TASK-FE-001.40
plan: PLAN-FE-001
title: "Выполнить реальную batch-интеграцию на подготовленном стенде"
status: blocked
owner: unassigned
priority: P1
readiness_category: A
phase: "5"
depends_on: ["TASK-FE-001.36", "TASK-FE-001.37", "TASK-FE-001.39"]
backend_tasks: ["TASK-002.17", "TASK-002.24", "TASK-002.30", "TASK-002.37"]
api_contracts: ["A01–A03", "W01–W09", "U01–U04", "R01–R05"]
blocked_by: ["Ожидаются backend .17 acceptance и подготовленный staging/операционный scope .24.", "Нужны test deployment из .39, разрешённые данные и доступные macOS/Linux hosts; при отсутствии любого evidence NOT RUN."]
scope:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/REAL_BATCH_E2E.ru.md"
  - "docs/ai/tasks/TASK-FE-001.40.md"
planned_paths:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/REAL_BATCH_E2E.ru.md"
delivery_stage: current
---

# TASK-FE-001.40: Выполнить реальную batch-интеграцию на подготовленном стенде

## Goal

Проверить полноценный текущий batch-сценарий на разрешённом реальном backend без будущих назначений.

Текущий этап. Реализация после завершения пересмотра и независимого review, в порядке DAG.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Mock/unit tests и принятый service code не доказывают полный model flow.

**Целевое:** Проверить полноценный текущий batch-сценарий на разрешённом реальном backend без будущих назначений.

**Категория A.** Текущая verification задача; status blocked связан со стендом/host/security evidence, а не отсутствием будущего API.
FE prerequisites: [TASK-FE-001.36](TASK-FE-001.36.md), [TASK-FE-001.37](TASK-FE-001.37.md), [TASK-FE-001.39](TASK-FE-001.39.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.30, TASK-002.37
API: A01–A03, W01–W09, U01–U04, R01–R05.

### Блокировки и разблокировка

- Ожидаются backend .17 acceptance и подготовленный staging/операционный scope .24.
- Нужны test deployment из .39, разрешённые данные и доступные macOS/Linux hosts; при отсутствии любого evidence NOT RUN.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: real E2E текущего сценария; убрать .50/.51 prerequisites и проверки назначений.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] На разрешённом реальном стенде пройдены login→workspace/anonymous→WAV/upload202→poll/restart→canonical Speaker N→независимая summary/documents→player/export→delete/logout.
- [ ] Stop/leave, options до Start, workspace shortcut, background notice без forced redirect и Results recovery подтверждены реальным outcome.
- [ ] Idempotency/lost response/409, owner isolation/no_speech/partial success/invalid WAV/original integrity проверены без public reprocess/cancel API.
- [ ] Actual FE/BE SHA/OS/config, quality .17 и staging .24 evidence записаны; непройденные пункты не подменяются fixtures/backend fixes.
- [ ] .43/.45/.46/.47/.50/.51 и будущие имена не prerequisite этого E2E. После их реализации будут отдельные future проверки.
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
