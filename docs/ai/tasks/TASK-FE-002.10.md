---
id: "TASK-FE-002.10"
plan: "PLAN-FE-002"
title: "Адаптировать библиотеку результатов и восстановление отправок"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.09"]
scope: ["lib/features/results/presentation/results_screen.dart", "lib/features/results/presentation/results_notifier.dart", "test/features/results/ios_results_library_test.dart", "docs/ai/tasks/TASK-FE-002.10.md"]
planned_paths: ["test/features/results/ios_results_library_test.dart"]
reuses_tasks: ["TASK-FE-001.26", "TASK-FE-001.27"]
implementation_selected: false
---

# TASK-FE-002.10: Адаптировать библиотеку результатов и восстановление отправок

## Goal

Адаптировать библиотеку результатов и восстановление отправок. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.26](../tasks/TASK-FE-001.26.md), [TASK-FE-001.27](../tasks/TASK-FE-001.27.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Список/пагинация/даты и pending uploads работают на узком экране с реальным R01 и durable journal.
- [ ] Refresh/возврат в foreground обновляет данные без повторной отправки/потери фильтра; доступен явный retry допустимых отправок.
- [ ] Различимы пустой список, offline, failed job, pending transcript/summary; done не обещает готовность всех документов.
- [ ] Состояние выбранного результата сохраняет реальные audio_id/job_id для подключения route в .11; смена аккаунта не оставляет старый список. До .11 нет действия на отсутствующий route.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Использовать существующие ResultsApi/ResultsNotifier, не создавать новый workspace filter API. Detail route добавляется в .11; до того отсутствующее действие не выдаётся за готовое.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/results/ios_results_library_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Simulator/iPhone: список с увеличенным текстом, фильтры, restore pending и navigation | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
