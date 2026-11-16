---
id: "TASK-FE-002.03"
plan: "PLAN-FE-002"
title: "Подтвердить iOS Keychain, авторизацию и HTTPS"
status: "draft"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.02"]
scope: ["lib/core/storage/secure_storage.dart", "lib/core/config/app_config.dart", "lib/core/network/auth_interceptor.dart", "lib/core/router/auth_listenable.dart", "lib/features/auth/presentation/auth_notifier.dart", "ios/Runner/Info.plist", "ios/Runner/Runner.entitlements", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_session_test.dart", "test/core/config/ios_gateway_test.dart", "docs/testing/IOS_SESSION.ru.md", "docs/ai/tasks/TASK-FE-002.03.md"]
planned_paths: ["ios/Runner/Info.plist", "ios/Runner/Runner.entitlements", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_session_test.dart", "test/core/config/ios_gateway_test.dart", "docs/testing/IOS_SESSION.ru.md"]
reuses_tasks: ["TASK-FE-001.02", "TASK-FE-001.03", "TASK-FE-001.04", "TASK-FE-001.05", "TASK-FE-001.07", "TASK-FE-001.08", "TASK-FE-001.09"]
implementation_selected: false
---

# TASK-FE-002.03: Подтвердить iOS Keychain, авторизацию и HTTPS

## Goal

Подтвердить iOS Keychain, авторизацию и HTTPS. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.02](../tasks/TASK-FE-001.02.md), [TASK-FE-001.03](../tasks/TASK-FE-001.03.md), [TASK-FE-001.04](../tasks/TASK-FE-001.04.md), [TASK-FE-001.05](../tasks/TASK-FE-001.05.md), [TASK-FE-001.07](../tasks/TASK-FE-001.07.md), [TASK-FE-001.08](../tasks/TASK-FE-001.08.md), [TASK-FE-001.09](../tasks/TASK-FE-001.09.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Login/register/logout и истечение/401 используют общий Dio и текущие API; нет нового wire/авторизации или plaintext fallback.
- [ ] Keychain accessibility выбрана явно с учётом блокировки телефона и background capture; холодный старт, lock/unlock, недоступное хранилище и смена аккаунта проверены на устройстве.
- [ ] Сохранение JWT после reinstall/restore не считается гарантированно очищенным: описано и проверено принятое поведение, секреты не попадают в логи/backup fixtures.
- [ ] HTTPS endpoint достижим отдельно из Simulator и iPhone; localhost телефона не считается Mac. Нет отключения TLS или широкого ATS allow-arbitrary-loads.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Переиспользовать существующий SecureStorage, не заменять его новой архитектурой. Entitlements добавлять только при доказанной необходимости плагина/подписи; не включать Keychain sharing по умолчанию.

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
| flutter test test/core/storage/ios_session_test.dart test/core/config/ios_gateway_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: login/cold start/lock/unlock/logout/401; TLS failure и недоступный gateway — evidence отдельно от fakes | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
