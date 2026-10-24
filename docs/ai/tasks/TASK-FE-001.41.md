---
id: TASK-FE-001.41
plan: PLAN-FE-001
title: "Подготовить локальный batch release candidate и инструкцию выпуска"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "5"
depends_on: ["TASK-FE-001.33","TASK-FE-001.35","TASK-FE-001.36","TASK-FE-001.37","TASK-FE-001.38"]
backend_tasks: ["TASK-002.17","TASK-002.24","TASK-002.31"]
api_contracts: ["§9"]
blocked_by: []
scope:
  - "docs/release/BATCH_RELEASE_CHECKLIST.ru.md"
  - "docs/release/CONFIGURATION.example.md"
  - "docs/ai/tasks/TASK-FE-001.41.md"
planned_paths:
  - "docs/release/BATCH_RELEASE_CHECKLIST.ru.md"
  - "docs/release/CONFIGURATION.example.md"
---

# TASK-FE-001.41: Подготовить локальный batch release candidate и инструкцию выпуска

## Goal

Воспроизводимый локальный candidate/checklist без публикации, самовольного version bump или cloud deployment.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Version 1.0.0+1 и платформенные templates есть; release process/конфигурационный checklist не зафиксированы.

**Целевое:** Воспроизводимый локальный candidate/checklist без публикации, самовольного version bump или cloud deployment.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.33](TASK-FE-001.33.md), [TASK-FE-001.35](TASK-FE-001.35.md), [TASK-FE-001.36](TASK-FE-001.36.md), [TASK-FE-001.37](TASK-FE-001.37.md), [TASK-FE-001.38](TASK-FE-001.38.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.31
API: §9.

## Acceptance criteria

- [ ] Документированы build commands, SDK/package lock, environment policy, платформенные prerequisites и безопасное хранение credentials.
- [ ] Release config не содержит ключей/HTTP production default/log bodies; все mandatory batch paths и отсутствующие функции описаны честно.
- [ ] Локальные artifacts/checksums и known limitations проверяемы, не добавлены в Git; версия/signing/notarization/installer distribution требуют отдельного решения.
- [ ] Наличие candidate не означает разрешения release или backend readiness; final gate в .42.
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
| `Повторяемая локальная сборка по .36/.37 и review release checklist` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `Redacted config/artifact scan; git diff --check` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
