---
id: "TASK-FE-002.09"
plan: "PLAN-FE-002"
title: "Адаптировать upload и восстановление к iOS suspend/resume"
status: "draft"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.08"]
scope: ["lib/features/record/presentation/record_notifier.dart", "lib/features/record/data/pending_upload_store.dart", "lib/features/results/data/pending_job_store.dart", "lib/features/results/presentation/processing_notifier.dart", "lib/shared/providers/providers.dart", "lib/core/lifecycle/ios_lifecycle_observer.dart", "test/features/record/ios_upload_recovery_test.dart", "docs/ai/tasks/TASK-FE-002.09.md"]
planned_paths: ["lib/core/lifecycle/ios_lifecycle_observer.dart", "test/features/record/ios_upload_recovery_test.dart"]
reuses_tasks: ["TASK-FE-001.19", "TASK-FE-001.20", "TASK-FE-001.21", "TASK-FE-001.22", "TASK-FE-001.25", "TASK-FE-001.34"]
implementation_selected: false
---

# TASK-FE-002.09: Адаптировать upload и восстановление к iOS suspend/resume

## Goal

Адаптировать upload и восстановление к iOS suspend/resume. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.19](../tasks/TASK-FE-001.19.md), [TASK-FE-001.20](../tasks/TASK-FE-001.20.md), [TASK-FE-001.21](../tasks/TASK-FE-001.21.md), [TASK-FE-001.22](../tasks/TASK-FE-001.22.md), [TASK-FE-001.25](../tasks/TASK-FE-001.25.md), [TASK-FE-001.34](../tasks/TASK-FE-001.34.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Перед отправкой durable journal владеет копией WAV/options/key; временный picker/capture path не единственная сохраняемая ссылка.
- [ ] При suspend/network loss/termination pending upload сохраняется; после resume/relaunch проверяется результат и используется тот же Idempotency-Key, после сохранённого 202 восстанавливается job polling без повторной загрузки.
- [ ] UI различает byte upload, queued/running/terminal и unknown outcome; нет обещания фоновой передачи на обычном Dio или постоянно работающего Timer в фоне.
- [ ] Polling приостанавливается/возобновляется по iOS lifecycle и текущей сессии без duplicate timers/requests; late completion после logout отбрасывается.
- [ ] Offline retry/backoff ограничен; file protection при lock и закрытый файл дают безопасную ошибку/отложенное восстановление, данные следующего аккаунта не открываются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Нативный background URLSession/новые backend API не добавляются автоматически. Отправка восстанавливается при возвращении приложения; долгий background recording не означает долгий background network.

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
| flutter test test/features/record/ios_upload_recovery_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: airplane mode во время upload, background/kill/relaunch до ответа и после 202; нет duplicate job по журналу и backend evidence | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
