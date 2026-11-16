---
id: "TASK-FE-002.01"
plan: "PLAN-FE-002"
title: "Зафиксировать iOS toolchain, deployment target и manifest Runner"
status: "ready"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: []
scope: ["docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "docs/ai/tasks/TASK-FE-002.01.md"]
planned_paths: ["docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md"]
reuses_tasks: ["TASK-FE-001.01", "TASK-FE-001.16", "TASK-FE-001.36"]
implementation_selected: false
---

# TASK-FE-002.01: Зафиксировать iOS toolchain, deployment target и manifest Runner

## Goal

Зафиксировать iOS toolchain, deployment target и manifest Runner. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.01](../tasks/TASK-FE-001.01.md), [TASK-FE-001.16](../tasks/TASK-FE-001.16.md), [TASK-FE-001.36](../tasks/TASK-FE-001.36.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Зафиксированы фактически доступные Flutter/Dart/Xcode/CocoaPods, simulator/device, совместимость pinned record, audioplayers, secure storage, file picker и path provider; отсутствие инструмента отмечено NOT RUN/blocker.
- [ ] Выбран минимальный iOS deployment target по требованиям pinned SDK/плагинов и обоснован доступными источниками; версия не выдумана заранее и SDK/lock не обновлены.
- [ ] Описаны команды генерации Runner текущим SDK и полный список создаваемых tracked файлов; manifest согласован с exact scope .02 до записи scaffold.
- [ ] Разделены simulator build, реальная запись на iPhone и подписанный candidate; bundle identifier/team/signing перечислены как решения/доступы, секреты не записаны.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Первый безопасный шаг реализации iOS-направления. Только аудит и два документа; не генерировать ios/, не менять зависимости/подпись. Инвентаризацию шаблона можно получить в изолированном временном каталоге без backend.

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
| flutter --version; dart --version; xcodebuild -version; pod --version; xcrun simctl list devices available — только доступное окружение, без изменения SDK | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Сверить pubspec.yaml/pubspec.lock/.metadata и manifest paths; отметить host/device/team blockers | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
