---
id: TASK-FE-001.42
plan: PLAN-FE-001
title: "Зафиксировать готовность frontend-интеграции к batch-релизу"
status: blocked
owner: unassigned
priority: P0
readiness_category: A
phase: "5"
depends_on: ["TASK-FE-001.40", "TASK-FE-001.41"]
backend_tasks: ["TASK-002.17", "TASK-002.24", "TASK-002.31"]
api_contracts: ["§9"]
blocked_by: ["Backend .17 draft, .24/.31 blocked на исходном срезе; production evidence отсутствует.", "Не завершены .40/.41, platform/security evidence и явная приёмка владельца."]
scope:
  - "docs/release/BATCH_ACCEPTANCE.ru.md"
  - "docs/ai/tasks/TASK-FE-001.42.md"
planned_paths:
  - "docs/release/BATCH_ACCEPTANCE.ru.md"
delivery_stage: current
---

# TASK-FE-001.42: Зафиксировать готовность frontend-интеграции к batch-релизу

## Goal

Зафиксировать готовность текущей работающей версии на существующем backend; будущие имена не условие этой приёмки.

Текущий этап. Реализация после завершения пересмотра и независимого review, в порядке DAG.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Полный CPU E2E/cutover/production evidence backend пока не завершены.

**Целевое:** Зафиксировать готовность текущей работающей версии на существующем backend; будущие имена не условие этой приёмки.

**Категория A.** Текущая verification задача; status blocked связан со стендом/host/security evidence, а не отсутствием будущего API.
FE prerequisites: [TASK-FE-001.40](TASK-FE-001.40.md), [TASK-FE-001.41](TASK-FE-001.41.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.31
API: §9.

### Блокировки и разблокировка

- Backend .17 draft, .24/.31 blocked на исходном срезе; production evidence отсутствует.
- Не завершены .40/.41, platform/security evidence и явная приёмка владельца.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: приёмка текущей версии по real E2E/security/hosts; future naming не release gate.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Текущий сценарий включает реальные login/workspaces/contacts, Stop/leave, WAV202, canonical Speaker N, независимую summary, notices/recovery/player/TXT/PDF/WAV/delete/logout.
- [ ] Все обязательные current tasks/checks/reviews и macOS/Linux evidence завершены; unresolved security/host/runtime/quality findings явно не release-ready.
- [ ] Backend quality/staging/production/cutover и credential rotation подтверждены владельцами; frontend не принимает их по одному accepted имени задачи.
- [ ] Будущие .43/.45/.46/.47/.50/.51 не gate текущей версии; их отсутствие не скрывается, phantom controls/local name replacement отсутствуют.
- [ ] Только владелец принимает результат; эта карточка не выполняет commit/push/merge/release/deployment.
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
