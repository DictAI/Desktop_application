---
id: TASK-FE-001.11
plan: PLAN-FE-001
title: "Убрать voice-profile coupling из workspace и старта записи"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.09","TASK-FE-001.10"]
backend_tasks: ["TASK-002.16","TASK-002.25","TASK-002.30"]
api_contracts: ["W03","W06–W09","U01"]
blocked_by: []
scope:
  - "lib/features/workspace/data/dto/participant_dto.dart"
  - "lib/features/workspace/presentation/workspace_notifier.dart"
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "test/features/workspace/profile_free_flow_test.dart"
  - "docs/ai/tasks/TASK-FE-001.11.md"
planned_paths:
  - "test/features/workspace/profile_free_flow_test.dart"
---

# TASK-FE-001.11: Убрать voice-profile coupling из workspace и старта записи

## Goal

Workspace detail и запись работают с одними контактами, без обязательного voice setup.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Detail load обращается к VoiceProfileApi; UI библиотеки/образцов и RecordScreen блокируют запись без участников/профилей.

**Целевое:** Workspace detail и запись работают с одними контактами, без обязательного voice setup.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.10](TASK-FE-001.10.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.30
API: W03, W06–W09, U01.

## Acceptance criteria

- [ ] Удалены voice state/lookup/dialogs/assignment и ParticipantDto.voiceProfileId во всех затронутых consumers; load не вызывает удалённый API.
- [ ] Owner может начать запись/выбор файла в пустом workspace; gate остаётся только по выбранному workspace и текущему доступу, который решает backend.
- [ ] Сохранены name/email contacts, layout detail, error/retry/add/delete; удаление profiles не удаляет контакты.
- [ ] Widget fake с нулём participants и mock, отвергающим любой /voice-profiles вызов, проходит.
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
| `flutter test test/features/workspace/profile_free_flow_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
