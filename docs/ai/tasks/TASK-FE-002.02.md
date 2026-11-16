---
id: "TASK-FE-002.02"
plan: "PLAN-FE-002"
title: "Добавить iOS Runner и воспроизводимую simulator-сборку"
status: "draft"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.01"]
scope: ["ios/.gitignore", "ios/Podfile", "ios/Flutter/AppFrameworkInfo.plist", "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig", "ios/Runner/AppDelegate.swift", "ios/Runner/SceneDelegate.swift", "ios/Runner/Runner-Bridging-Header.h", "ios/Runner/Info.plist", "ios/Runner/Base.lproj/LaunchScreen.storyboard", "ios/Runner/Base.lproj/Main.storyboard", "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme", "ios/Runner.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/RunnerTests/RunnerTests.swift", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md", ".metadata", "docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "docs/ai/tasks/TASK-FE-002.02.md"]
planned_paths: ["ios/.gitignore", "ios/Podfile", "ios/Flutter/AppFrameworkInfo.plist", "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig", "ios/Runner/AppDelegate.swift", "ios/Runner/SceneDelegate.swift", "ios/Runner/Runner-Bridging-Header.h", "ios/Runner/Info.plist", "ios/Runner/Base.lproj/LaunchScreen.storyboard", "ios/Runner/Base.lproj/Main.storyboard", "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme", "ios/Runner.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/RunnerTests/RunnerTests.swift", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md", "docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"]
reuses_tasks: ["TASK-FE-001.01", "TASK-FE-001.05", "TASK-FE-001.36"]
implementation_selected: false
---

# TASK-FE-002.02: Добавить iOS Runner и воспроизводимую simulator-сборку

## Goal

Добавить iOS Runner и воспроизводимую simulator-сборку. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.01](../tasks/TASK-FE-001.01.md), [TASK-FE-001.05](../tasks/TASK-FE-001.05.md), [TASK-FE-001.36](../tasks/TASK-FE-001.36.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Runner создан pinned Flutter SDK с deployment target из .01; есть воспроизводимая команда сборки и проверенный вход в существующее приложение.
- [ ] Перед генерацией .01 уточняет полный exact manifest .02: перечисленные здесь пути — кандидаты шаблона, лишние не создаются; новые пути сначала документируются. Generated registrants вручную не редактируются.
- [ ] Обоснованы bundle identifier, capabilities и plist; нет широких ATS exceptions, лишних permission prompts или встроенных секретов. Команда/подпись владельца не подменены случайными значениями.
- [ ] flutter build ios --simulator --debug выполнен либо записан конкретный внешний blocker; сборка не объявляется работающим микрофоном или backend E2E.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Платформенный scaffold; бизнес-экраны остаются для следующих задач. Если сборка требует изменения lock/dependencies, сначала зафиксировать конкретную необходимость в scope и получить решение, не обновлять всё автоматически.

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
| flutter build ios --simulator --debug — macOS/Xcode, подготовленные pinned dependencies, API_BASE_URL из разрешённой конфигурации | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Проверить plist/project/deployment target и полный generated diff; ios/Pods, ephemeral и локальная подпись не tracked | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
