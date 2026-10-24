---
id: TASK-FE-001.01
plan: PLAN-FE-001
title: "Согласовать и воспроизвести Flutter/Dart toolchain"
status: ready
owner: unassigned
priority: P0
readiness_category: A
phase: "0"
depends_on: []
backend_tasks: []
api_contracts: []
blocked_by: []
scope:
  - "pubspec.yaml"
  - "pubspec.lock"
  - "docs/development/TOOLCHAIN.ru.md"
  - "docs/ai/tasks/TASK-FE-001.01.md"
planned_paths:
  - "docs/development/TOOLCHAIN.ru.md"
---

# TASK-FE-001.01: Согласовать и воспроизвести Flutter/Dart toolchain

## Goal

Один проверенный совместимый SDK и согласованные ограничения без случайного обновления dependency graph.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** pubspec допускает Dart 3.3/Flutter 3.19, lock требует Dart >=3.11/Flutter >=3.35.6; установлен Flutter 3.38.1 с Dart 3.10.0.

**Целевое:** Один проверенный совместимый SDK и согласованные ограничения без случайного обновления dependency graph.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: нет.
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: нет новых API.

## Acceptance criteria

- [ ] Зафиксированы точная версия Flutter с bundled Dart >=3.11, способ получения и требования macOS/Linux; конкретная версия выбрана по реально доступному SDK, не выдумана планом.
- [ ] pubspec/lock согласованы; предпочтён совместимый SDK с существующим lock, изменения packages только при доказанной необходимости и явном scope.
- [ ] Сняты исходные analyze/test/format результаты с разделением старых проблем и новых; пустой widget_test не считается покрытием.
- [ ] Изменения host SDK/установка инструментов выполняются только при разрешённой среде; отсутствие SDK остаётся явным blocker.
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
SDK/lock changes ограничены воспроизводимостью, не общим обновлением libraries.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter --version; dart --version; flutter pub get (только выбранная реализация, проверить diff lock)` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze; flutter test; dart format --output=none --set-exit-if-changed lib test` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
