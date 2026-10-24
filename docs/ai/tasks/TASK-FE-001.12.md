---
id: TASK-FE-001.12
plan: PLAN-FE-001
title: "Завершить workspace UX создания и переименования"
status: draft
owner: unassigned
priority: P2
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.11"]
backend_tasks: ["TASK-002.25"]
api_contracts: ["W01–W05"]
blocked_by: []
scope:
  - "lib/features/workspace/presentation/workspaces_screen.dart"
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "lib/features/workspace/presentation/workspace_notifier.dart"
  - "test/features/workspace/workspace_crud_widget_test.dart"
  - "docs/ai/tasks/TASK-FE-001.12.md"
planned_paths:
  - "test/features/workspace/workspace_crud_widget_test.dart"
---

# TASK-FE-001.12: Завершить workspace UX создания и переименования

## Goal

Workspace CRUD через существующие API с сохранением сетки и маршрута detail.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Список/create/delete существуют, updateWorkspace в notifier не связан с полноценным edit UX.

**Целевое:** Workspace CRUD через существующие API с сохранением сетки и маршрута detail.

**Категория B, P2.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.11](TASK-FE-001.11.md).
Backend traceability: TASK-002.25
API: W01–W05.

## Acceptance criteria

- [ ] Создание, открытие, rename и delete имеют loading/validation/failure/retry состояния без STUB обещаний.
- [ ] Rename обновляет list/detail и выбранный workspace без stale name; отсутствие/недоступность workspace корректно объясняется.
- [ ] Удаление не трактуется как deletion всех audio/results; соответствующую политику не выдумывать.
- [ ] Контакт/роль не используются как подтверждение серверного owner access.
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
| `flutter test test/features/workspace/workspace_crud_widget_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
