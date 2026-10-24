---
id: TASK-FE-001.38
plan: PLAN-FE-001
title: "Подготовить opt-in интеграционный harness и требования к стенду"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "4"
depends_on: ["TASK-FE-001.19","TASK-FE-001.21","TASK-FE-001.22","TASK-FE-001.26","TASK-FE-001.30","TASK-FE-001.34","TASK-FE-001.35"]
backend_tasks: ["TASK-002.14","TASK-002.15","TASK-002.16","TASK-002.17","TASK-002.22","TASK-002.24","TASK-002.28","TASK-002.30","TASK-002.37"]
api_contracts: ["§9","A01–A03","W01–W09","U01–U04","R01–R05"]
blocked_by: []
scope:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/BACKEND_INTEGRATION.ru.md"
  - "docs/ai/tasks/TASK-FE-001.38.md"
planned_paths:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/BACKEND_INTEGRATION.ru.md"
---

# TASK-FE-001.38: Подготовить opt-in интеграционный harness и требования к стенду

## Goal

Harness готов с synthetic fixtures и явным opt-in, без запуска на неподтверждённом endpoint.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Нет тестового gateway config или opt-in интеграционного сценария; наличие IP в providers не даёт разрешения писать в production.

**Целевое:** Harness готов с synthetic fixtures и явным opt-in, без запуска на неподтверждённом endpoint.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.19](TASK-FE-001.19.md), [TASK-FE-001.21](TASK-FE-001.21.md), [TASK-FE-001.22](TASK-FE-001.22.md), [TASK-FE-001.26](TASK-FE-001.26.md), [TASK-FE-001.30](TASK-FE-001.30.md), [TASK-FE-001.34](TASK-FE-001.34.md), [TASK-FE-001.35](TASK-FE-001.35.md).
Backend traceability: TASK-002.14, TASK-002.15, TASK-002.16, TASK-002.17, TASK-002.22, TASK-002.24, TASK-002.28, TASK-002.30, TASK-002.37
API: §9, A01–A03, W01–W09, U01–U04, R01–R05.

## Acceptance criteria

- [ ] Документ перечисляет test URL/TLS, V2 gate, модели/artifacts/MinIO versioning, migrations/NATS/mTLS, LLM/Typst/SMTP и owner test accounts.
- [ ] Harness по умолчанию не делает network writes и не выдаёт SKIP за PASS; запуск требует явного test-origin/credentials/разрешения на finite synthetic jobs.
- [ ] Проверяет exact bytes/status/ownership и cleanup через существующий delete, не утверждает полное physical deletion; нет зависимости integration_test SDK без необходимости.
- [ ] Чеклист различает функциональные HTTP probes, .17 quality acceptance, .24 staging и .31 production evidence; secret env в docs не записывается.
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
| `flutter test test/integration/batch_backend_test.dart (без opt-in ожидаемый NOT RUN/SKIP, не PASS интеграции)` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `Проверка harness с fake transport и review safety guards` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
