---
id: TASK-FE-001.46
plan: PLAN-FE-001
title: "Создать редактор назначений после готовности backend"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "3"
depends_on: ["TASK-FE-001.43", "TASK-FE-001.45", "TASK-FE-001.29", "TASK-FE-001.34"]
backend_tasks: []
backend_requests: ["BR-02", "BR-03"]
api_contracts: []
blocked_by: ["Вне текущего этапа: нет утверждённого и реализованного backend read/save назначений и связи Speaker ID с contact (BR-02/03)."]
scope:
  - "lib/features/results/presentation/speaker_assignment_screen.dart"
  - "lib/features/results/presentation/speaker_assignment_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/core/router/app_router.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/speaker_assignment_editor_test.dart"
  - "docs/ai/tasks/TASK-FE-001.46.md"
planned_paths:
  - "lib/features/results/presentation/speaker_assignment_screen.dart"
  - "lib/features/results/presentation/speaker_assignment_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "test/features/results/speaker_assignment_editor_test.dart"
delivery_stage: future
---

# TASK-FE-001.46: Создать редактор назначений после готовности backend

## Goal

После готовности backend реализовать редактор имён/контактов и Skip с настоящим read/save; текущая версия не содержит этого UI.

Будущий этап, реализация не выбрана до backend evidence.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.43](TASK-FE-001.43.md), [TASK-FE-001.45](TASK-FE-001.45.md), [TASK-FE-001.29](TASK-FE-001.29.md), [TASK-FE-001.34](TASK-FE-001.34.md).
Категория C: ожидание утверждённого и реализованного backend; реализация исключена из текущей очереди.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Будущее: реальный editor/Skip только с backend. Сейчас нет формы, локальных имён или mock save.

**Будущее, вне текущей очереди.** Не создавать временный UI/local persistence/mock. Согласованные требования сохранены в UX/BR; unblock только по backend evidence и отдельному выбору.

## Acceptance criteria

- [ ] Редактор появляется только после готового backend read/save/reset; никакого временного editor/local name store/mock save/unavailable production заглушки сейчас.
- [ ] Backend Speaker IDs/labels/canonical неизменны. Future manual/default/contact назначения сохраняются сервером, read failure не равно пустому набору.
- [ ] Future Save переходит после server confirmation, Skip открывает transcript без стирания назначений; можно открыть позднее, summary не gate.
- [ ] Unsaved input/error/offline/conflict и dirty navigation обрабатываются после реального контракта; локальное persisted имя не источник истины.
- [ ] Workspace contacts и sample интегрируют future .47/.45; без workspace manual/default. Никаких fictitious emails/profiles/автоматической identity.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Будущее требование сохраняется, но текущая версия не создаёт этот UI, API-клиент или локальную бизнес-имитацию. До actual backend contract evidence не вводить wire fields/endpoints/revision и архитектуру на вырост. Тестовые fixtures допустимы после существования соответствующего контракта; отдельный mock-репозиторий будущих назначений не обязателен и сейчас запрещён.

Scope/planned_paths — будущие пути, не команда создавать их сейчас. Backend read-only; code/tasks не реализуются этой коррекцией. Commit/push/merge запрещены текущим поручением.

## Verification

Будущие проверки после backend readiness, сейчас **NOT RUN**.

| Проверка | Статус / граница |
|---|---|
| Contract approval/implementation/actual SHA и owner authorization | NOT RUN; обязательный входной gate |
| `flutter test test/features/results/speaker_assignment_editor_test.dart` | NOT RUN; файлы planned, не существуют/не создаются сейчас |
| Scoped format/analyze, real integration и независимый review | NOT RUN; mock/prototype не заменяет backend |

## Result

2026-11-02: перенесено в будущий этап, status blocked/category C. Согласованное продуктовое требование не отменено; код этой функциональности отсутствует и не создаётся. Прежняя стратегия обязательного mock/UI/local-name prototype отменена. Фактический backend контракт ещё не предоставлен; endpoint/DTO не назначаются frontend. Приёмки нет.
