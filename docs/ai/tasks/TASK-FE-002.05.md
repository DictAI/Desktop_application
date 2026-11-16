---
id: "TASK-FE-002.05"
plan: "PLAN-FE-002"
title: "Адаптировать workspaces и контакты для iPhone"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.04"]
scope: ["lib/features/workspace/presentation/workspaces_screen.dart", "lib/features/workspace/presentation/workspace_detail_screen.dart", "lib/features/workspace/presentation/workspace_notifier.dart", "test/features/workspace/ios_workspace_test.dart", "docs/ai/tasks/TASK-FE-002.05.md"]
planned_paths: ["test/features/workspace/ios_workspace_test.dart"]
reuses_tasks: ["TASK-FE-001.10", "TASK-FE-001.11", "TASK-FE-001.12", "TASK-FE-001.13", "TASK-FE-001.14"]
implementation_selected: false
---

# TASK-FE-002.05: Адаптировать workspaces и контакты для iPhone

## Goal

Адаптировать workspaces и контакты для iPhone. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.10](../tasks/TASK-FE-001.10.md), [TASK-FE-001.11](../tasks/TASK-FE-001.11.md), [TASK-FE-001.12](../tasks/TASK-FE-001.12.md), [TASK-FE-001.13](../tasks/TASK-FE-001.13.md), [TASK-FE-001.14](../tasks/TASK-FE-001.14.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Список, создание/переименование workspace и CRUD name/email contacts доступны одной рукой, с клавиатурой и увеличенным текстом.
- [ ] Новая запись переносит корректный workspace; можно записывать без workspace под авторизованным владельцем.
- [ ] Loading/empty/error/повтор и удаление контакта отображаются по реальным ответам, поздний ответ после logout не показывает данные.
- [ ] Нет запроса системной адресной книги, voice profiles или Speaker assignments; текущие contacts API сохраняются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Это адаптация существующего CRUD, не новая интеграция backend. Системные iOS Contacts не требуются.

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
| flutter test test/features/workspace/ios_workspace_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Simulator: workspace → новая запись, формы с клавиатурой, VoiceOver focus | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
