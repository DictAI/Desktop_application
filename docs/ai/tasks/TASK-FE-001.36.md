---
id: TASK-FE-001.36
plan: PLAN-FE-001
title: "Проверить macOS Debug/Release, permissions, capture и файлы"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "4"
depends_on: ["TASK-FE-001.16", "TASK-FE-001.33", "TASK-FE-001.35"]
backend_tasks: ["TASK-002.08", "TASK-002.16", "TASK-002.28"]
api_contracts: ["U01", "U02", "U04", "R05"]
blocked_by: []
scope:
  - "docs/testing/MACOS_BATCH_VERIFICATION.ru.md"
  - "macos/RunnerTests/RunnerTests.swift"
  - "docs/ai/tasks/TASK-FE-001.36.md"
planned_paths:
  - "docs/testing/MACOS_BATCH_VERIFICATION.ru.md"
delivery_stage: current
---

# TASK-FE-001.36: Проверить macOS Debug/Release, permissions, capture и файлы

## Goal

Повторяемый macOS smoke и evidence реальных WAV/Keychain/save/open lifecycles.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Есть native implementation/entitlements, но реальные permissions/capture/release не подтверждены текущим аудитом.

**Целевое:** Повторяемый macOS smoke и evidence реальных WAV/Keychain/save/open lifecycles.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.16](TASK-FE-001.16.md), [TASK-FE-001.33](TASK-FE-001.33.md), [TASK-FE-001.35](TASK-FE-001.35.md).
Backend traceability: TASK-002.08, TASK-002.16, TASK-002.28
API: U01, U02, U04, R05.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: реальные macOS Debug/Release/capture/player; naming smoke не обязательство текущего этапа.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] На настоящем macOS Debug/локальном Release проверены Stop/leave, оба capture flow, Play/Pause/seek, файлы/cache и готовность transcript без обязательства назначения имён.
- [ ] Mic/system allow/deny, final WAV/лимиты/long-capture bounded memory проверяются на synthetic/consented input, не разговорах посторонних.
- [ ] Keychain migration/failure и sandbox save/open проверены; локальный signed build не разрешает публикацию/нотариацию.
- [ ] Недоступные host/permissions дают NOT RUN/blocked; fake test не platform evidence, naming smoke не создаётся.
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
