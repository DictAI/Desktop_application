---
id: TASK-FE-001.33
plan: PLAN-FE-001
title: "Удалить остатки legacy speech flow после переключения consumers"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.14", "TASK-FE-001.23", "TASK-FE-001.24", "TASK-FE-001.27", "TASK-FE-001.28", "TASK-FE-001.31", "TASK-FE-001.32"]
backend_tasks: ["TASK-002.20", "TASK-002.25"]
api_contracts: ["§10"]
blocked_by: []
scope:
  - "lib/features/record/data/audio_ingest_api.dart"
  - "lib/features/record/data/anonymous_session_api.dart"
  - "lib/features/record/data/dto/anonymous_session_dto.dart"
  - "lib/features/record/presentation/label_speakers_modal.dart"
  - "lib/features/results/data/results_api.dart"
  - "lib/shared/providers/providers.dart"
  - "test/retirement/legacy_speech_test.dart"
  - "docs/ai/tasks/TASK-FE-001.33.md"
planned_paths:
  - "test/retirement/legacy_speech_test.dart"
delivery_stage: current
---

# TASK-FE-001.33: Удалить остатки legacy speech flow после переключения consumers

## Goal

Единственный runtime speech flow V2, без fallback и compatibility adapters.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** После V2 wiring старые API/DTO/confirm methods могут остаться неиспользуемыми.

**Целевое:** Единственный runtime speech flow V2, без fallback и compatibility adapters.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.14](TASK-FE-001.14.md), [TASK-FE-001.23](TASK-FE-001.23.md), [TASK-FE-001.24](TASK-FE-001.24.md), [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.32](TASK-FE-001.32.md).
Backend traceability: TASK-002.20, TASK-002.25
API: §10.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: удалить legacy/profile/confirm consumers; будущие assignments не создавать.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Удалены retired upload/session/fragment/confirm/profile APIs и old downloads после переключения callers, включая старый LabelSpeakersModal.
- [ ] Regression source не содержит старых runtime routes; historical docs допустимы.
- [ ] Сохраняются реальный audioplayers/file_picker и текущий player; ни mock assignments, ни local names не добавляются вместо legacy flow.
- [ ] Dormant ChatPanel/AnthropicService не подключаются; generic dependency cleanup/посторонняя чистка не входят в scope.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

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

План будущих проверок текущей реализации, сейчас **NOT RUN** в коррекции документации. Cwd — frontend, pinned SDK после .01; .01 не переоткрывается.

| Command / scenario | Expected | Actual / status / граница |
|---|---|---|
| `flutter test test/retirement/legacy_speech_test.dart` | Сохранены текущий player/transcript, удалены retired routes/DTO/LabelSpeakersModal | NOT RUN; тестовые fixtures только действующего контракта |
| Scoped format и analyze при реализации Dart | Нет новых проблем выбранного scope | NOT RUN; исходный unrelated baseline не исправляется автоматически |
| Real platform/live checks где релевантны | Реальный результат, не mock evidence | NOT RUN; .36/.37/.40, без будущих assignments |
| Links/DAG/hash/diff и независимый review коррекции | Текущая очередь без future prereqs, код сохранён | Coordinator evidence в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
