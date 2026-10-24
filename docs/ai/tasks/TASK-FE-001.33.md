---
id: TASK-FE-001.33
plan: PLAN-FE-001
title: "Удалить остатки legacy speech flow после переключения consumers"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.14","TASK-FE-001.23","TASK-FE-001.24","TASK-FE-001.27","TASK-FE-001.28","TASK-FE-001.31","TASK-FE-001.32"]
backend_tasks: ["TASK-002.20","TASK-002.25"]
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
---

# TASK-FE-001.33: Удалить остатки legacy speech flow после переключения consumers

## Goal

Единственный runtime speech flow V2, без fallback и compatibility adapters.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** После V2 wiring старые API/DTO/confirm methods могут остаться неиспользуемыми.

**Целевое:** Единственный runtime speech flow V2, без fallback и compatibility adapters.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.14](TASK-FE-001.14.md), [TASK-FE-001.23](TASK-FE-001.23.md), [TASK-FE-001.24](TASK-FE-001.24.md), [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.32](TASK-FE-001.32.md).
Backend traceability: TASK-002.20, TASK-002.25
API: §10.

## Acceptance criteria

- [ ] Удалены старые upload/session/fragment/confirm DTO/API/imports и старые results downloads после миграции callers.
- [ ] rg/consumer regression подтверждает отсутствие вызовов /ingest/audio, /voice-profiles, старых summary/transcript/audio paths; historical docs допустимы.
- [ ] Пакеты не удаляются автоматически только из-за исчезновения voice UI: audioplayers/file_picker могут использоваться новым flow.
- [ ] ChatPanel/AnthropicService не подключаются и не развиваются; отдельная физическая чистка dormant chat не обязательный scope этой задачи.
- [ ] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

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

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/retirement/legacy_speech_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
