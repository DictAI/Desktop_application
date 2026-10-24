---
id: TASK-FE-001.34
plan: PLAN-FE-001
title: "Проверить и завершить account isolation и cleanup всего batch flow"
status: draft
owner: unassigned
priority: P0
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.09","TASK-FE-001.20","TASK-FE-001.25","TASK-FE-001.27","TASK-FE-001.28","TASK-FE-001.32","TASK-FE-001.33"]
backend_tasks: ["TASK-002.13","TASK-002.15","TASK-002.16","TASK-002.37"]
api_contracts: ["§2","R01–R04","U01–U04"]
blocked_by: []
scope:
  - "lib/shared/providers/providers.dart"
  - "lib/core/network/auth_interceptor.dart"
  - "lib/core/router/app_router.dart"
  - "lib/features/auth/presentation/auth_notifier.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/features/record/data/pending_upload_store.dart"
  - "test/security/account_isolation_test.dart"
  - "docs/ai/tasks/TASK-FE-001.34.md"
planned_paths:
  - "test/security/account_isolation_test.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/features/record/data/pending_upload_store.dart"
---

# TASK-FE-001.34: Проверить и завершить account isolation и cleanup всего batch flow

## Goal

Owner namespace и generation fencing во всём capture/upload/poll/download восстановлении.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Глобальные providers и async callbacks могут продолжить старую сессию после logout/account switch.

**Целевое:** Owner namespace и generation fencing во всём capture/upload/poll/download восстановлении.

**Категория B, P0.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.20](TASK-FE-001.20.md), [TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.32](TASK-FE-001.32.md), [TASK-FE-001.33](TASK-FE-001.33.md).
Backend traceability: TASK-002.13, TASK-002.15, TASK-002.16, TASK-002.37
API: §2, R01–R04, U01–U04.

## Acceptance criteria

- [ ] Logout/expiry закрывают все owned recorder/process/timer/subscription lifecycles и очищают/изолируют state перед новым login.
- [ ] Late 401/202/poll/download старой сессии не удаляют новый JWT и не показывают данные другому owner.
- [ ] Restart A→B→A проверен; чужие journal entries не запрашиваются/не загружаются; отсутствие публичного user profile API не восполняется новым endpoint.
- [ ] Токен лишь источник локального namespace, авторизация всегда серверная; temporary audio и journal не попадают в общие logs.
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
| `flutter test test/security/account_isolation_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
