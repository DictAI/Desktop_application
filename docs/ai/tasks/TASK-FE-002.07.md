---
id: "TASK-FE-002.07"
plan: "PLAN-FE-002"
title: "Импортировать WAV из Files в sandbox приложения"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.06"]
scope: ["lib/features/record/data/ios_wav_import.dart", "lib/features/record/presentation/upload_modal.dart", "lib/features/record/data/wav_validator.dart", "ios/Runner/DocumentImportBridge.swift", "ios/Runner/AppDelegate.swift", "test/features/record/ios_wav_import_test.dart", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.07.md"]
planned_paths: ["lib/features/record/data/ios_wav_import.dart", "ios/Runner/DocumentImportBridge.swift", "ios/Runner/AppDelegate.swift", "test/features/record/ios_wav_import_test.dart", "ios/Runner.xcodeproj/project.pbxproj"]
reuses_tasks: ["TASK-FE-001.18", "TASK-FE-001.23", "TASK-FE-001.31"]
implementation_selected: false
---

# TASK-FE-002.07: Импортировать WAV из Files в sandbox приложения

## Goal

Импортировать WAV из Files в sandbox приложения. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.18](../tasks/TASK-FE-001.18.md), [TASK-FE-001.23](../tasks/TASK-FE-001.23.md), [TASK-FE-001.31](../tasks/TASK-FE-001.31.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Files picker принимает WAV из локальных Files/iCloud/provider; отмена и provider download/error не создают отправку.
- [ ] Выбранный внешний URL/временный путь копируется в принадлежащий приложению sandbox, security-scoped access ограничен временем операции; произвольный путь не считается постоянным.
- [ ] Валидируются реальные WAV bytes и существующие лимиты, не только расширение; большой файл обрабатывается потоком без полной копии в Dart memory.
- [ ] M4A/MP3 и неподдержанный WAV получают понятную ошибку без фиктивного переименования/ffmpeg; partial copy/disk full очищаются, оригинал пользователя не удаляется.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Использовать существующий file_picker, проверив фактическую iOS семантику пути/copy. Native bridge создавать лишь при необходимости; новые document UTTypes не обещают поддержку новых кодеков.

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
| flutter test test/features/record/ios_wav_import_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone Files: локальный/iCloud WAV, cancel, missing provider/offline, большой файл и недостаток места | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
