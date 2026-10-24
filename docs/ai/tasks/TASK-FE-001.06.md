---
id: TASK-FE-001.06
plan: PLAN-FE-001
title: "Подготовить тестовую основу без сети и аппаратуры"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01"]
backend_tasks: []
api_contracts: []
blocked_by: []
scope:
  - "test/widget_test.dart"
  - "test/support/test_app.dart"
  - "test/support/fakes.dart"
  - "docs/testing/README.ru.md"
  - "docs/ai/tasks/TASK-FE-001.06.md"
planned_paths:
  - "test/support/test_app.dart"
  - "test/support/fakes.dart"
  - "docs/testing/README.ru.md"
---

# TASK-FE-001.06: Подготовить тестовую основу без сети и аппаратуры

## Goal

Повторяемые unit/widget проверки через Riverpod overrides, fake Dio/capture/storage и управляемое время.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** widget_test.dart пустой; unit/widget fixtures и overrides отсутствуют.

**Целевое:** Повторяемые unit/widget проверки через Riverpod overrides, fake Dio/capture/storage и управляемое время.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: нет новых API.

## Acceptance criteria

- [ ] Пустой тест заменён содержательным app/router smoke без реального API, Keychain, микрофона и subprocess.
- [ ] Документированы команды и override boundaries; тесты не используют реальные ключи, аудио и домашние пути.
- [ ] Fakes позволяют задержанные ответы, 401, non-JSON/bytes, late completion/dispose и контролируемый polling без flaky sleep.
- [ ] Новые test packages не добавляются без необходимости; сначала используются flutter_test и существующие dependencies.
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
| `flutter test test/widget_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
