---
id: TASK-FE-001.32
plan: PLAN-FE-001
title: "Согласовать delete/tombstone и очистку локального состояния"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.27","TASK-FE-001.28","TASK-FE-001.31"]
backend_tasks: ["TASK-002.15","TASK-002.20","TASK-002.27","TASK-002.37"]
api_contracts: ["R02","R03","U03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "test/features/results/deletion_test.dart"
  - "docs/ai/tasks/TASK-FE-001.32.md"
planned_paths:
  - "test/features/results/deletion_test.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
---

# TASK-FE-001.32: Согласовать delete/tombstone и очистку локального состояния

## Goal

Удаление скрывает все версии audio в UI и прекращает polling/локальное восстановление.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Delete из списка существует, но не координирует detail/job/journal и сообщает ошибочный STUB message.

**Целевое:** Удаление скрывает все версии audio в UI и прекращает polling/локальное восстановление.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.31](TASK-FE-001.31.md).
Backend traceability: TASK-002.15, TASK-002.20, TASK-002.27, TASK-002.37
API: R02, R03, U03.

## Acceptance criteria

- [ ] Confirm поясняет hide/tombstone, а не cancel/полное physical destruction; 204 и повтор/404/401/500 обработаны.
- [ ] Удалённые audio/job исчезают из list/detail/cache/journal; late polls и anonymous session ready не воскрешают result.
- [ ] Локальные app-owned temp файлы удаляются только по своему inventory; исходный пользовательский выбранный файл не удаляется.
- [ ] Нет source cleanup API, server cancel, profile data SQL или backend retention changes.
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
| `flutter test test/features/results/deletion_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
