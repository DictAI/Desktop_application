---
id: "TASK-FE-002.15"
plan: "PLAN-FE-002"
title: "Связать готовность результата с lifecycle и уведомлением внутри приложения"
status: "review"
owner: "/root/notice_prep_finish"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.14"]
scope: ["lib/features/results/presentation/processing_notifier.dart", "lib/features/results/presentation/result_ready_notice.dart", "lib/core/shell/main_shell.dart", "lib/core/lifecycle/ios_lifecycle_observer.dart", "lib/shared/providers/providers.dart", "test/features/results/ios_ready_notice_test.dart", "docs/ai/tasks/TASK-FE-002.15.md", "test/core/router/ios_navigation_test.dart"]
planned_paths: ["lib/features/results/presentation/result_ready_notice.dart", "test/features/results/ios_ready_notice_test.dart"]
reuses_tasks: ["TASK-FE-001.25", "TASK-FE-001.48"]
implementation_selected: true
---

# TASK-FE-002.15: Связать готовность результата с lifecycle и уведомлением внутри приложения

## Реализация и handoff — 2026-11-18

Owner `/root/notice_prep_finish` завершил host implementation после gate .14
(commit `bdfc370`). Source/tests заморожены для независимого
[REVIEW-FE-002.15-01](../reviews/REVIEW-FE-002.15-01.md), reviewer
`/root/media_review_finish`. Статус review не объявляет physical readiness,
verified или accepted. Базовый lifecycle/tracker .09 и detail .11 сохранены.

На iOS MainShell монтирует ResultReadyNoticeHost, поэтому принадлежащий текущей
сессии BatchSession восстанавливает принятые jobs уже в любом разделе. Новая
очередь слушает тот же ProcessingNotifier без HTTP, timers или второго poller.
Notice требует реально полученного canonical; summary pending/failed не задерживает
готовый транскрипт. Показывается один banner с явным действием открытия.
Пользователь остаётся в текущем разделе до нажатия; push/local notifications,
APNs и новые permissions не добавлены.

Dismiss и просмотр exact resolved audio/job подтверждают сообщение только для
текущей login session. Повторные status reads/resume его не дублируют. URL без
job_id использует resolved identity существующего detail-provider, поэтому
просмотр одного job не прячет другой job той же записи. Open вызывает обычный
context.go и существующий Record onExit: «Остаться» сохраняет и capture, и notice;
подтверждённая отмена выполняет исходный переход после owned cleanup. Action
повторно проверяет current session и tombstone до навигации. Logout/401 синхронно
закрывают tracker/очередь; поздний canonical и старая кнопка аккаунта A не могут
открыть данные в аккаунте B. Delete/lost access удаляют недоступное сообщение.

Структура Host сохраняет element текущего экрана при появлении/закрытии banner
и смене доступности сессии. Это исправление раннего независимого F01 P2:
первый вариант менял subtree и мог сбросить локальный elapsed RecordScreen.
Stateful probe подтверждает отсутствие дополнительного init/dispose на обоих
переходах. Ограничение banner половиной доступной высоты и его scroll сохраняют
доступность content/actions в узком landscape и при text scale 2.

Coordinator до записи расширил exact scope одним integration test:
`test/core/router/ios_navigation_test.dart`. Более ранний shell restore запускал
filesystem Futures в widget fake zone; старый тест ждал их внутри одного
runAsync без pump. Исправлен bounded цикл с чередованием pump/runAsync; прежние
assertions exact route, selected tab, один R01 GET, отсутствие POST и logout
сохранены. Runtime implementation для обхода теста не менялся.

## Verification реализации — 2026-11-18

Cwd всех команд `/Users/mxdnght/dictai-app`; macOS arm64, pinned
Flutter 3.41.3 / Dart 3.11.1 из `/tmp/dictai-flutter-3.41.3`, prepared packages,
без pub/lock/SDK изменений. Source/tests перечислены в Result ниже.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub test/features/results/ios_ready_notice_test.dart test/features/record/ios_upload_recovery_test.dart test/features/results/ios_result_detail_test.dart test/features/results/ios_results_library_test.dart test/features/record/record_discard_test.dart test/core/router/ios_navigation_test.dart test/features/results/processing_recovery_test.dart --reporter expanded` | 118/118 PASS, exit0, включая 15 новых notice cases | PASS | Host/fake HTTP/capture/storage, synthetic WAV/DTO; log `/tmp/dictai-ready-notice-targeted.log` |
| `/tmp/dictai-flutter-3.41.3/bin/dart format --output=none --set-exit-if-changed lib/features/results/presentation/result_ready_notice.dart lib/core/shell/main_shell.dart lib/shared/providers/providers.dart test/features/results/ios_ready_notice_test.dart test/core/router/ios_navigation_test.dart` | 5 files, 0 changed, exit0 | PASS | Только назначенный Dart scope |
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit0, 7 прежних info, 0 errors/warnings и новых info | PASS | `/tmp/dictai-ready-notice-analyze-final.log`; прежние info вне scope не исправлялись |
| `git diff --check` и `git diff --no-index --check -- /dev/null <оба новых Dart paths>` | Нет whitespace diagnostics | PASS | Source review/diff, не runtime; no-index exit1 означает новый файл |
| Initial notice fixture runs | Missing Uint8List import, erroneous fixture cascade, invalid anonymous receipt mode и teardown timing исправлены | FAIL, исторический | Ошибки новых fixtures; финальные 15 cases входят в 118 PASS |
| Initial integration run с прежним navigation fixture | 115 PASS / 3 FAIL, Results page/journal wait timeout | FAIL, исправлен | Bounded pump/runAsync correction выше; финальный 118 PASS |
| Production main Simulator build/install/launch | Выполняет coordinator после freeze | NOT RUN автором | Source-only изменение не заменяет runtime build evidence |
| Реальный iPhone: foreground/background/relaunch/VoiceOver и смена аккаунта | Не выполнялось | NOT RUN | Host tests не доказывают hardware accessibility/lifecycle |
| Независимый implementation review .15-01 | Назначен `/root/media_review_finish`, source/tests frozen | IN REVIEW | F01 исправлен с regression, финальный verdict в отчёте |

## Result реализации — 2026-11-18

Изменены `lib/core/shell/main_shell.dart`, `lib/shared/providers/providers.dart`,
`test/core/router/ios_navigation_test.dart` и эта карточка; добавлены
`lib/features/results/presentation/result_ready_notice.dart` и
`test/features/results/ios_ready_notice_test.dart`. Реализации
processing_notifier/lifecycle, API/DTO/backend/native/dependencies не менялись.

Подтверждены canonical-only готовность при pending summary, несколько exact jobs,
повторный resume/dismiss без дублей, recovery реально сохранённого accepted
receipt после пересоздания session без POST/startup redirect, удаление и lost
access, поздний canonical после delete/logout, matched401, A→B и старая action,
resolved latest detail, URI encoding, existing recording guard Stay/confirm,
сохранение Stateful child, 320×568/430×320 и text scale2.
Acknowledgements живут в текущей login session; новое открытие приложения или
новая авторизация может снова показать восстановленный ready job. Нового durable
notification journal и обещания уведомлений при закрытом приложении нет.

Полная приёмка остаётся за пользователем; physical checks NOT RUN. Commit/push
выполняет только coordinator в пределах текущего разрешения пользователя.

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Связать готовность результата с lifecycle и уведомлением внутри приложения. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.25](../tasks/TASK-FE-001.25.md), [TASK-FE-001.48](../tasks/TASK-FE-001.48.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Ожидающий пользователь получает готовый canonical независимо от summary; другой раздел показывает одно in-app сообщение с переходом, без внезапной смены экрана.
- [ ] После suspended/terminated состояния приложение перечитывает текущие jobs; библиотека восстанавливает результат без вечного background polling и startup redirect.
- [ ] Notification/navigation использует текущие account/audio/job; повторный resume не дублирует notice и не открывает предыдущую сессию.
- [ ] Нет push/APNs/local notification permission или обещания уведомления при закрытом приложении; это отдельное будущее продуктовое решение.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

In-app notice не требует backend push capability. Не открывать несуществующий names editor.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/results/ios_ready_notice_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: ожидание/другая вкладка/background/relaunch/смена аккаунта | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.


## Integration coordinator — 2026-11-18

Cwd frontend, pinned Flutter3.41.3/Dart3.11.1, macOS/Xcode26.5.
`python3 /tmp/dictai_ios_max_build.py 15-final`: production main Simulator
build PASS8.5s, log `/tmp/dictai-task-fe-002.15-final-build.log`.
`simctl install` и `launch --terminate-running-process` на iPhone17Pro/iOS26.5:
PASS. Это запуск production main после source freeze; physical notification/
recording/VoiceOver/backend E2E не проверены. .15 не меняет Swift/SDK/dependencies.

Независимый REVIEW-FE-002.15-01 reviewed/complete: reviewer118 tests/format5
PASS, F01 fixed, открытых findings нет. Host/Simulator gate пройден; accepted нет.
