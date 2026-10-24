---
id: TASK-FE-001.09
plan: PLAN-FE-001
title: "Согласовать auth UI, JWT lifecycle и навигацию"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.08"]
backend_tasks: ["TASK-002.37"]
api_contracts: ["A01–A03","§2"]
blocked_by: []
scope:
  - "lib/features/auth/presentation/auth_notifier.dart"
  - "lib/features/auth/presentation/login_screen.dart"
  - "lib/core/network/auth_interceptor.dart"
  - "lib/core/router/auth_listenable.dart"
  - "lib/core/router/app_router.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/auth/session_navigation_test.dart"
  - "docs/ai/tasks/TASK-FE-001.09.md"
planned_paths:
  - "test/features/auth/session_navigation_test.dart"
---

# TASK-FE-001.09: Согласовать auth UI, JWT lifecycle и навигацию

## Goal

Явные login/loading/error/expired/logout состояния и управляемое обновление ещё действующего JWT.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Redirect проверяет только наличие token; 401 удаляет его; error copyWith не очищает null; session-bound features живут глобально.

**Целевое:** Явные login/loading/error/expired/logout состояния и управляемое обновление ещё действующего JWT.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.08](TASK-FE-001.08.md).
Backend traceability: TASK-002.37
API: A01–A03, §2.

## Acceptance criteria

- [ ] Register→login сохранён; ошибка очищается при повторе; double submit и поздние callbacks после dispose не меняют новый session.
- [ ] Истёкший/старый issuer JWT требует login; refresh не лечит expired JWT и не запускает бесконечный 401/refresh loop.
- [ ] Logout локально удаляет credential и сбрасывает текущие feature states; поздний ответ старого session не разлогинивает нового пользователя.
- [ ] Полная batch account-isolation дополняется .34; router guards сохраняют JWT и для anonymous.
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
| `flutter test test/features/auth/session_navigation_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
