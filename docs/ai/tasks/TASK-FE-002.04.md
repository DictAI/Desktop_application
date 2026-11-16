---
id: "TASK-FE-002.04"
plan: "PLAN-FE-002"
title: "Сделать мобильную навигацию и экран входа"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.03"]
scope: ["lib/core/shell/main_shell.dart", "lib/core/router/app_router.dart", "lib/core/router/auth_listenable.dart", "lib/features/auth/presentation/login_screen.dart", "lib/app.dart", "lib/core/theme/app_theme.dart", "test/core/router/ios_navigation_test.dart", "test/features/auth/ios_login_layout_test.dart", "docs/ai/tasks/TASK-FE-002.04.md"]
planned_paths: ["test/core/router/ios_navigation_test.dart", "test/features/auth/ios_login_layout_test.dart"]
reuses_tasks: ["TASK-FE-001.09", "TASK-FE-001.12", "TASK-FE-001.28", "TASK-FE-001.49"]
implementation_selected: false
---

# TASK-FE-002.04: Сделать мобильную навигацию и экран входа

## Goal

Сделать мобильную навигацию и экран входа. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.09](../tasks/TASK-FE-001.09.md), [TASK-FE-001.12](../tasks/TASK-FE-001.12.md), [TASK-FE-001.28](../tasks/TASK-FE-001.28.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Основные разделы Record/Results/Workspaces доступны на iPhone через мобильную навигацию; keyboard, safe areas и системный Back/swipe не обрезают действия.
- [ ] На ширине 320/375/430 logical px нет overflow; вход/регистрация работают с клавиатурой и увеличенным текстом, основные controls доступны VoiceOver.
- [ ] Auth redirects, параметры workspace и восстановление маршрута не обходят guards; desktop sidebar сохраняется при широкой компоновке без отдельной очереди desktop redesign.
- [ ] Logout доступен на телефоне; route transitions не запускают повторные upload/poll. Active-record guard доводится в .08, здесь есть регрессионная проверка существующего guard.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Сохранить Riverpod/GoRouter; bottom navigation и адаптивный layout предпочтительны собственному navigation framework. iPad получает безопасную адаптивную компоновку; отдельная iPad-оптимизация вне первого этапа.

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
| flutter test test/core/router/ios_navigation_test.dart test/features/auth/ios_login_layout_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Simulator: keyboard/safe area/back, text scale и доступность основного пути | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
