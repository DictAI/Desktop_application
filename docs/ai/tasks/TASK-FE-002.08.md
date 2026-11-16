---
id: "TASK-FE-002.08"
plan: "PLAN-FE-002"
title: "Собрать мобильный экран записи и безопасный Stop/уход"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.07"]
scope: ["lib/features/record/presentation/record_screen.dart", "lib/features/record/presentation/record_notifier.dart", "lib/features/record/presentation/finish_recording_dialog.dart", "lib/features/record/presentation/record_exit_guard.dart", "lib/core/router/app_router.dart", "test/features/record/ios_record_flow_test.dart", "docs/ai/tasks/TASK-FE-002.08.md"]
planned_paths: ["test/features/record/ios_record_flow_test.dart"]
reuses_tasks: ["TASK-FE-001.23", "TASK-FE-001.24", "TASK-FE-001.49"]
implementation_selected: false
---

# TASK-FE-002.08: Собрать мобильный экран записи и безопасный Stop/уход

## Goal

Собрать мобильный экран записи и безопасный Stop/уход. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.23](../tasks/TASK-FE-001.23.md), [TASK-FE-001.24](../tasks/TASK-FE-001.24.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] На iPhone доступны mic/импорт WAV, workspace/без него и действующие language/mixed options; неподдерживаемый system audio скрыт, выбор snapshot фиксируется до Start.
- [ ] Record/Pause/Resume/Stop, таймер и ошибки отражают реальное состояние capture, не декоративную анимацию/фиктивные проценты.
- [ ] Stop, вкладки, Back/swipe и уход из workspace вызывают единое подтверждение: продолжить сохраняет запись, завершить даёт один finalized WAV и одну отправку; double tap безопасен.
- [ ] Блокировка/сворачивание не трактуется как подтверждённый Stop; interruption state приходит из .06. Политика принудительного logout отдельно безопасно освобождает recorder.
- [ ] Нет overflow на малом iPhone/landscape/увеличенном тексте; controls понятны VoiceOver и имеют удобную область касания.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Оба режима записи используют общий V2 flow. Anonymous означает без workspace, не без авторизации; legacy confirm не подключать.

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
| flutter test test/features/record/ios_record_flow_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: Stop cancel/confirm, swipe/back/tab, permission prompt, lock/unlock, interruption и отсутствие double upload | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
