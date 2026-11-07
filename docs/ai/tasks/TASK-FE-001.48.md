---
id: TASK-FE-001.48
plan: PLAN-FE-001
title: "Связать готовность транскрипта с уведомлениями и навигацией"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.25", "TASK-FE-001.27", "TASK-FE-001.28", "TASK-FE-001.44"]
backend_tasks: []
backend_requests: ["BR-01", "BR-06", "BR-07"]
api_contracts: ["R01", "R03", "R04"]
blocked_by: []
scope:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "lib/core/router/app_router.dart"
  - "lib/core/shell/main_shell.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/results/readiness_navigation_test.dart"
  - "docs/ai/tasks/TASK-FE-001.48.md"
planned_paths:
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/presentation/result_detail_notifier.dart"
  - "test/features/results/readiness_navigation_test.dart"
delivery_stage: current
---

# TASK-FE-001.48: Связать готовность транскрипта с уведомлениями и навигацией

## Goal

Связать canonical readiness с показом транскрипта ожидающему, уведомлением в другом разделе и повторным открытием из Results.

Текущий этап. Реализация после завершения пересмотра и независимого review, в порядке DAG.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.44](TASK-FE-001.44.md).
Категория B: текущий UI/state по реальному API; test fakes проверяют действующий wire/оборудование и не являются runtime бизнес-реализацией.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Смешанная: сейчас готовность→транскрипт/notice/Results; переход к editor перенесён в .50. Не блокируется целиком.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] После upload202 waiting, валидный R04 200 нужного job показывает canonical transcript ожидающему именно этот результат; summary не gate.
- [ ] В другом разделе/результате нет forced navigation: ненавязчивый in-app notice открывает текущий detail/transcript, не форму назначения.
- [ ] После restart запись доступна из Results, без forced startup redirect; повторный poll/summary event не открывает её заново.
- [ ] Dedupe owner/audio/job/session, guard активной записи .49, deleted/late/чужие события не показывают данные; original unavailable не gate transcript.
- [ ] Используются текущие notifiers/Riverpod/router, без нового универсального event framework/notifications API; assignment routing в будущем добавит .50.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| `flutter test test/features/results/readiness_navigation_test.dart` | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Создана только карточка планирования; функциональный код,
API-клиенты, DTO, платформы и зависимости не менялись. Mock evidence не означает
серверного сохранения, multi-device readiness или именованного server export.
Implemented ≠ verified ≠ accepted; приёмки и разрешения публикации нет.
