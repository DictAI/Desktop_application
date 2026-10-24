---
id: TASK-FE-001.35
plan: PLAN-FE-001
title: "Покрыть batch-пути unit/widget regression suite"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "4"
depends_on: ["TASK-FE-001.12","TASK-FE-001.13","TASK-FE-001.23","TASK-FE-001.24","TASK-FE-001.29","TASK-FE-001.31","TASK-FE-001.32","TASK-FE-001.34"]
backend_tasks: ["TASK-002.17"]
api_contracts: ["A01–A03","W01–W09","U01–U04","R01–R05"]
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
---

# TASK-FE-001.35: Покрыть batch-пути unit/widget regression suite

## Goal

Детерминированная пользовательская regression matrix по fake backend/capture/storage.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Нет сквозных проверок state/навигации, existing widget_test пуст.

**Целевое:** Детерминированная пользовательская regression matrix по fake backend/capture/storage.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.12](TASK-FE-001.12.md), [TASK-FE-001.13](TASK-FE-001.13.md), [TASK-FE-001.23](TASK-FE-001.23.md), [TASK-FE-001.24](TASK-FE-001.24.md), [TASK-FE-001.29](TASK-FE-001.29.md), [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.32](TASK-FE-001.32.md), [TASK-FE-001.34](TASK-FE-001.34.md).
Backend traceability: TASK-002.17
API: A01–A03, W01–W09, U01–U04, R01–R05.

## Acceptance criteria

- [ ] Покрыты login→workspace/anonymous→capture или picker→202→restart→canonical→summary/documents→delete→logout.
- [ ] Покрыты lost upload response/replay409, offline/backoff429/502/503, 202failed/cancelled, no-speech, transcript ready+summary failed, artifact503, document404 и неполный original.
- [ ] Покрыты owner isolation/expired session и обход отсутствующего confirm; assertions проверяют видимое поведение, а не только вызванные методы.
- [ ] NOT RUN platform/model checks явно отделены; golden/theme redesign и CI не входят в task.
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
| `flutter test test/journeys/batch_journey_test.dart test/journeys/batch_failure_test.dart test/journeys/batch_restart_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter test; flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
