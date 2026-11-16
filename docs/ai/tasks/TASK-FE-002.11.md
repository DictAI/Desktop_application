---
id: "TASK-FE-002.11"
plan: "PLAN-FE-002"
title: "Добавить единый мобильный экран результата"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.10"]
scope: ["lib/features/results/presentation/result_detail_screen.dart", "lib/features/results/presentation/result_detail_notifier.dart", "lib/features/results/presentation/results_screen.dart", "lib/features/record/presentation/record_screen.dart", "lib/core/router/app_router.dart", "lib/shared/providers/providers.dart", "test/features/results/ios_result_detail_test.dart", "docs/ai/tasks/TASK-FE-002.11.md"]
planned_paths: ["lib/features/results/presentation/result_detail_screen.dart", "lib/features/results/presentation/result_detail_notifier.dart", "test/features/results/ios_result_detail_test.dart"]
reuses_tasks: ["TASK-FE-001.22", "TASK-FE-001.28", "TASK-FE-001.30"]
implementation_selected: false
---

# TASK-FE-002.11: Добавить единый мобильный экран результата

## Goal

Добавить единый мобильный экран результата. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.22](../tasks/TASK-FE-001.22.md), [TASK-FE-001.28](../tasks/TASK-FE-001.28.md), [TASK-FE-001.30](../tasks/TASK-FE-001.30.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Route /results/:audioId с optional job_id доступен из записи/библиотеки под существующим auth guard и восстанавливается по идентификаторам.
- [ ] Queued/running/202, failed/no_speech/404/503 и доступность canonical/summary/documents независимы; original WAV не gate транскрипта.
- [ ] Пользователь видит реальный текст canonical, затем .12 завершает большой viewer; summary берётся существующим document API, её ожидание не скрывает transcript.
- [ ] Back/повторное открытие/late response не создают upload и дополнительный вечный poll; отсутствие job_id разрешается только действующим контрактом.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Не создавать assignments editor или недоступную заглушку. Код больших transcript/player/share идёт последовательными .12/.13/.14.

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
| flutter test test/features/results/ios_result_detail_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Simulator: Record/Results → detail → Back; 200/202/404/503/no_speech на контролируемых fixtures | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
