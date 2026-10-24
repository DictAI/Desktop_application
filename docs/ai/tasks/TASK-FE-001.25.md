---
id: TASK-FE-001.25
plan: PLAN-FE-001
title: "Организовать lifecycle polling и восстановление accepted jobs"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.09","TASK-FE-001.14","TASK-FE-001.20","TASK-FE-001.21"]
backend_tasks: ["TASK-002.13","TASK-002.15","TASK-002.16","TASK-002.22"]
api_contracts: ["R01","R03","U03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/processing_recovery_test.dart"
  - "docs/ai/tasks/TASK-FE-001.25.md"
planned_paths:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "test/features/results/processing_recovery_test.dart"
---

# TASK-FE-001.25: Организовать lifecycle polling и восстановление accepted jobs

## Goal

Один bounded in-flight poll на job с generation fencing/backoff и owner-scoped restart recovery.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Periodic timers anonymous/results могут перекрываться, теряют filters и не сохраняют job identity; failed иногда не останавливает ожидание.

**Целевое:** Один bounded in-flight poll на job с generation fencing/backoff и owner-scoped restart recovery.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.14](TASK-FE-001.14.md), [TASK-FE-001.20](TASK-FE-001.20.md), [TASK-FE-001.21](TASK-FE-001.21.md).
Backend traceability: TASK-002.13, TASK-002.15, TASK-002.16, TASK-002.22
API: R01, R03, U03.

## Acceptance criteria

- [ ] Poll не перекрывается; failed/cancelled/expired/deleted завершают соответствующее ожидание; summary pending отслеживается отдельно после transcript ready.
- [ ] После restart accepted job возобновляется по journal или R01(result_id=job_id), без повторного upload; отсутствующий/чужой/deleted job не воскрешается.
- [ ] Transient offline/429/502/503 имеют ограниченную backoff policy; 401 завершает session; late responses после dispose/logout не меняют state.
- [ ] Никаких stage metrics/private broker, бесконечных loops и автоматического grant/reprocess/cancel; pending без данных не трактуется как успех.
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
| `flutter test test/features/results/processing_recovery_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
