---
id: "TASK-FE-002.03"
plan: "PLAN-FE-002"
title: "Подтвердить iOS Keychain, авторизацию и HTTPS"
status: "blocked"
owner: "primary-agent"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.02"]
scope: ["lib/core/storage/secure_storage.dart", "lib/core/config/app_config.dart", "lib/core/network/auth_interceptor.dart", "lib/core/router/auth_listenable.dart", "lib/features/auth/presentation/auth_notifier.dart", "ios/Runner/Info.plist", "ios/Runner/Runner.entitlements", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_session_test.dart", "test/core/config/ios_gateway_test.dart", "docs/testing/IOS_SESSION.ru.md", "docs/ai/tasks/TASK-FE-002.03.md", "test/core/storage/ios_session_smoke_app.dart"]
planned_paths: ["ios/Runner/Info.plist", "ios/Runner/Runner.entitlements", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_session_test.dart", "test/core/config/ios_gateway_test.dart", "docs/testing/IOS_SESSION.ru.md", "test/core/storage/ios_session_smoke_app.dart"]
reuses_tasks: ["TASK-FE-001.02", "TASK-FE-001.03", "TASK-FE-001.04", "TASK-FE-001.05", "TASK-FE-001.07", "TASK-FE-001.08", "TASK-FE-001.09"]
implementation_selected: true
---

# TASK-FE-002.03: Подтвердить iOS Keychain, авторизацию и HTTPS

## Goal

Подтвердить iOS Keychain, авторизацию и HTTPS. Один завершённый этап iOS/iPhone очереди.

## Context

Текущий проход: checks .02 и независимый REVIEW-FE-002.02-03 завершены без
findings. Исходную реализацию .03 подготовил ios_session; после code handoff
primary-agent принял sole write и финальную проверку. Simulator iPhone17 Pro /
iOS26.5 доступен, Flutter3.41.3. Host tests и девять native phases прошли;
физические iPhone criteria остаются NOT RUN из-за недоступной подписи.
Пользователь разрешил создать серверный тестовый аккаунт и передать ему данные;
аккаунт зарегистрирован, секреты вне repo/evidence. Baseline335 перед .03:
`/tmp/dictai-ios-session-baseline.json`. Standalone native harness добавлен в
scope/planned_paths до записи; прежний macOS smoke сохранён.

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Последующее поручение 2026-11-16 выбрало реализацию .01–.05 пятью агентами.
Write gate и owner назначены в active-plan; зависимости проверяются до записи.
Planning baseline исходников: `44ace4d`; исходный HEAD текущего поручения —
`260b149`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.02](../tasks/TASK-FE-001.02.md), [TASK-FE-001.03](../tasks/TASK-FE-001.03.md), [TASK-FE-001.04](../tasks/TASK-FE-001.04.md), [TASK-FE-001.05](../tasks/TASK-FE-001.05.md), [TASK-FE-001.07](../tasks/TASK-FE-001.07.md), [TASK-FE-001.08](../tasks/TASK-FE-001.08.md), [TASK-FE-001.09](../tasks/TASK-FE-001.09.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Login/register/logout и истечение/401 используют общий Dio и текущие API; нет нового wire/авторизации или plaintext fallback.
- [ ] Keychain accessibility выбрана явно с учётом блокировки телефона и background capture; холодный старт, lock/unlock, недоступное хранилище и смена аккаунта проверены на устройстве.
- [ ] Сохранение JWT после reinstall/restore не считается гарантированно очищенным: описано и проверено принятое поведение, секреты не попадают в логи/backup fixtures.
- [ ] HTTPS endpoint достижим отдельно из Simulator и iPhone; localhost телефона не считается Mac. Нет отключения TLS или широкого ATS allow-arbitrary-loads.
- [x] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

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

Cwd frontend, macOS26.5.2 arm64/Xcode26.5/CocoaPods1.16.2;
Flutter3.41.3/Dart3.11.1 по постоянному пути. Полные команды, сценарии и
ограничения: [IOS_SESSION.ru.md](../../testing/IOS_SESSION.ru.md).
Все runtime-команды исполнил primary-agent, не независимый reviewer.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| Direct Dart3.41.3 scoped `format --output=none --set-exit-if-changed` | 4 files, 0 changed после fallback | PASS | Формат |
| `flutter test --no-pub --reporter expanded` с ios_session/ios_gateway/secure_storage/storage_interceptor/auth_api/session_navigation | 60/60, exit0 | PASS | Host channel/API fakes |
| `flutter test --no-pub --reporter expanded` | 561/561, exit0 | PASS | После этого менялся только standalone native harness |
| `flutter analyze --no-pub --no-fatal-infos` | Initial и final после fallback exit0, 9 прежних info, no errors/warnings | PASS | Нет новых замечаний анализатора |
| `flutter build ios --simulator --debug --no-pub --target test/core/storage/ios_session_smoke_app.dart --dart-define=API_BASE_URL=<provided-https-origin>` | Initial13s, diagnostic7.9s, final fallback6.8s, exit0; install exit0 | PASS | Build не подменяет phases |
| Initial write/restart и diagnostic write | FAIL invalid_configuration, Dart не увидел переданные env variables | FAIL, исторический | Storage/network не начаты; test-only sandbox JSON fallback исправил причину |
| Final native write/restart/legacy_delete/empty | 4 PASS markers, отдельные процессы | PASS | Native Keychain/migration/retained-unlocked delete, не OS attributes |
| Native https_untrusted до CA; add-root-cert только выбранному Simulator; native https | Отказ TLS до доверия, HTTP response после доверия, оба ожидаемых PASS | PASS | Реальный общий Dio; no bypass/ATS/Mac trust changes |
| Native auth_register_login/auth_restart/auth_logout | 3 PASS: real register/login, protected read, cold-process persistence, native cleanup и unauthorized read после выхода | PASS | Создан один разрешённый серверный аккаунт, не UI taps/iPhone |
| Restore `lib/main.dart` build/install/launch/render | Build exit0/17.6s, install/launch exit0, обычный login screen визуально подтверждён | PASS | Тестовый target заменён production entrypoint |
| Physical lock/unlock, unavailable Keychain, account switch, reinstall/restore и iPhone HTTPS/auth | Подпись недоступна, не выполнялось | NOT RUN | Обязательный gate .03, закрывает .04/.05 |
| Scope/links/whitespace/полный tracked/untracked diff | Session335 и original queue checkers PASS, HEAD/staging сохранены, actual email/password в diff не найдены | PASS | Проверка границ и документов, не independent review |
| Independent [REVIEW-FE-002.03-02](../reviews/REVIEW-FE-002.03-02.md) | Reviewed, F01 P3 исправлен и повторно проверен; открытых findings нет | PASS | Physical criteria не закрывает; .04/.05 остаются blocked |

## Result

В scope изменён `lib/core/storage/secure_storage.dart`; созданы два host test
файла, standalone native smoke target и IOS_SESSION.ru.md. Новые iOS writes
используют `first_unlock_this_device`, synchronizable:false; keyed delete не
фильтрует accessibility, чтобы удалять retained non-synchronized unlocked items.
API/DTO/auth/router/providers, dependencies, signing, ATS, permissions и native
entitlements в .03 не менялись. Нет production testing getter или новых слоёв.

Pinned plugin read может читать retained/synchronized items независимо от новых
options; чтение само не переклассифицирует их. Synchronized cleanup не добавлен: post-delete verify сообщает ошибку, а
credential suppression закрывает запросы только текущего Dart процесса. После
cold start retained synchronized item может восстановить сессию при валидном
JWT; неуспешный logout не гарантирует очистку между запусками.
Native smoke подтверждает операции, не OS protection attributes. Подробные
ограничения documented в IOS_SESSION. Host channel tests не выданы за iOS options.

Все561 host tests и девять final native phases PASS. Initial config failures
оставлены историческими FAIL, после bounded sandbox config повтор успешен.
Создан разрешённый пользователем тестовый аккаунт, данные передаются отдельно
вне repo. Реальный login, protected read, восстановление между процессами и
logout проверены через существующий production stack на Simulator; тестовая
native session удалена. CA доверен только выбранному Simulator и остаётся там.
Временные sandbox config/credentials удалены. Backend source изучался read-only;
CodeGraph CLI/MCP был недоступен, контракт register/login сверён по handlers и
service. Соседний репозиторий не менялся.

Status blocked: physical iPhone checks не выполнены из-за недоступной подписи;
reinstall/restore, lock/unlock и account switch не объявляются проверенными.
.04/.05 functional gates остаются закрыты. Первый критерий подтверждён host и
Simulator evidence, physical acceptance остаётся unchecked. Независимый .03-02
завершён: F01 P3 уточнил process-local suppression, исправление подтверждено
delta review; открытых findings нет. Accepted/commit/push/merge/release не назначены.
