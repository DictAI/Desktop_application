---
id: TASK-FE-001.51
plan: PLAN-FE-001
title: "Интегрировать экспорт TXT/PDF с сохранёнными именами"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "5"
depends_on: ["TASK-FE-001.31", "TASK-FE-001.50"]
backend_tasks: []
backend_requests: ["BR-04"]
api_contracts: []
blocked_by: ["Вне текущего этапа: нет backend назначений и утверждённого/реализованного BR-04 для именованных документов/freshness."]
scope:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/named_exports_api.dart"
  - "lib/features/results/data/dto/named_export_wire_dto.dart"
  - "lib/features/results/data/named_export_state.dart"
  - "lib/features/results/data/export_service.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/named_export_test.dart"
  - "docs/ai/tasks/TASK-FE-001.51.md"
planned_paths:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/named_exports_api.dart"
  - "lib/features/results/data/dto/named_export_wire_dto.dart"
  - "lib/features/results/data/named_export_state.dart"
  - "lib/features/results/data/export_service.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "test/features/results/named_export_test.dart"
delivery_stage: future
---

# TASK-FE-001.51: Интегрировать экспорт TXT/PDF с сохранёнными именами

## Goal

Все применимые экспортируемые transcript/summary TXT/PDF отражают подтверждённые имена; старые Speaker N bytes не выдаются за обновлённые.

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

FE prerequisites: [TASK-FE-001.31](TASK-FE-001.31.md), [TASK-FE-001.50](TASK-FE-001.50.md).
Категория C: реализация/завершение ждут внешнего согласованного и реализованного backend-контракта.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Будущее: именованные TXT/PDF после backend; существующий raw export остаётся .31.

**Будущее, вне текущей очереди.** Не создавать временный UI/local persistence/mock. Согласованные требования сохранены в UX/BR; unblock только по backend evidence и отдельному выбору.

## Acceptance criteria

- [ ] До реализации backend согласовал и реализовал BR-04 для transcript.txt/pdf и summary.txt/pdf: применение historical snapshot имён, поздние изменения, доступность/freshness документов, failure/cache/concurrency semantics; новый endpoint не обязателен и не назначается frontend заранее.
- [ ] UI/export client отличают готовый актуальный документ от старой/строящейся/failed редакции по принятому contract delta; запрос с ожидаемыми именами не сохраняет молча старые bytes. Четыре kinds и summary independent доступны по их реальным статусам.
- [ ] Имена применяются там, где документ ссылается на соответствующего Speaker, без blind string replace spoken text/цитат/имён других людей и без выдуманного повторного ASR/LLM processing API.
- [ ] Skip/Speaker N корректны; позднее назначение/переименование обновляет применимые документы по контракту. Summary pending/failed не блокирует transcript/naming; именованные summary документы проверяются после фактической готовности.
- [ ] Есть escaping безопасного user text для TXT/PDF/Typst и проверка owner/job/назначений. Original WAV не изменяется, повторной отправки писем/новых recipients не обещать.
- [ ] Реальные четыре named documents и обновление после late rename подтверждены evidence .51 на разрешённом стенде по будущему контракту; mock rendering, локальная подмена PDF или новая зависимость не заменяют backend.
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
| `flutter test test/features/results/named_export_test.dart` | NOT RUN; файлы planned, не существуют/не создаются сейчас |
| Scoped format/analyze, real integration и независимый review | NOT RUN; mock/prototype не заменяет backend |

## Result

2026-11-02: перенесено в будущий этап, status blocked/category C. Согласованное продуктовое требование не отменено; код этой функциональности отсутствует и не создаётся. Прежняя стратегия обязательного mock/UI/local-name prototype отменена. Фактический backend контракт ещё не предоставлен; endpoint/DTO не назначаются frontend. Приёмки нет.
