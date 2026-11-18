---
id: "TASK-FE-002.19"
plan: "PLAN-FE-002"
title: "Подготовить iOS candidate и требования TestFlight/App Store"
status: "blocked"
owner: "/root"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.18"]
scope: ["docs/testing/IOS_RELEASE.ru.md", "ios/Runner/PrivacyInfo.xcprivacy", "ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.19.md"]
planned_paths: ["docs/testing/IOS_RELEASE.ru.md", "ios/Runner/PrivacyInfo.xcprivacy"]
reuses_tasks: ["TASK-FE-001.41", "TASK-FE-001.42"]
implementation_selected: true
---

# TASK-FE-002.19: Подготовить iOS candidate и требования TestFlight/App Store

## Текущий результат и blocker — 2026-11-18

Пользователь поручил завершить доступный объём ранее выбранной очереди и push;
owner `/root`. Подготовлен [release checklist](../../testing/IOS_RELEASE.ru.md)
по read-only audit `/root/readiness_audit`; candidate не сформирован.

**Blocked:** обязательный hardware/backend gate .18 не пройден, signing/team
отсутствуют; не назначены проверенные privacy/support URLs, review access,
release privacy answers/manifest allowed reasons и Store ownership. В backend
`92ad6e4572a3b12a601ba3ab7e5cc385a21694ae` нет auth/gateway HTTP удаления аккаунта;
DB DeleteUser helper, result deletion и logout его не заменяют. Это отдельный
release blocker, без придуманного endpoint или новой backend задачи.

До выполнения .18 и предоставления проверяемых release inputs native project,
Info.plist и PrivacyInfo.xcprivacy не менялись; manifest не заполняется выдуманными
reason codes. Не создавались сертификаты/profiles, signed archive и Store upload.
Commit/push исходников разрешены текущим поручением, release отдельно не поручен.

## Verification текущего prerequisite scope

Cwd frontend `/Users/mxdnght/dictai-app`; macOS26.5.2 arm64/Xcode26.5;
backend `/Users/mxdnght/dictai` изучен read-only.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| Source pubspec/Runner plist/project/locked SDK manifests review | version1.0.0+1, bundle com.dictai.app, iOS13; mic/audio background заданы, app privacy manifest отсутствует | PASS source inventory | Не Store validation |
| `security find-identity -v -p codesigning`; project DEVELOPMENT_TEAM | 0 valid identities; team не назначен | PASS inventory | Signed archive blocked |
| Current auth/gateway routers + deletion capability search | HTTP account deletion отсутствует; DB helper не endpoint | PASS source audit | Store release gap остаётся |
| Locked plugin manifests + direct app metadata APIs audit | Required-reason/privacy inputs перечислены в IOS_RELEASE, фактические ответы не выдуманы | PASS inventory | Полный release privacy audit не завершён |
| `flutter build ipa --release --no-pub`, archive/export/Store validation | Не выполнялись | NOT RUN | .18/signing/privacy inputs отсутствуют |
| YAML/status/scope/links/full doc diff и independent .19-01 | Coordinator/reviewer PASS, .19-01 reviewed/complete, actionable findings нет | PASS | Только документы, blocker не снимается |

## Result prerequisite scope

Создан только IOS_RELEASE.ru.md и обновлена эта карточка. Документ отделяет
source inventory, signed candidate, archive validation и Store публикацию;
содержит точные недостающие inputs и ограничения. Native/code/deps/lock/permissions
не менялись. .19 остаётся blocked, `accepted` не назначен; независимый [review документов .19-01](../reviews/REVIEW-FE-002.19-01.md)
reviewed/complete, actionable findings нет; это не готовый candidate.

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

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

## Verification planning baseline

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter build ipa --release — только при доступных signing/team/config; иначе NOT RUN с blocker | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Проверить archive/privacy/project diff и release checklist; локальная готовность, TestFlight validation и App Store approval различаются | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result planning baseline

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
