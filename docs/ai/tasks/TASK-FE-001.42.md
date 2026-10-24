---
id: TASK-FE-001.42
plan: PLAN-FE-001
title: "Зафиксировать готовность frontend-интеграции к batch-релизу"
status: blocked
owner: unassigned
priority: P0
readiness_category: C
phase: "5"
depends_on: ["TASK-FE-001.40","TASK-FE-001.41"]
backend_tasks: ["TASK-002.17","TASK-002.24","TASK-002.31"]
api_contracts: ["§9"]
blocked_by: ["Backend .17 draft, .24/.31 blocked на исходном срезе; production evidence отсутствует.","Не завершены .40/.41, platform/security evidence и явная приёмка владельца."]
scope:
  - "docs/release/BATCH_ACCEPTANCE.ru.md"
  - "docs/ai/tasks/TASK-FE-001.42.md"
planned_paths:
  - "docs/release/BATCH_ACCEPTANCE.ru.md"
---

# TASK-FE-001.42: Зафиксировать готовность frontend-интеграции к batch-релизу

## Goal

Человеческая приёмка frontend по evidence и синхронизация с реально готовым новым backend.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Полный CPU E2E/cutover/production evidence backend пока не завершены.

**Целевое:** Человеческая приёмка frontend по evidence и синхронизация с реально готовым новым backend.

**Категория C, P0.** Полное завершение заблокировано внешним backend/operator evidence; отсутствие evidence нельзя заменить mocks.
FE prerequisites: [TASK-FE-001.40](TASK-FE-001.40.md), [TASK-FE-001.41](TASK-FE-001.41.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.31
API: §9.

### Блокировки и разблокировка

- Backend .17 draft, .24/.31 blocked на исходном срезе; production evidence отсутствует.
- Не завершены .40/.41, platform/security evidence и явная приёмка владельца.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Acceptance criteria

- [ ] Закрыты выбранные mandatory задачи, tests/reviews и macOS/Linux checks; unresolved findings/blockers явно исключают утверждение полного release readiness.
- [ ] Подтверждены .17/.24/.31 для целевого deployment, судьба old in-flight jobs/results и операторская конфигурация; current SHA/contracts перепроверены.
- [ ] Security findings .02/.39 и credential rotation имеют evidence владельца; неподтверждённые live/chat/sharing/cancel не рекламируются.
- [ ] Только владелец принимает результат; commit/push/merge/release/deployment не выполняются этой карточкой.
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
| `Review всех acceptance/evidence records и backend rollout receipts` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `Пользовательская приёмка на зафиксированных frontend/backend SHA` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
