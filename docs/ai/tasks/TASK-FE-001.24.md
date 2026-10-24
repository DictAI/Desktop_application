---
id: TASK-FE-001.24
plan: PLAN-FE-001
title: "Заменить anonymous confirm на owner-only V2 batch UX"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.23"]
backend_tasks: ["TASK-002.16","TASK-002.25","TASK-002.30"]
api_contracts: ["U02","U03","R03","R04"]
blocked_by: []
scope:
  - "lib/features/record/presentation/anonymous_record_notifier.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/features/record/presentation/upload_modal.dart"
  - "lib/features/record/presentation/label_speakers_modal.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/record/anonymous_flow_test.dart"
  - "docs/ai/tasks/TASK-FE-001.24.md"
planned_paths:
  - "test/features/record/anonymous_flow_test.dart"
---

# TASK-FE-001.24: Заменить anonymous confirm на owner-only V2 batch UX

## Goal

Авторизованный upload без workspace, тот же WAV/capture/journal/tracker, без speaker confirmation.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Anon пишет M4A/OGG; открывает недismissible LabelSpeakersModal, collects name/email и confirm создаёт workspace.

**Целевое:** Авторизованный upload без workspace, тот же WAV/capture/journal/tracker, без speaker confirmation.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.23](TASK-FE-001.23.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.30
API: U02, U03, R03, R04.

## Acceptance criteria

- [ ] Anonymous использует общий capture для mic/system на macOS/Linux, а не отдельный opus/aac pipeline.
- [ ] В upload workspace_id отсутствует; accepted job/session сохранены, failed/cancelled/expired отображаются terminal без вечного polling.
- [ ] Не запрашиваются speaker names/emails/fragments, не создаются workspace/participants/profiles; LabelSpeakersModal и его consumers удалены.
- [ ] UI показывает именно anon upload/error/poll state, блокирует двойные stop/upload и mode switch; email только owner, anonymous не значит unauthenticated.
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
| `flutter test test/features/record/anonymous_flow_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
