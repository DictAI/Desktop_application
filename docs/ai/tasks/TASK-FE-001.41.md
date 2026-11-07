---
id: TASK-FE-001.41
plan: PLAN-FE-001
title: "Подготовить локальный batch release candidate и инструкцию выпуска"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "5"
depends_on: ["TASK-FE-001.33", "TASK-FE-001.35", "TASK-FE-001.36", "TASK-FE-001.37", "TASK-FE-001.38"]
backend_tasks: ["TASK-002.17", "TASK-002.24", "TASK-002.31"]
api_contracts: ["§9"]
blocked_by: []
scope:
  - "docs/release/BATCH_RELEASE_CHECKLIST.ru.md"
  - "docs/release/CONFIGURATION.example.md"
  - "docs/ai/tasks/TASK-FE-001.41.md"
planned_paths:
  - "docs/release/BATCH_RELEASE_CHECKLIST.ru.md"
  - "docs/release/CONFIGURATION.example.md"
delivery_stage: current
---

# TASK-FE-001.41: Подготовить локальный batch release candidate и инструкцию выпуска

## Goal

Воспроизводимый локальный candidate/checklist без публикации, самовольного version bump или cloud deployment.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Version 1.0.0+1 и платформенные templates есть; release process/конфигурационный checklist не зафиксированы.

**Целевое:** Воспроизводимый локальный candidate/checklist без публикации, самовольного version bump или cloud deployment.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.33](TASK-FE-001.33.md), [TASK-FE-001.35](TASK-FE-001.35.md), [TASK-FE-001.36](TASK-FE-001.36.md), [TASK-FE-001.37](TASK-FE-001.37.md), [TASK-FE-001.38](TASK-FE-001.38.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.31
API: §9.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: candidate/checklist полноценной текущей версии, без mock-only release.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Candidate — полноценная текущая версия с real API, а не mock demo; Speaker N и отсутствие rename честно указаны.
- [ ] SDK/lock/config, host/audio/storage prerequisites и безопасный ввод credentials документированы, без ключей/default HTTP/log bodies.
- [ ] Artifacts/checksums/known limitations проверяемы и вне Git; distribution/signing/notarization/version/release требуют отдельного решения.
- [ ] Наличие candidate не закрывает .39/.40/.42 и не требует будущих assignments/именованного экспорта.
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
