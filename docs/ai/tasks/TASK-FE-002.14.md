---
id: "TASK-FE-002.14"
plan: "PLAN-FE-002"
title: "Экспортировать документы и WAV через iOS Files/share sheet"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.13"]
scope: ["lib/features/results/data/ios_document_export.dart", "lib/features/results/presentation/result_detail_screen.dart", "lib/features/results/presentation/results_screen.dart", "ios/Runner/DocumentExportBridge.swift", "ios/Runner/AppDelegate.swift", "test/features/results/ios_document_export_test.dart", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.14.md", "test/features/results/ios_media_smoke_app.dart", "docs/testing/IOS_MEDIA.ru.md"]
planned_paths: ["lib/features/results/data/ios_document_export.dart", "lib/features/results/presentation/result_detail_screen.dart", "ios/Runner/DocumentExportBridge.swift", "ios/Runner/AppDelegate.swift", "test/features/results/ios_document_export_test.dart", "ios/Runner.xcodeproj/project.pbxproj", "test/features/results/ios_media_smoke_app.dart", "docs/testing/IOS_MEDIA.ru.md"]
reuses_tasks: ["TASK-FE-001.30", "TASK-FE-001.31"]
implementation_selected: true
---

# TASK-FE-002.14: Экспортировать документы и WAV через iOS Files/share sheet

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Экспортировать документы и WAV через iOS Files/share sheet. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.30](../tasks/TASK-FE-001.30.md), [TASK-FE-001.31](../tasks/TASK-FE-001.31.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Transcript TXT/PDF, summary TXT/PDF и original WAV доступны только по реальной готовности соответствующего документа.
- [ ] Авторизованный download сохраняет server bytes; временный owned file передаётся в системный share/Save to Files без публичных token URLs и macOS open/Linux xdg-open.
- [ ] Filename/MIME/cancel/provider failure корректны; файл живёт до завершения system activity, очистка не удаляет пользовательский export.
- [ ] Большие файлы не загружаются целиком в память и не выставляют контейнер приложения для общего доступа без необходимости; iPad popover anchor безопасен.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Первый вариант — узкий native bridge UIActivityViewController/документный export с обеими сторонами MethodChannel. Новый package возможен только с отдельным обоснованным scope.

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
| flutter test test/features/results/ios_document_export_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: Save to Files/share/cancel, offline download, TXT/PDF/WAV, сохранённые bytes; iPad Simulator popover smoke | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
