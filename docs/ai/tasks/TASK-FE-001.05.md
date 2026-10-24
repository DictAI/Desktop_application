---
id: TASK-FE-001.05
plan: PLAN-FE-001
title: "Настроить явную конфигурацию gateway и сетевых политик"
status: draft
owner: unassigned
priority: P0
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01","TASK-FE-001.02","TASK-FE-001.03"]
backend_tasks: ["TASK-002.16","TASK-002.28","TASK-002.37"]
api_contracts: ["§2","§9"]
blocked_by: []
scope:
  - "lib/core/network/api_client.dart"
  - "lib/core/config/app_config.dart"
  - "lib/shared/providers/providers.dart"
  - ".vscode/launch.json"
  - ".vscode/launch.example.json"
  - "docs/development/ENVIRONMENT.ru.md"
  - "test/core/config/app_config_test.dart"
  - "docs/ai/tasks/TASK-FE-001.05.md"
planned_paths:
  - "lib/core/config/app_config.dart"
  - "docs/development/ENVIRONMENT.ru.md"
  - "test/core/config/app_config_test.dart"
  - ".vscode/launch.example.json"
---

# TASK-FE-001.05: Настроить явную конфигурацию gateway и сетевых политик

## Goal

Environment config без секретов в binary, корректный origin и отдельные upload/download/status timeouts.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Gateway URL захардкожен в providers; launch dart-define не читаются; единый receive timeout 30 s.

**Целевое:** Environment config без секретов в binary, корректный origin и отдельные upload/download/status timeouts.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md), [TASK-FE-001.02](TASK-FE-001.02.md), [TASK-FE-001.03](TASK-FE-001.03.md).
Backend traceability: TASK-002.16, TASK-002.28, TASK-002.37
API: §2, §9.

## Acceptance criteria

- [ ] API base URL читается из документированного dart-define; release не использует скрытый HTTP IP/default, HTTPS обязателен вне явно заданного local dev.
- [ ] Проверяются origin/relative URLs: JWT не уходит на произвольные host из result URL; внешние ссылки не считаются signed public downloads.
- [ ] Timeout и retry policy различают upload 15-min server context, polling и большие downloads; не обещается обход более короткого proxy timeout.
- [ ] Взаимодействие идёт только через gateway; MinIO/NATS/gRPC/private metrics не становятся frontend dependencies.
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
| `flutter test test/core/config/app_config_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
