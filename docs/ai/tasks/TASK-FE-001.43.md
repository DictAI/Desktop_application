---
id: TASK-FE-001.43
plan: PLAN-FE-001
title: "Добавить модель назначений после готовности backend-контракта"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "3"
depends_on: ["TASK-FE-001.06", "TASK-FE-001.07", "TASK-FE-001.22"]
backend_tasks: []
backend_requests: ["BR-02", "BR-03"]
api_contracts: ["R04 (только источник ID)"]
blocked_by: ["Вне текущего этапа: нет утверждённого и реализованного backend read/save назначений и связи Speaker ID с contact (BR-02/03)."]
scope:
  - "lib/features/results/data/speaker_assignment_model.dart"
  - "test/features/results/speaker_assignment_model_test.dart"
  - "docs/ai/tasks/TASK-FE-001.43.md"
planned_paths:
  - "lib/features/results/data/speaker_assignment_model.dart"
  - "test/features/results/speaker_assignment_model_test.dart"
delivery_stage: future
---

# TASK-FE-001.43: Добавить модель назначений после готовности backend-контракта

## Goal

После готовности backend добавить только действительно нужную модель назначений по утверждённому контракту, без прототипа/mock-репозитория заранее.

Будущий этап, реализация не выбрана до backend evidence.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md), [TASK-FE-001.22](TASK-FE-001.22.md).
Категория C: ожидание утверждённого и реализованного backend; реализация исключена из текущей очереди.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Будущее: модель только после утверждённого реализованного backend. Обязательный mock/repository prototype исключён.

**Будущее, вне текущей очереди.** Не создавать временный UI/local persistence/mock. Согласованные требования сохранены в UX/BR; unblock только по backend evidence и отдельному выбору.

## Acceptance criteria

- [ ] Начинать только после утверждённого и реализованного backend read/save/reset и contact association контракта BR-02/03, с actual SHA и owner backend.
- [ ] Модель отражает фактический contract и recording-local Speaker ID; никаких назначенных заранее wire/revision полей или canonical mutation.
- [ ] Отдельный repository/interface создаётся лишь при конкретной необходимости готовой интеграции; обязательный mock/dev/unavailable provider/prototype исключён.
- [ ] Backend остаётся authoritative для сохранённых имён; ни local persistence, ни тестовые данные не подменяют server success.
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
| `flutter test test/features/results/speaker_assignment_model_test.dart` | NOT RUN; файлы planned, не существуют/не создаются сейчас |
| Scoped format/analyze, real integration и независимый review | NOT RUN; mock/prototype не заменяет backend |

## Result

2026-11-02: перенесено в будущий этап, status blocked/category C. Согласованное продуктовое требование не отменено; код этой функциональности отсутствует и не создаётся. Прежняя стратегия обязательного mock/UI/local-name prototype отменена. Фактический backend контракт ещё не предоставлен; endpoint/DTO не назначаются frontend. Приёмки нет.
