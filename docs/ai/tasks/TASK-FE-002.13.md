---
id: "TASK-FE-002.13"
plan: "PLAN-FE-002"
title: "Добавить iOS аудиоплеер и принадлежащий аккаунту cache"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.12"]
scope: ["lib/features/results/presentation/audio_player.dart", "lib/features/results/data/original_audio_cache.dart", "lib/features/results/presentation/result_detail_screen.dart", "ios/Runner/AudioSessionBridge.swift", "test/features/results/ios_audio_player_test.dart", "docs/ai/tasks/TASK-FE-002.13.md"]
planned_paths: ["lib/features/results/presentation/audio_player.dart", "lib/features/results/data/original_audio_cache.dart", "lib/features/results/presentation/result_detail_screen.dart", "ios/Runner/AudioSessionBridge.swift", "test/features/results/ios_audio_player_test.dart"]
reuses_tasks: ["TASK-FE-001.30", "TASK-FE-001.44"]
implementation_selected: false
---

# TASK-FE-002.13: Добавить iOS аудиоплеер и принадлежащий аккаунту cache

## Goal

Добавить iOS аудиоплеер и принадлежащий аккаунту cache. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.30](../tasks/TASK-FE-001.30.md), [TASK-FE-001.44](../tasks/TASK-FE-001.44.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Реальный original WAV скачивается авторизованным DocumentsApi и поддерживает Play/Pause/seek с фактической длительностью.
- [ ] Cache ограничен объёмом и принадлежит account/audio/job; partial download, hash/length где доступны и network error не воспроизводятся как готовый файл.
- [ ] Audio session координируется с capture; start recording останавливает playback, interruption/наушники/lock/resume не запускают звук неожиданно.
- [ ] Нет обещания фонового плеера/lock screen controls: для первого этапа playback останавливается при уходе в background; активная background запись из .06 сохраняется.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Переиспользовать audioplayers, не вводить новую media dependency автоматически. Сегментный sample/editor будущего этапа не нужен текущему player.

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
| flutter test test/features/results/ios_audio_player_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: звук/seek, Bluetooth route change, playback→record, lock/background и account change | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
