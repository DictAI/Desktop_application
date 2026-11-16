---
id: "TASK-FE-002.06"
plan: "PLAN-FE-002"
title: "Добавить iOS микрофон, background recording и audio interruptions"
status: "draft"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.05"]
scope: ["lib/features/record/data/ios_audio_capture.dart", "lib/features/record/data/audio_capture.dart", "lib/features/record/presentation/record_notifier.dart", "ios/Runner/AudioSessionBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner/Info.plist", "test/features/record/ios_audio_capture_test.dart", "docs/testing/IOS_AUDIO.ru.md", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.06.md"]
planned_paths: ["lib/features/record/data/ios_audio_capture.dart", "ios/Runner/AudioSessionBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner/Info.plist", "test/features/record/ios_audio_capture_test.dart", "docs/testing/IOS_AUDIO.ru.md", "ios/Runner.xcodeproj/project.pbxproj"]
reuses_tasks: ["TASK-FE-001.15", "TASK-FE-001.16", "TASK-FE-001.17", "TASK-FE-001.18", "TASK-FE-001.49"]
implementation_selected: false
---

# TASK-FE-002.06: Добавить iOS микрофон, background recording и audio interruptions

## Goal

Добавить iOS микрофон, background recording и audio interruptions. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.15](../tasks/TASK-FE-001.15.md), [TASK-FE-001.16](../tasks/TASK-FE-001.16.md), [TASK-FE-001.17](../tasks/TASK-FE-001.17.md), [TASK-FE-001.18](../tasks/TASK-FE-001.18.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Через существующий AudioCapture создаётся настоящий допустимый PCM WAV; Start/Pause/Resume/Stop идемпотентны, permission denial/revocation и аппаратная ошибка понятны.
- [ ] NSMicrophoneUsageDescription объясняет запись встреч. AVAudioSession category/mode/routes и background audio выбраны для активной микрофонной записи; lock screen/background проверены на iPhone, запись не начинает работать скрытно.
- [ ] Incoming call/Siri/interruption, отключение гарнитуры/Bluetooth route change, media-services reset корректно меняют состояние. Прерванная запись не выглядит активной, автоматический resume разрешён только безопасной политикой.
- [ ] Финализация ограничена по времени/памяти, dispose освобождает session/observer; файл сохранён либо честно помечен неполным, нет обещания восстановления несохранённого WAV после принудительного kill.
- [ ] iOS не вызывает MacosAudioCapture/LinuxAudioCapture, ffmpeg/parec/ScreenCaptureKit; system audio и запись телефонного звонка не предлагаются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Pinned record — первая проверяемая возможность; узкий Swift bridge только для реально отсутствующих lifecycle/session hooks, обе стороны проверять. Background mode относится к активной записи, не даёт бессрочный polling/upload.

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
| flutter test test/features/record/ios_audio_capture_test.dart; scoped format; flutter analyze; flutter build ios --simulator --debug | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Физический iPhone: реальный звук, screen lock/background, interruption/route changes, отказ mic, длинная запись; Simulator не заменяет этот smoke | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
