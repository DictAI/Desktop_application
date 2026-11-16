---
id: "TASK-FE-002.15"
plan: "PLAN-FE-002"
title: "Связать готовность результата с lifecycle и уведомлением внутри приложения"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.14"]
scope: ["lib/features/results/presentation/processing_notifier.dart", "lib/features/results/presentation/result_ready_notice.dart", "lib/core/shell/main_shell.dart", "lib/core/lifecycle/ios_lifecycle_observer.dart", "lib/shared/providers/providers.dart", "test/features/results/ios_ready_notice_test.dart", "docs/ai/tasks/TASK-FE-002.15.md"]
planned_paths: ["lib/features/results/presentation/result_ready_notice.dart", "lib/core/lifecycle/ios_lifecycle_observer.dart", "test/features/results/ios_ready_notice_test.dart"]
reuses_tasks: ["TASK-FE-001.25", "TASK-FE-001.48"]
implementation_selected: false
---

# TASK-FE-002.15: Связать готовность результата с lifecycle и уведомлением внутри приложения

## Goal

Связать готовность результата с lifecycle и уведомлением внутри приложения. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.25](../tasks/TASK-FE-001.25.md), [TASK-FE-001.48](../tasks/TASK-FE-001.48.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Ожидающий пользователь получает готовый canonical независимо от summary; другой раздел показывает одно in-app сообщение с переходом, без внезапной смены экрана.
- [ ] После suspended/terminated состояния приложение перечитывает текущие jobs; библиотека восстанавливает результат без вечного background polling и startup redirect.
- [ ] Notification/navigation использует текущие account/audio/job; повторный resume не дублирует notice и не открывает предыдущую сессию.
- [ ] Нет push/APNs/local notification permission или обещания уведомления при закрытом приложении; это отдельное будущее продуктовое решение.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

In-app notice не требует backend push capability. Не открывать несуществующий names editor.

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
| flutter test test/features/results/ios_ready_notice_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: ожидание/другая вкладка/background/relaunch/смена аккаунта | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
