---
id: TASK-FE-001.39
plan: PLAN-FE-001
title: "Подтвердить тестовый backend и закрыть контрактные вопросы доступа"
status: blocked
owner: unassigned
priority: P0
readiness_category: C
phase: "5"
depends_on: ["TASK-FE-001.38"]
backend_tasks: ["TASK-002.16","TASK-002.24","TASK-002.28","TASK-002.37"]
api_contracts: ["§9","W03","W06","U05","U06"]
blocked_by: ["Нет согласованного test-origin/operator env/accounts и подтверждения runtime prerequisites.","Не урегулированы workspace access/security вопросы; нет отдельной backend задачи, которая автоматически обещает их исправить."]
scope:
  - "docs/testing/BACKEND_CONTRACT_GATE.ru.md"
  - "docs/ai/tasks/TASK-FE-001.39.md"
planned_paths:
  - "docs/testing/BACKEND_CONTRACT_GATE.ru.md"
---

# TASK-FE-001.39: Подтвердить тестовый backend и закрыть контрактные вопросы доступа

## Goal

Принятое описание тестового окружения, актуального SHA и границ первого batch API без самовольных backend fixes.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Base URL/TLS/PKI/model runtime и правила workspace доступа не подтверждены; grant discovery отсутствует.

**Целевое:** Принятое описание тестового окружения, актуального SHA и границ первого batch API без самовольных backend fixes.

**Категория C, P0.** Полное завершение заблокировано внешним backend/operator evidence; отсутствие evidence нельзя заменить mocks.
FE prerequisites: [TASK-FE-001.38](TASK-FE-001.38.md).
Backend traceability: TASK-002.16, TASK-002.24, TASK-002.28, TASK-002.37
API: §9, W03, W06, U05, U06.

### Блокировки и разблокировка

- Нет согласованного test-origin/operator env/accounts и подтверждения runtime prerequisites.
- Не урегулированы workspace access/security вопросы; нет отдельной backend задачи, которая автоматически обещает их исправить.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Acceptance criteria

- [ ] Есть явно разрешённый isolated test origin и accounts, runtime prerequisites проверены с operator evidence; секреты не сохраняются.
- [ ] Сверены актуальные routes/DTO с исследованным SHA; изменения оформлены отдельным delta evidence, неизменяемые BACKEND_* snapshots не переписаны.
- [ ] Владелец/команда согласовали owner-only/contact semantics и существующие workspace access ошибки; security blockers переданы backend с реальным owner, без придуманных task ID.
- [ ] Grant discovery/cancel/live и spec-only meetings не становятся требованиями этого batch-релиза; если они всё же нужны — отдельный согласованный scope.
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
| `Read-only source/config/route сверка и согласованные test probes по docs/testing/BACKEND_INTEGRATION.ru.md` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `Проверка owner/nonowner на синтетических test accounts с разрешением на стенд` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
