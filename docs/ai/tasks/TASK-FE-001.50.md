---
id: TASK-FE-001.50
plan: PLAN-FE-001
title: "Подключить будущий backend API назначений имён"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "5"
depends_on: ["TASK-FE-001.43", "TASK-FE-001.47", "TASK-FE-001.48", "TASK-FE-001.34"]
backend_tasks: []
backend_requests: ["BR-02", "BR-03", "BR-07"]
api_contracts: []
blocked_by: ["Вне текущего этапа: нет утверждённого и реализованного backend read/save назначений и связи Speaker ID с contact (BR-02/03)."]
scope:
  - "lib/features/results/data/speaker_assignments_api.dart"
  - "lib/features/results/data/dto/speaker_assignments_wire_dto.dart"
  - "lib/features/results/presentation/speaker_assignment_notifier.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/speaker_assignments_api_test.dart"
  - "test/features/results/server_assignments_restart_test.dart"
  - "docs/ai/tasks/TASK-FE-001.50.md"
  - "lib/core/router/app_router.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
planned_paths:
  - "lib/features/results/data/speaker_assignments_api.dart"
  - "lib/features/results/data/dto/speaker_assignments_wire_dto.dart"
  - "lib/features/results/presentation/speaker_assignment_notifier.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "test/features/results/speaker_assignments_api_test.dart"
  - "test/features/results/server_assignments_restart_test.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
delivery_stage: future
---

# TASK-FE-001.50: Подключить будущий backend API назначений имён

## Goal

Настоящий owner-authorized read/save и contact snapshot на backend, доступные после повторного входа и на другом устройстве.

Не выполнять сейчас: разрешено планирование, реализация не выбрана. Категория и
mock-ready не заменяют выбора пользователя, accepted prerequisites и review.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.43](TASK-FE-001.43.md), [TASK-FE-001.47](TASK-FE-001.47.md), [TASK-FE-001.48](TASK-FE-001.48.md), [TASK-FE-001.34](TASK-FE-001.34.md).
Категория C: реализация/завершение ждут внешнего согласованного и реализованного backend-контракта.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Будущее: реальный read/save/reset/contact snapshot и подключение editor entry после backend.

**Будущее, вне текущей очереди.** Не создавать временный UI/local persistence/mock. Согласованные требования сохранены в UX/BR; unblock только по backend evidence и отдельному выбору.

## Acceptance criteria

- [ ] До реализации команда предоставила утверждённый и реализованный контракт BR-02/03: context/ownership, read/save/reset, validation, conflict/idempotency/unknown-outcome, contact snapshot и tombstone. Backend task IDs/actual SHA записаны только после назначения командой.
- [ ] Wire DTO/client строго следуют этому contract delta, общий Dio/AuthInterceptor сохранён; никаких заранее придуманных endpoints/JSON/revision/status fields. Canonical ID/label/processing_version не меняются.
- [ ] Подтверждённые имена переживают logout/login/restart и доступны другому разрешённому клиенту того же owner; чужой owner/job/speaker/contact workspace отвергается сервером, не только UI.
- [ ] Snapshot имени переживает rename/delete контакта; один контакт на нескольких Speaker IDs разрешён с UI warning; запись без workspace допускает manual/Speaker N без создания контакта.
- [ ] Summary pending/failed не блокирует read/save; offline/read/save/conflict/lost response не теряют draft и не выдаются за success. Save retry/конкурентность проверены по реальному согласованному контракту.
- [ ] Production использует реально поддерживаемый API; repository seam не обязателен без необходимости. Тестовые fixtures отражают уже существующий contract, без обязательного mock-репозитория будущей функции. Нет silent local fallback; future real E2E подтверждается отдельно от текущей .40.
- [ ] Записаны команды/cwd/среда/actual results; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый review выполнен другим агентом; findings и ограничения сохранены, accepted требует пользователя.

## Implementation notes

Будущее требование сохраняется, но текущая версия не создаёт этот UI, API-клиент или локальную бизнес-имитацию. До actual backend contract evidence не вводить wire fields/endpoints/revision и архитектуру на вырост. Тестовые fixtures допустимы после существования соответствующего контракта; отдельный mock-репозиторий будущих назначений не обязателен и сейчас запрещён.

Scope/planned_paths — будущие пути, не команда создавать их сейчас. Backend read-only; code/tasks не реализуются этой коррекцией. Commit/push/merge запрещены текущим поручением.

## Verification

Будущие проверки после backend readiness, сейчас **NOT RUN**.

| Проверка | Статус / граница |
|---|---|
| Contract approval/implementation/actual SHA и owner authorization | NOT RUN; обязательный входной gate |
| `flutter test test/features/results/speaker_assignments_api_test.dart test/features/results/server_assignments_restart_test.dart` | NOT RUN; файлы planned, не существуют/не создаются сейчас |
| Scoped format/analyze, real integration и независимый review | NOT RUN; mock/prototype не заменяет backend |

## Result

2026-11-02: перенесено в будущий этап, status blocked/category C. Согласованное продуктовое требование не отменено; код этой функциональности отсутствует и не создаётся. Прежняя стратегия обязательного mock/UI/local-name prototype отменена. Фактический backend контракт ещё не предоставлен; endpoint/DTO не назначаются frontend. Приёмки нет.
