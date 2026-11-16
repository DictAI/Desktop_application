---
id: "TASK-FE-002.17"
plan: "PLAN-FE-002"
title: "Закрепить iOS batch-сценарий регрессионными проверками"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.16"]
scope: ["test/features/ios_batch_regression_test.dart", "test/support/fakes.dart", "docs/testing/IOS_REGRESSION.ru.md", "docs/ai/tasks/TASK-FE-002.17.md"]
planned_paths: ["test/features/ios_batch_regression_test.dart", "docs/testing/IOS_REGRESSION.ru.md"]
reuses_tasks: ["TASK-FE-001.06", "TASK-FE-001.35", "TASK-FE-001.38"]
implementation_selected: false
---

# TASK-FE-002.17: Закрепить iOS batch-сценарий регрессионными проверками

## Goal

Закрепить iOS batch-сценарий регрессионными проверками. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.06](../tasks/TASK-FE-001.06.md), [TASK-FE-001.35](../tasks/TASK-FE-001.35.md), [TASK-FE-001.38](../tasks/TASK-FE-001.38.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Набор покрывает login/workspace→mic или Files→WAV validation→upload/202→canonical→player/export→delete/logout по существующим контрактам.
- [ ] Проверены permission refusal/interruption/suspend/network failure/unknown upload outcome/restart/account change; нет пустых tests и runtime demo mocks.
- [ ] Fixtures синтетические, virtual timers/fakes не читают настоящий Keychain/микрофон/API; unit/widget и opt-in device E2E разделены.
- [ ] Подготовлен opt-in ручной device/backend harness с точными шагами, предусловиями и evidence для .18; автоматизированный unit/widget regression не зависит от новых packages.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Существующий flutter_test используется для регрессии, device/backend сценарии фиксируются как воспроизводимый ручной opt-in harness. Новая зависимость integration_test и pubspec/lock изменения в этот scope не входят. Переход к автоматизации device E2E возможен отдельным выбранным расширением, не является скрытым prerequisite.

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
| flutter test --no-pub; flutter analyze --no-pub; dart format --output=none --set-exit-if-changed lib test — подготовленные зависимости | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Сверка ручного IOS_REGRESSION device/backend harness с каждым критерием .18 и действующими API | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
