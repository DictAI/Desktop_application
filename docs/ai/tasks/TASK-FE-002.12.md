---
id: "TASK-FE-002.12"
plan: "PLAN-FE-002"
title: "Показать большой транскрипт с говорящими и таймкодами"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.11"]
scope: ["lib/features/results/presentation/transcript_view.dart", "lib/features/results/presentation/result_detail_screen.dart", "test/features/results/ios_transcript_test.dart", "docs/ai/tasks/TASK-FE-002.12.md"]
planned_paths: ["lib/features/results/presentation/transcript_view.dart", "lib/features/results/presentation/result_detail_screen.dart", "test/features/results/ios_transcript_test.dart"]
reuses_tasks: ["TASK-FE-001.29"]
implementation_selected: false
---

# TASK-FE-002.12: Показать большой транскрипт с говорящими и таймкодами

## Goal

Показать большой транскрипт с говорящими и таймкодами. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.29](../tasks/TASK-FE-001.29.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Показаны исходные backend Speaker ID/labels, UNKNOWN, порядок, overlap и timings из integer microseconds; имена не выдумываются.
- [ ] Lazy UI и ограниченное потребление памяти выдерживают canonical до существующего artifact limit 50 MiB; масштабирование текста, scroll/selection и VoiceOver остаются пригодны на iPhone.
- [ ] No_speech — успешное пустое состояние; отсутствие/некорректный timing не подменяется нулём или выдуманным временем.
- [ ] Нет rename/contact assignment/canonical merge/split или зависимости от будущего names API.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Сохранить DTO и пределы API; fixture stress не доказывает качество модели или работу backend.

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
| flutter test test/features/results/ios_transcript_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: synthetic large canonical memory/scroll, text scale/VoiceOver; реальный transcript проверяется в .18 | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
