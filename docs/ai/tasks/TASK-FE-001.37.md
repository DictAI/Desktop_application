---
id: TASK-FE-001.37
plan: PLAN-FE-001
title: "Проверить Linux build, аудио prerequisites и export"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "4"
depends_on: ["TASK-FE-001.17","TASK-FE-001.33","TASK-FE-001.35"]
backend_tasks: ["TASK-002.08","TASK-002.16","TASK-002.28"]
api_contracts: ["U01","U02","U04","R05"]
blocked_by: []
scope:
  - "docs/testing/LINUX_BATCH_VERIFICATION.ru.md"
  - "docs/ai/tasks/TASK-FE-001.37.md"
planned_paths:
  - "docs/testing/LINUX_BATCH_VERIFICATION.ru.md"
---

# TASK-FE-001.37: Проверить Linux build, аудио prerequisites и export

## Goal

Evidence Linux release bundle, mic/monitor capture, missing dependencies и desktop storage/export.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Linux CMake/GTK и CLI audio paths есть; macOS хост не доказывает Linux behavior.

**Целевое:** Evidence Linux release bundle, mic/monitor capture, missing dependencies и desktop storage/export.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.17](TASK-FE-001.17.md), [TASK-FE-001.33](TASK-FE-001.33.md), [TASK-FE-001.35](TASK-FE-001.35.md).
Backend traceability: TASK-002.08, TASK-002.16, TASK-002.28
API: U01, U02, U04, R05.

## Acceptance criteria

- [ ] На реальном Linux собран release bundle, указан audio server и версии pactl/parec/ffmpeg/GTK; missing tools и monitor дают ожидаемые UI errors.
- [ ] Обе формы получают валидный завершённый WAV; stop/dispose не оставляют subprocess, permission/mix failures не теряют источник молча.
- [ ] Secure storage backend и save/open download проверены, включая отсутствие secret-service/opener.
- [ ] Linux не помечается проверенным по macOS/fake tests; при недоступном host фиксируется явный внешний blocker.
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
| `flutter build linux --release` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `Ручной Linux smoke и процессный inventory до/после` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
