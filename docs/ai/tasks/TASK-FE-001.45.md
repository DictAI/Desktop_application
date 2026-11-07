---
id: TASK-FE-001.45
plan: PLAN-FE-001
title: "Воспроизводить первый подходящий фрагмент Speaker из canonical"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "3"
depends_on: ["TASK-FE-001.22", "TASK-FE-001.44"]
backend_tasks: []
backend_requests: ["BR-05"]
api_contracts: ["R04", "U04"]
blocked_by: ["Продуктово отложено вместе с редактором .46 до backend назначений. R04/U04 уже есть; общий player/таймкоды остаются .44/.29."]
scope:
  - "lib/features/results/data/speaker_sample_selector.dart"
  - "lib/features/results/presentation/speaker_sample_controller.dart"
  - "lib/features/results/presentation/speaker_sample_button.dart"
  - "test/features/results/speaker_sample_selector_test.dart"
  - "test/features/results/speaker_sample_playback_test.dart"
  - "docs/ai/tasks/TASK-FE-001.45.md"
planned_paths:
  - "lib/features/results/data/speaker_sample_selector.dart"
  - "lib/features/results/presentation/speaker_sample_controller.dart"
  - "lib/features/results/presentation/speaker_sample_button.dart"
  - "test/features/results/speaker_sample_selector_test.dart"
  - "test/features/results/speaker_sample_playback_test.dart"
delivery_stage: future
---

# TASK-FE-001.45: Воспроизводить первый подходящий фрагмент Speaker из canonical

## Goal

Простой выбор первой подходящей реплики по времени и локальное прослушивание без legacy fragment API и поиска «лучшего» голоса.

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

FE prerequisites: [TASK-FE-001.22](TASK-FE-001.22.md), [TASK-FE-001.44](TASK-FE-001.44.md).
Категория C: ожидание утверждённого и реализованного backend; реализация исключена из текущей очереди.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Будущее: отдельный выбор характерной реплики обслуживает редактор .46. Полный player и таймкоды остаются .44/.29.

**Будущее, вне текущей очереди.** Не создавать временный UI/local persistence/mock. Согласованные требования сохранены в UX/BR; unblock только по backend evidence и отдельному выбору.

## Acceptance criteria

- [ ] Начинать вместе с будущим редактором после готовности backend назначений; сам R04/U04 уже существует, новым clip API это не объявляется.
- [ ] По real canonical выбирается первая достаточная реплика без overlap; короткая/неподходящая пропускается, без ML/ranking/биометрии.
- [ ] Используется существующий .44 cache/player; interval/microseconds/duration/end/error проверены, нет отдельного cache на Speaker.
- [ ] Отсутствие sample не блокирует future manual/contact/default/Skip; в текущем UI этого control/алгоритма нет.
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
| `flutter test test/features/results/speaker_sample_selector_test.dart test/features/results/speaker_sample_playback_test.dart` | NOT RUN; файлы planned, не существуют/не создаются сейчас |
| Scoped format/analyze, real integration и независимый review | NOT RUN; mock/prototype не заменяет backend |

## Result

2026-11-02: перенесено в будущий этап, status blocked/category C. Согласованное продуктовое требование не отменено; код этой функциональности отсутствует и не создаётся. Прежняя стратегия обязательного mock/UI/local-name prototype отменена. Фактический backend контракт ещё не предоставлен; endpoint/DTO не назначаются frontend. Приёмки нет.
