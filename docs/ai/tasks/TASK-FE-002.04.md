---
id: "TASK-FE-002.04"
plan: "PLAN-FE-002"
title: "Сделать мобильную навигацию и экран входа"
status: "review"
owner: "primary-agent"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.03"]
scope: ["lib/features/auth/presentation/login_screen.dart", "test/features/auth/ios_login_layout_test.dart", "docs/ai/tasks/TASK-FE-002.04.md"]
planned_paths: ["test/features/auth/ios_login_layout_test.dart"]
reuses_tasks: ["TASK-FE-001.09", "TASK-FE-001.12", "TASK-FE-001.28", "TASK-FE-001.49"]
implementation_selected: true
---

# TASK-FE-002.04: Сделать мобильную навигацию и экран входа

## Интеграционная Verification / Result — 2026-11-17

Текущий sole writer — `primary-agent`, принявший handoff прежних исполнителей.
Статус **review** означает передачу реализованного scope на независимую проверку;
полная задача не verified/accepted. Ниже сохранены результаты отдельных авторов
и исторические snapshots; настоящий раздел задаёт актуальный интеграционный итог.

Cwd всех команд: `/Users/mxdnght/dictai-app`; Flutter 3.41.3 / Dart 3.11.1,
macOS/Xcode, подготовленный lock/package_config, `--no-pub`.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded` | 658/658 PASS, exit0; `/tmp/dictai-ios-resume-full-tests.log` | PASS | Общий host regression, не реальный API/iPhone |
| `dart format --output=none --set-exit-if-changed <changed/new Dart paths>` | 27 files, 0 changed, exit0; `/tmp/dictai-ios-resume-scoped-format.log` | PASS | Выбраны все changed/untracked Dart lib/test пути относительно HEAD |
| `dart format --output=none --set-exit-if-changed lib test` | Exit1: 10 прежних файлов вне scope требуют формата; `/tmp/dictai-ios-resume-format.log` | FAIL, existing | `--output=none` сохранил файлы; посторонние formatting changes не вносились |
| `flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit0, errors/warnings нет, 7 прежних prefer_const info; `/tmp/dictai-ios-resume-analyze.log` | PASS | Info в audio_ingest_api/label_speakers_modal вне scope не исправлялись |
| `flutter --no-version-check build ios --simulator --debug --no-pub --target lib/main.dart --dart-define-from-file=/tmp/dictai-ios-nav-gateway.json`; `simctl install`; `simctl launch` | Exit0, Xcode12.3s; обычное приложение установлено и запущено; `/tmp/dictai-ios-resume-production-build.log` | PASS | Compile/link и launch не доказывают все пользовательские сценарии |
| `simctl io <UDID> screenshot /tmp/dictai-ios-resume-production.png` и визуальное чтение | Record, logout и нижние Record/Workspaces/Results без overflow | PASS | Только отрисовка текущего экрана, без UI taps/VoiceOver |
| Physical iPhone / реальный provider / VoiceOver / hardware/lifecycle | Не выполнялось: нет подготовленной подписи/устройства | NOT RUN | Обязательные physical criteria не закрыты; .03 blocker сохраняется |

Независимый общий [REVIEW-FE-002.04-02](../reviews/REVIEW-FE-002.04-02.md)
проверяет все шесть выбранных задач и учёт; углублённый native/Files
[REVIEW-FE-002.06-01](../reviews/REVIEW-FE-002.06-01.md) проверяет .06/.07.
Оба отчёта завершены: **reviewed / complete**, открытых actionable findings нет.
Общий reviewer нашёл F01 P3 в описании fixture; исправление подтверждено delta review.
`python3 /tmp/check_dictai_ios_resume.py` — PASS: YAML/status/owner/scope/table,
219 локальных ссылок, whitespace tracked/new files, baseline342/353 и сохранность
HEAD/staging; лог `/tmp/dictai-ios-resume-doc-check.log`. От resume baseline
изменены только 9 документов и добавлены 2 review reports; все 344 остальных
файла, включая исходники/tests/platform/dependencies и исходный .DS_Store, сохранены.

Интеграционный regression включает исправленный async fixture
`profile_free_flow_test.dart`: real WAV copy ожидается через `tester.runAsync`;
прежние assertions workspace/upload сохранены. Desktop layout regression отдельно
исправлена возвратом прежнего toggle в .08, без изменения выбора option в fixture.
Промежуточный integration FAIL из авторского .05 Result независимо перепроверен
полным PASS658 и PASS87 reviewer; исторический FAIL ниже не удаляется.

Ограничения: .09 lifecycle/upload recovery и .11–.19 не выбраны; .10 подтверждает
mobile UI и текущие journals, без полного suspend/relaunch recovery. Физические
Keychain/background/interruption/Files и полная readiness остаются открытыми.
SDK, dependencies/lock, API/DTO, signing и посторонний исходный diff сохранены.
Документальная проверка ссылок/status/scope и контроль baseline — в актуальном
итоге PLAN-FE-002/active-plan. Commit/push/release/accepted не выполнялись.


## Goal

Сделать мобильную навигацию и экран входа. Один завершённый этап iOS/iPhone очереди.

## Context

Текущее поручение: пользователь выбрал весь перечисленный iOS объём .04/.05/.06/.07/.08/.10
и разрешил до 10 параллельных агентов. Единственный writer этой карточки и её
текущего exact scope — `primary-agent` после handoff от `/root/ios_login`. Выполняется выбранная реализация
с проверками Simulator/host; исходные physical acceptance criteria сохраняются.
Предыдущие последовательные write gates заменены назначенными непересекающимися
scopes для разработки, интеграционные зависимости остаются обязательными для
проверки результата. .03 physical blocker не объявляется снятым; .09 не выбрана,
полный suspend/resume recovery в .10 не реализуется автоматически.
Scope .04 — оставшийся login UI, .08/.10 — мобильная компоновка и существующие
flows; восстановление upload/lifecycle вне .09 не расширяется.
Baseline: `/tmp/dictai-ios-batch-baseline/`. Правила интеграции и owner общих файлов
см. в начале active-plan и ADR-FE-011; прежние записи ниже — история.

Предыдущий scope навигационного прохода: нижний навбар вместо
левой панели на телефоне. Primary-agent реализует только responsive MainShell,
верхний доступный logout, Back для вложенных маршрутов, SafeArea и regression
tests навигации. Login layout
и feature screens не меняются. Это явное отдельное UI поручение, поэтому оно
исполняется без ожидания physical gate .03; сама .03 и полная iOS readiness
остаются blocked. Зависимость и незакрытые критерии не объявляются выполненными.
Исходный baseline `/tmp/dictai-mobile-nav-baseline.json`; продолжение:
`/tmp/dictai-ios-nav-start-hashes.json` и `/tmp/dictai-ios-nav-baseline.patch`.


[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Последующее поручение 2026-11-16 выбрало реализацию .01–.05 пятью агентами.
Write gate и owner назначены в active-plan; зависимости проверяются до записи.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.09](../tasks/TASK-FE-001.09.md), [TASK-FE-001.12](../tasks/TASK-FE-001.12.md), [TASK-FE-001.28](../tasks/TASK-FE-001.28.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Основные разделы Record/Results/Workspaces доступны на iPhone через мобильную навигацию; keyboard, safe areas и системный Back/swipe не обрезают действия.
- [ ] На ширине 320/375/430 logical px нет overflow; вход/регистрация работают с клавиатурой и увеличенным текстом, основные controls доступны VoiceOver.
- [ ] Auth redirects, параметры workspace и восстановление маршрута не обходят guards; desktop sidebar сохраняется при широкой компоновке без отдельной очереди desktop redesign.
- [ ] Logout доступен на телефоне; route transitions не запускают повторные upload/poll. Active-record guard доводится в .08, здесь есть регрессионная проверка существующего guard.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Сохранить Riverpod/GoRouter; bottom navigation и адаптивный layout предпочтительны собственному navigation framework. iPad получает безопасную адаптивную компоновку; отдельная iPad-оптимизация вне первого этапа.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification login UI выбранного параллельного блока — 2026-11-16

Owner `/root/ios_login`, cwd `/Users/mxdnght/dictai-app`, Flutter 3.41.3 / Dart
3.11.1 (`/tmp/dictai-flutter-3.41.3/bin/`), prepared package_config/no-pub.
Новые проверки ниже относятся к текущему login diff относительно
`/tmp/dictai-ios-batch-baseline/`; прежний nav evidence ниже сохраняется отдельно.

| Command / scenario | Expected / Actual | Status | Limitation |
|---|---|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/auth/presentation/login_screen.dart test/features/auth/ios_login_layout_test.dart` | Два файла отформатированы, exit0 | PASS | Scoped format |
| `flutter --no-version-check test --no-pub test/features/auth/ios_login_layout_test.dart` | 9 новых widget tests PASS | PASS | Fake Dio/Keychain; настоящий LoginScreen/AuthNotifier, без HTTP/аккаунтов |
| `flutter --no-version-check test --no-pub test/features/auth/ios_login_layout_test.dart test/features/auth/auth_api_test.dart test/features/auth/session_navigation_test.dart` | 46 tests PASS, exit0; log `/tmp/dictai-ios-login-tests.log` | PASS | Содержит настоящий app router/401; не physical iPhone |
| `flutter --no-version-check analyze --no-pub --no-fatal-infos lib/features/auth/presentation/login_screen.dart test/features/auth/ios_login_layout_test.dart` | No issues found, exit0; log `/tmp/dictai-ios-login-analyze.log` | PASS | Scoped analyze, общий analyze выполняет coordinator |
| `git diff --check -- lib/features/auth/presentation/login_screen.dart test/features/auth/ios_login_layout_test.dart docs/ai/tasks/TASK-FE-002.04.md`; полный diff исходника и нового test | Нет whitespace diagnostics, изменения в назначенном scope | PASS | Посторонние параллельные edits не оценивались |
| Simulator build/install/launch/screenshot текущего общего блока | Выполняет root после handoff | NOT RUN | Автор login не запускает параллельный Xcode build |
| Physical iPhone / VoiceOver / iOS keyboard UI taps | Не выполнялось | NOT RUN | Semantics проверены widget tests, это не VoiceOver smoke; gate .03 сохраняется |
| Независимый review [REVIEW-FE-002.04-02](../reviews/REVIEW-FE-002.04-02.md) | Назначен coordinator после интеграции | NOT RUN | Reviewer не писал этот diff; статус report пока reserved |

## Result login UI выбранного параллельного блока — 2026-11-16

В `lib/features/auth/presentation/login_screen.dart` формы входа и регистрации
обёрнуты в SafeArea и одну прокручиваемую область. Фиксированная высота 260 и
вложенная прокрутка регистрации убраны; мобильные отступы уменьшены до 24 внутри
карточки, широкая desktop-карточка сохраняет ширину 440 и padding 48. При изменении
text scale растут высота tabs/submit и содержимое формы. Keyboard уменьшает
viewport через существующий Scaffold, все поля, ошибки и submit доступны прокруткой.

TabController теперь обновляет выбранную форму и подпись submit сразу при
переключении Sign In/Sign Up; текст controllers сохраняется между вкладками.
У полей есть labelText, у password visibility controls — явные tooltips, ошибки
объявлены liveRegion; валидация email, обязательного login password, 8 UTF-8 bytes
нового password и совпадения confirmation сохранена. AuthNotifier/API/storage,
auth routes и wire format не менялись; регистрация по-прежнему возвращает на
Sign In и не создаёт сессию автоматически.

Новый `test/features/auth/ios_login_layout_test.dart` проверяет widths
320/375/430 с text2 и keyboard, landscape, формы и validation errors, успешный
login и redirect, signup byte validation и return-to-login, disabled loading,
отображение/сброс auth error, сохранение ввода, semantics labels/visibility и
desktop constraints. Временный combined-run FAIL из-за незавершённых параллельных
RecordState import/const Semantics edits был передан их владельцам; собственные
9 tests прошли; после исправлений владельцев финальный combined-run дал 46/46 PASS.

Статус implemented: выбранный login код готов; независимый review, общий
Simulator regression и physical evidence этим автором не объявлены завершёнными.
Ни полный physical .04, ни .03 не accepted/verified; публикация не выполнялась.

## Verification выбранного UI scope — 2026-11-16

Cwd всех команд: `/Users/mxdnght/dictai-app`. SDK:
`/tmp/dictai-flutter-3.41.3/bin/` (Flutter 3.41.3 / Dart 3.11.1), macOS/Xcode.
Существующий package_config соответствует этому SDK; pub get, обновление SDK,
pubspec/lock и платформенных разрешений не требовались.

| Command / scenario | Expected / Actual | Status | Limitation |
|---|---|---|---|
| `dart format --output=none --set-exit-if-changed lib/core/shell/main_shell.dart test/core/router/ios_navigation_test.dart` | Два файла отформатированы, изменений нет | PASS | Scoped format |
| `flutter --no-version-check test --no-pub test/core/router/ios_navigation_test.dart test/features/auth/session_navigation_test.dart test/features/record/record_confirmation_test.dart` | 33 tests PASS: 8 новых shell tests и существующие auth/401/active-record tests | PASS | Shell tests используют настоящий GoRouter с лёгким контентом; существующие tests — app router/guards, desktop layout |
| `flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit0: errors/warnings нет; 7 прежних info в соседних feature files, в выбранных файлах diagnostics нет | PASS | Info не повышены до ошибки; обычный analyze ранее завершался exit1 из-за info |
| `flutter --no-version-check build ios --simulator --debug --no-pub` | Exit0: Runner.app собран, Xcode 16.2s | PASS | Только compile/link; запуск обновлённой сборки и device smoke не заявляются |
| `python3 /tmp/check_dictai_ios_nav.py`; `git diff --check`; полный scoped tracked/untracked diff | YAML/status/paths/links PASS; 336 из 340 существовавших файлов неизменны, остальные 4 входят в scope; nav test и report просмотрены целиком | PASS | Baseline/команды проверяют выбранный scope и сохранность, не приложение |
| Независимый [REVIEW-FE-002.04-01](../reviews/REVIEW-FE-002.04-01.md) | Reviewer `/root/mobile_nav_review`: reviewed/complete, actionable findings нет; независимо повторены 33 tests и format2 PASS | PASS | Analyze/build прочитаны reviewer как author evidence; runtime не утверждается |
| Ручной iPhone/VoiceOver/swipe и внутренние feature layouts | Не выполнялись в этом UI проходе | NOT RUN | Login layout и адаптация Record/Results/Workspaces не входят в выбранный scope; physical gate .03 сохраняется |

## Result выбранного UI scope — 2026-11-16

В `MainShell` добавлена нижняя `NavigationBar` с Record / Workspaces / Results
для iOS при любой ширине, включая landscape/iPad, и для окон уже 600 logical px.
Широкий desktop сохраняет sidebar. Верхний AppBar содержит доступный через tooltip
logout и Back для вложенных маршрутов; AppBar/NavigationBar/SafeArea учитывают
верхний, боковые и нижний системные отступы. Текущая вкладка вычисляется по маршруту,
через routerDelegate, включая pop; отклонённый onExit не переключает выделение.
Повторное нажатие сохраняет
workspace path/query/extra. Навигация использует прежний `context.go` и guards.

Изменены только `lib/core/shell/main_shell.dart`, новый
`test/core/router/ios_navigation_test.dart`, эта карточка и общий учёт
`active-plan.md` / `PLAN-FE-002.md`; отдельный reviewer пишет назначенный report.
Новые tests проверяют widths 320/375/430, safe areas, landscape + keyboard/text2,
выбор разделов, path/query/extra, видимый Back/system Back, отказ onExit,
реальное удаление fixture credentials кнопкой logout и desktop resize.

Статус review относится к передаче выбранного UI scope; вся .04 не объявляется
verified/accepted. Полные критерии формы входа, адаптации внутренних экранов,
VoiceOver/swipe и физические gates остаются открытыми. .05 не разблокирована.
Независимый [REVIEW-FE-002.04-01](../reviews/REVIEW-FE-002.04-01.md) завершён
агентом `/root/mobile_nav_review`, actionable findings нет. Финальные format,
33 targeted tests, analyze без errors/warnings и simulator build PASS.
Семь прежних info остаются вне scope. На первом этапе сборка не устанавливалась;
последующее применение к Simulator зафиксировано ниже. Physical iPhone не проверялся.
Commit/push/merge/release не выполнялись.

## Применение к запущенному Simulator — 2026-11-16

После сообщения пользователя, что изменения не видны, подтверждено: процесс
`flutter run` отсутствовал, установленный Runner оставался прежним. Выполнены
повторная сборка с существующим API origin установленного приложения,
`simctl install` и `simctl launch --terminate-running-process` на iPhone 17 Pro,
UDID `EFF90604-B7F5-4B2B-9A95-7AC2B9E257B6`, iOS 26.5. Origin сохранён
только во временном `/tmp/dictai-ios-nav-gateway.json`; secrets/config не внесены
в repo. На реальном screenshot Simulator подтверждены Record, верхний logout
и нижние Record / Workspaces / Results, sidebar отсутствует.

При визуальной проверке исправлен контраст активной иконки: стандартный цвет
NavigationDestination давал чёрную иконку на тёмном indicator. Для иконок задан
существующий `AppColors.textPrimary`; поведение маршрутов не менялось.

| Command / scenario | Cwd / environment | Actual | Status / limitation |
|---|---|---|---|
| Те же scoped format и 33 targeted tests из Verification выше | frontend / Flutter 3.41.3 | Exit0, формат не изменён, 33 tests PASS после изменения цвета | PASS |
| `flutter --no-version-check analyze --no-pub --no-fatal-infos` | frontend / Flutter 3.41.3 | Exit0, errors/warnings нет, 7 прежних info вне scope | PASS |
| `flutter --no-version-check build ios --simulator --debug --no-pub --dart-define-from-file=/tmp/dictai-ios-nav-gateway.json` | frontend / Flutter 3.41.3 | Exit0, Xcode 10.8s, Runner.app собран | PASS; log `/tmp/dictai-ios-nav-applied-build.log` |
| `xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch --terminate-running-process <UDID> com.dictai.app` | frontend / установленный iPhone 17 Pro Simulator | Обе команды exit0, final PID 45018 | PASS; без удаления sandbox/Keychain |
| `xcrun simctl io <UDID> screenshot /tmp/dictai-ios-nav-applied.png`; визуальное чтение screenshot | тот же Simulator | Обычный экран Record с нижними вкладками; активная иконка светлая | PASS; только render, без UI taps/VoiceOver/swipe/проверки записи |

Полная .04/.05 и physical gate .03 не закрываются этим применением.

## Историческая Verification до выбранного UI scope

Cwd: `/Users/mxdnght/dictai-app`. В этом проходе изменена только карточка;
исполнитель .04 проверки приложения не запускал. Чтение исходников ниже —
preflight, не доказательство поведения на iPhone. Результаты .02 и текущего
прогона .03 получены из независимого отчёта и handoff координатора; они не
являются функциональными проверками ещё не реализованной .04.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| Flutter tests / scoped format / flutter analyze | frontend | Проверки изменённого Dart-кода и новой навигации | Функциональная реализация не начата, planned test paths не созданы | NOT RUN | Write gate закрыт до checks/review .03; в этом проходе только документация |
| Simulator: keyboard/safe area/back, text scale и доступность основного пути | frontend / iOS Simulator | Подтверждённый мобильный путь | Не выполнялось | NOT RUN | Launch .02 подтверждён; write gate .04 закрыт до обязательных checks/review .03 |
| `ruby -ryaml -e 'YAML.safe_load(File.read(ARGV.fetch(0)).split("---", 3).fetch(1)); puts "PASS YAML"' docs/ai/tasks/TASK-FE-002.04.md` | frontend / Ruby Psych | Валидный frontmatter | Frontmatter разобран без ошибок | PASS | Проверка только документа |
| `python3 /tmp/check_dictai_ios_navigation_task.py` | frontend / Python 3 stdlib | Ссылки существуют, owner/selection/dependency согласованы; criteria unchecked, planned tests отсутствуют | Проверки карточки пройдены | PASS | Временный checker вне продуктового diff; не проверяет приложение |
| `git diff --check -- docs/ai/tasks/TASK-FE-002.04.md`; полный diff карточки | frontend / Git | Нет whitespace diagnostics; изменения ограничены выбором и фиксацией blocker | Diagnostics нет, полный diff просмотрен | PASS | Не относится к чужим параллельным изменениям |
| Исторический doc-only review [REVIEW-FE-002.03-01](../reviews/REVIEW-FE-002.03-01.md) | reviewer `/root/ios_queue_review` | Проверены прежняя blocker-карточка и координационный учёт | reviewed/complete, actionable findings нет | PASS | Предыдущий doc snapshot; обновлённая карточка включена в завершённый REVIEW-FE-002.03-02, functional gate закрыт |

## Исторический Result до выбранного UI scope

2026-11-16, текущее состояние после возобновления Simulator, owner
`/root/ios_navigation`: выбранная задача **blocked**, выбор реализации сохранён.
Блокер .02/runtime снят: [TASK-FE-002.02](TASK-FE-002.02.md) имеет actual
build/install/launch/render PASS на Flutter 3.41.3, iOS 26.5, iPhone 17 Pro
Simulator; независимый [REVIEW-FE-002.02-03](../reviews/REVIEW-FE-002.02-03.md)
завершён без findings. Исполнитель .04 запуск не повторял.

Актуальный blocker — обязательное physical evidence
[TASK-FE-002.03](TASK-FE-002.03.md). Финальная интеграция .03 у primary-agent:
реализация и targeted60/full561/analyze прошли; девять native Keychain/HTTPS/auth
phases PASS на Simulator, тестовый аккаунт создан. Эти результаты не относятся
к функциональным изменениям .04. Независимый .03-02 завершён без открытых findings, а обязательные
physical lock/unlock/unavailable Keychain/account switch/reinstall/restore и
iPhone HTTPS не выполнены: подпись недоступна по ответу пользователя.
Functional gate .04 закрыт до всех mandatory checks и review .03.

В этом возобновлении исполнитель .04 изменил только данную карточку; router,
theme, исходники и тесты им не менялись. Acceptance criteria остаются unchecked,
functional проверки .04 не выполнялись, verified/accepted не заявлены. Текущий
doc diff проверен в REVIEW-FE-002.03-02 без открытых findings. Условие возобновления
реализации: обязательные checks .03 подтверждены, её независимый review
завершён без блокирующих findings и координатор передал write gate .04.

История первого blocked-прохода и preflight, до восстановления Simulator:
зависимость .03 не имела полного checks/review evidence; координатор передал
0 signing identities и 0 provisioning profiles, а .02 ещё не имела launch
evidence из-за отсутствовавшего runtime. Эти сведения повторно исполнителем
.04 не проверялись. Прежний runtime blocker снят описанным выше результатом .02;
запись сохранена для истории, она не определяет текущий gate.

Read-only preflight по текущим исходникам: `MainShell` содержит sidebar шириной
220 и logout только в нём; `LoginScreen` — padding 48, фиксированную область
TabBarView высотой 260, без SafeArea. Router уже содержит ShellRoute, auth
redirect, параметры workspace и onExit guard записи. Минимальное продолжение
в назначенном scope: мобильная NavigationBar с доступным logout и SafeArea,
сохранение широкой sidebar-компоновки и существующих guards, адаптивные формы
входа/регистрации с прокруткой для клавиатуры и доступными controls. Новые тесты
из planned_paths пока не созданы. Для регрессии доступны существующие
`test/features/auth/session_navigation_test.dart` и
`test/features/record/record_confirmation_test.dart`; они в этом проходе
не запускались. Адаптация фиксированных ширин RecordScreen относится к .08
и не реализуется внутри .04.

Независимый [REVIEW-FE-002.03-01](../reviews/REVIEW-FE-002.03-01.md) первого
doc-only прохода завершён агентом `/root/ios_queue_review`: reviewed/complete,
actionable findings нет. Он проверял прежние blocker-карточки и учёт; текущая
редакция и реализация .04 этим историческим review не подтверждаются.
Commit/push/merge/release не выполнялись.
