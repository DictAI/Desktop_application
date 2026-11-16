---
id: "TASK-FE-002.19"
plan: "PLAN-FE-002"
title: "Подготовить iOS candidate и требования TestFlight/App Store"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.18"]
scope: ["docs/testing/IOS_RELEASE.ru.md", "ios/Runner/PrivacyInfo.xcprivacy", "ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.19.md"]
planned_paths: ["docs/testing/IOS_RELEASE.ru.md", "ios/Runner/PrivacyInfo.xcprivacy", "ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj"]
reuses_tasks: ["TASK-FE-001.41", "TASK-FE-001.42"]
implementation_selected: false
---

# TASK-FE-002.19: Подготовить iOS candidate и требования TestFlight/App Store

## Goal

Подготовить iOS candidate и требования TestFlight/App Store. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.41](../tasks/TASK-FE-001.41.md), [TASK-FE-001.42](../tasks/TASK-FE-001.42.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Подготовлен воспроизводимый candidate по проверенному .18, указаны version/build, bundle ID, deployment target, signing owner и evidence архива/валидации.
- [ ] Проверены permission strings, privacy manifest/required reason API и фактический сбор данных приложением/SDK, политика записей/хранения и export compliance; значения не выдуманы.
- [ ] Для публикации проверены App Store privacy/support URLs, review access и текущие требования к удалению аккаунта для приложения с регистрацией; отсутствующая backend возможность явно release blocker, без придуманного endpoint.
- [ ] TestFlight/App Store upload, внешние приглашения, сертификаты/profiles и выпуск выполняются только по отдельному разрешению владельца; готовый checklist не равен публикации.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Публичный релиз не входит в запрос на перепланирование. Если владелец пока выбирает локальную установку, требования Store остаются явно отдельным gate, а отсутствие backend account deletion не скрывается.

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
| flutter build ipa --release — только при доступных signing/team/config; иначе NOT RUN с blocker | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Проверить archive/privacy/project diff и release checklist; локальная готовность, TestFlight validation и App Store approval различаются | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
