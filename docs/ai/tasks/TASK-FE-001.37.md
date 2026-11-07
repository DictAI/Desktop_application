---
id: TASK-FE-001.37
plan: PLAN-FE-001
title: "Проверить Linux build, аудио prerequisites и export"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "4"
depends_on: ["TASK-FE-001.17", "TASK-FE-001.33", "TASK-FE-001.35"]
backend_tasks: ["TASK-002.08", "TASK-002.16", "TASK-002.28"]
api_contracts: ["U01", "U02", "U04", "R05"]
blocked_by: []
scope:
  - "docs/testing/LINUX_BATCH_VERIFICATION.ru.md"
  - "docs/ai/tasks/TASK-FE-001.37.md"
planned_paths:
  - "docs/testing/LINUX_BATCH_VERIFICATION.ru.md"
delivery_stage: current
---

# TASK-FE-001.37: Проверить Linux build, аудио prerequisites и export

## Goal

Evidence Linux release bundle, mic/monitor capture, missing dependencies и desktop storage/export.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Linux CMake/GTK и CLI audio paths есть; macOS хост не доказывает Linux behavior.

**Целевое:** Evidence Linux release bundle, mic/monitor capture, missing dependencies и desktop storage/export.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.17](TASK-FE-001.17.md), [TASK-FE-001.33](TASK-FE-001.33.md), [TASK-FE-001.35](TASK-FE-001.35.md).
Backend traceability: TASK-002.08, TASK-002.16, TASK-002.28
API: U01, U02, U04, R05.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: реальные Linux audio/storage/export; host gate не относится к будущему naming.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Настоящий Linux release build с указанными audio server/pactl/parec/ffmpeg/GTK, оба flow/Stop/leave/player/save/open; имена не условие smoke.
- [ ] Final WAV и process join/dispose/error/mix/permissions не теряют system source молча, zombie отсутствуют.
- [ ] Secret service и отсутствие opener/tools проверены; cache/journal cleanup не удаляет user source.
- [ ] macOS/fake tests не Linux evidence; без host — внешний blocker, без назначения mock для видимости готовности.
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
