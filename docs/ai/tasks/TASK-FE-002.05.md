---
id: "TASK-FE-002.05"
plan: "PLAN-FE-002"
title: "Адаптировать workspaces и контакты для iPhone"
status: "review"
owner: "primary-agent"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.04"]
scope: ["lib/features/workspace/presentation/workspaces_screen.dart", "lib/features/workspace/presentation/workspace_detail_screen.dart", "lib/features/workspace/presentation/workspace_notifier.dart", "test/features/workspace/ios_workspace_test.dart", "docs/ai/tasks/TASK-FE-002.05.md"]
planned_paths: ["test/features/workspace/ios_workspace_test.dart"]
reuses_tasks: ["TASK-FE-001.10", "TASK-FE-001.11", "TASK-FE-001.12", "TASK-FE-001.13", "TASK-FE-001.14"]
implementation_selected: true
---

# TASK-FE-002.05: Адаптировать workspaces и контакты для iPhone

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

Адаптировать workspaces и контакты для iPhone. Один завершённый этап iOS/iPhone очереди.

## Context

Текущее поручение: пользователь выбрал весь перечисленный iOS объём .04/.05/.06/.07/.08/.10
и разрешил до 10 параллельных агентов. Единственный writer этой карточки и её
текущего exact scope — `primary-agent` после handoff от `/root/ios_workspaces_batch`. Выполняется выбранная реализация
с проверками Simulator/host; исходные physical acceptance criteria сохраняются.
Предыдущие последовательные write gates заменены назначенными непересекающимися
scopes для разработки, интеграционные зависимости остаются обязательными для
проверки результата. .03 physical blocker не объявляется снятым; .09 не выбрана,
полный suspend/resume recovery в .10 не реализуется автоматически.
Scope .04 — оставшийся login UI, .08/.10 — мобильная компоновка и существующие
flows; восстановление upload/lifecycle вне .09 не расширяется.
Baseline: `/tmp/dictai-ios-batch-baseline/`. Правила интеграции и owner общих файлов
см. в начале active-plan и ADR-FE-011; прежние записи ниже — история.

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Последующее поручение 2026-11-16 выбрало реализацию .01–.05 пятью агентами.
Write gate и owner назначены в active-plan; зависимости проверяются до записи.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.10](../tasks/TASK-FE-001.10.md), [TASK-FE-001.11](../tasks/TASK-FE-001.11.md), [TASK-FE-001.12](../tasks/TASK-FE-001.12.md), [TASK-FE-001.13](../tasks/TASK-FE-001.13.md), [TASK-FE-001.14](../tasks/TASK-FE-001.14.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Список, создание/переименование workspace и CRUD name/email contacts доступны одной рукой, с клавиатурой и увеличенным текстом.
- [ ] Новая запись переносит корректный workspace; можно записывать без workspace под авторизованным владельцем.
- [ ] Loading/empty/error/повтор и удаление контакта отображаются по реальным ответам, поздний ответ после logout не показывает данные.
- [ ] Нет запроса системной адресной книги, voice profiles или Speaker assignments; текущие contacts API сохраняются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Это адаптация существующего CRUD, не новая интеграция backend. Системные iOS Contacts не требуются.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification текущей реализации .05 — 2026-11-16

Cwd всех команд: `/Users/mxdnght/dictai-app`; Flutter 3.41.3 / Dart 3.11.1
из `/tmp/dictai-flutter-3.41.3/bin/`, существующий package_config, no pub/lock
updates. Общий iOS build/install/launch выполняет coordinator после handoff.

| Command / scenario | Expected | Actual | Status | Limitation |
|---|---|---|---|---|
| `flutter --no-version-check test --no-pub test/features/workspace/ios_workspace_test.dart` | Мобильные CRUD/layout/session сценарии | 11 tests PASS | PASS | iOS-themed widget tests с настоящим GoRouter и scripted Dio; не реальный iPhone/HTTP |
| `flutter --no-version-check test --no-pub test/features/workspace/ios_workspace_test.dart test/features/workspace/workspace_crud_widget_test.dart test/features/workspace/contact_crud_widget_test.dart` | Новый mobile scope + прежние workspace/contact CRUD/reconciliation | 36 tests PASS | PASS | Без параллельно изменяемого RecordScreen |
| `dart format --output=none --set-exit-if-changed lib/features/workspace/presentation/workspaces_screen.dart lib/features/workspace/presentation/workspace_detail_screen.dart lib/features/workspace/presentation/workspace_notifier.dart test/features/workspace/ios_workspace_test.dart` | Формат корректен | 4 files, 0 changed, exit0 | PASS | Scoped format |
| `dart analyze lib/features/workspace/presentation/workspaces_screen.dart lib/features/workspace/presentation/workspace_detail_screen.dart lib/features/workspace/presentation/workspace_notifier.dart test/features/workspace/ios_workspace_test.dart` | Нет diagnostics | No issues found, exit0 | PASS | Общий analyze выполняет coordinator после интеграции |
| Те же три suite + `profile_free_flow_test.dart` и `workspace_record_start_test.dart` | Интеграционная регрессия с RecordScreen | 49/50 PASS на промежуточном parallel snapshot: profile_free_flow:263 option `Empty workspace` оказался за viewport1280×900 | FAIL | Передано coordinator/ios_record_ui; до параллельного изменения RecordScreen прежние 41 tests PASS; промежуточный FAIL не помечен исправленным |
| `git diff --check -- <четыре Dart paths>`; полный diff source/test | Нет whitespace и выхода за scope | Diagnostics нет; source/new test просмотрены целиком | PASS | Сохранность всего исходного diff дополнительно проверяет coordinator |
| Simulator/iPhone: VoiceOver focus, клавиатура, workspace → Record UI taps | Реальный пользовательский путь | Не выполнялось исполнителем .05 | NOT RUN | Build/runtime/native проверки централизованы у coordinator; physical signing недоступна |
| Независимый REVIEW-FE-002.04-02 | Review выбранного batch, в том числе .05 | Ожидается после handoff | NOT RUN | Самопроверка не заменяет independent review |

Покрытие новых tests: ширины320/375/430 с text scale2 и keyboard220; создание
workspace; landscape640×375 с text1.5/keyboard100 и add/edit/remove contact;
контакт/форма на320×568 text2/keyboard160; error/retry/empty; rename и передача
workspaceId плюс typed WorkspaceDto в Record; logout и поздние list/detail/mutation
responses; external unauthorized event; новая login-session не видит данные прежней.

## Result текущей реализации .05 — 2026-11-16

Owner `/root/ios_workspaces_batch`, status implemented: подготовлены mobile
list/detail/workspace/contact формы, проверки выполнены в своём exact scope,
интеграция и независимый review coordinator ещё не завершены. Accepted не назначен.

Изменены только три presentation Dart файла, новый
`test/features/workspace/ios_workspace_test.dart` и эта карточка.
`WorkspacesScreen` использует slivers: на узком экране список карточек с естественной
высотой и переносимые actions, на широком desktop остаётся grid. Весь detail
прокручивается; заголовок, «Новая запись», rename/refresh и контакты доступны
при уменьшенной высоте, клавиатуре и увеличенном тексте. Contact card показывает
name/email отдельно от редактирования/удаления. Dialog contents прокручиваются,
actions остаются доступны, поля имеют соответствующие keyboard actions.

Workspace/detail notifier синхронно очищаются на auth/session event и отбрасывают
поздние ответы; успешный login создаёт новый instance и новый load. Между GET detail
и GET contacts повторно проверяется принадлежность текущей сессии: после logout
старый load не начинает следующий запрос. Dialog fields очищаются и root route
диалога удаляется при смене сессии, в том числе при pending mutation. Существующие
W01–W09 API/DTO, validation и uncertainty/reconciliation сохраняются; backend,
общие providers/router/auth/RecordNotifier, зависимости и разрешения не менялись.
Нет Contacts access, voice profiles, speaker assignment или выдуманных данных.

11 новых tests и36 scoped tests PASS; scoped analyze/format PASS. Промежуточный
integration FAIL в profile_free_flow передан владельцу Record UI и coordinator,
не объявлен закрытым. Все phone hardware/VoiceOver/manual criteria остаются
неподтверждёнными; отдельная auth/signing .03 не закрывается. Весь batch после
handoff должен получить общий regression/build/launch и независимый review.
Commit/push/merge/release не выполнялись.

## Историческая Verification до текущей реализации

Cwd: `/Users/mxdnght/dictai-app`. В этом проходе меняется только карточка;
чтение текущих исходников — preflight, не проверка поведения приложения.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| Flutter tests / scoped format / flutter analyze | frontend | Проверки мобильной адаптации и нового теста | Реализация не начата, `test/features/workspace/ios_workspace_test.dart` не создан | NOT RUN | Write gate закрыт до обязательных checks и независимого review .04; Dart-код не меняется |
| Workspace → новая запись / формы с клавиатурой / VoiceOver focus | frontend / iOS Simulator | Подтверждённый мобильный путь .05 | Не выполнялось | NOT RUN | Зависимость .04 заблокирована до обязательных checks/review .03; успешный запуск scaffold .02 не подтверждает сценарии .05 |
| Evidence зависимости .02: [REVIEW-FE-002.02-03](../reviews/REVIEW-FE-002.02-03.md) и handoff coordinator | Flutter 3.41.3 / iOS 26.5 / iPhone 17 Pro Simulator | Закрыт прежний runtime blocker .02 | Actual build/install/launch/render PASS; независимый review reviewed/complete, actionable findings нет | PASS | Прочитано evidence .02 и handoff; исполнитель .05 команды не повторял, собственная функциональная проверка .05 не выполнена |
| `ruby -ryaml -e 'YAML.safe_load(File.read(ARGV.fetch(0)).split("---", 3).fetch(1)); puts "PASS YAML"' docs/ai/tasks/TASK-FE-002.05.md` | frontend / Ruby Psych | Валидный frontmatter | Frontmatter разобран без ошибок | PASS | Проверка только документа |
| `python3 /tmp/check_dictai_ios_workspace_task.py` | frontend / Python 3 stdlib | Ссылки, owner/selection/dependency, unchecked criteria и отсутствие planned test согласованы | Проверки карточки пройдены | PASS | Временный checker вне продуктового diff; не проверяет приложение |
| `git diff --check -- docs/ai/tasks/TASK-FE-002.05.md`; полный diff карточки | frontend / Git | Нет whitespace diagnostics; изменена только запись выбранной задачи | Diagnostics нет, полный diff просмотрен | PASS | Проверка только своей карточки; чужой параллельный diff не оценивался |
| Исторический независимый review [REVIEW-FE-002.03-01](../reviews/REVIEW-FE-002.03-01.md) | `/root/ios_queue_review`, только документационный scope прежнего прохода | Проверены blocker cards .03–.05 и координационные записи того прохода | reviewed/complete, actionable findings нет | PASS | Не подтверждает текущую реализацию .03, функциональные проверки .05 или это последующее обновление карточки |

## Исторический Result до текущей реализации

### Текущее состояние после возобновления .02/.03 — 2026-11-16

Owner `/root/ios_workspaces`, status **blocked**, functional write gate закрыт.
В этом обновлении изменена только эта карточка; workspace screens/notifier
и planned test `test/features/workspace/ios_workspace_test.dart` не менялись.
Все acceptance criteria остаются unchecked, `implementation_selected: true`
сохранён. Verified/accepted не заявлены, публикация не разрешена.

Прежний runtime blocker [TASK-FE-002.02](TASK-FE-002.02.md) устранён: coordinator
подтвердил actual Simulator build/install/launch/render на Flutter 3.41.3,
iOS 26.5, iPhone 17 Pro. Независимый [REVIEW-FE-002.02-03](../reviews/REVIEW-FE-002.02-03.md)
завершён без findings. Исполнитель .05 прочитал отчёт и handoff; сборку и команды
Simulator не повторял. Исторический FAIL SDK 3.44/lock ниже не описывает текущее
состояние .02.

Прямой blocker .05 сохраняется: [TASK-FE-002.04](TASK-FE-002.04.md) заблокирована
до обязательных checks и независимого review [TASK-FE-002.03](TASK-FE-002.03.md).
По финальному evidence coordinator targeted60/full561/analyze и девять native
Keychain/HTTPS/auth phases .03 PASS на Simulator; independent .03-02 завершён без открытых findings. Обязательные physical iPhone
checks .03 остаются NOT RUN: подпись недоступна по сообщению пользователя.
Успешные Simulator scaffold и unit/widget проверки не заменяют эти device gates.

Условие возобновления .05: обязательные проверки и независимый review .04
завершены без блокирующих findings, coordinator передал exact write scope .05.
Текущее документационное обновление независимо проверено в REVIEW-FE-002.03-02
вместе с возобновлённым scope .03; открытых findings нет. .03-01 относится к истории.
Риски мобильной компоновки и позднего ответа после logout, перечисленные ниже,
остаются неподтверждёнными функциональными проверками и не исправлялись.

### Первый блокирующий проход — история, не текущий blocker .02

Следующая запись сохранена как evidence первого прохода до успешной сборки и
запуска .02 и до возобновления реализации .03. Её FAIL/NOT RUN не заменяют
текущее evidence выше; review .03-01 проверял документацию того прохода.

2026-11-16, owner `/root/ios_workspaces`: выбранная задача **blocked**.
Исполнитель изменил только эту карточку; workspace screens/notifier и тесты
не менялись. Owner, `implementation_selected: true` и все критерии сохранены;
`accepted` не выставлен, публикация не разрешена.

Прямой blocker — [TASK-FE-002.04](TASK-FE-002.04.md) имеет status blocked и
не имеет обязательного evidence реализации и её checks/review. По handoff координатора
`/root`, её зависимость [TASK-FE-002.03](TASK-FE-002.03.md) не может подтвердить
обязательные iPhone Keychain/auth/HTTPS сценарии: пользователь сообщил, что
подпись недоступна; coordinator проверил 0 signing identities и 0 provisioning
profiles. Также coordinator сообщил о FAIL exit 65 команды
`flutter pub get --enforce-lockfile` в .02: SDK 3.44 использует pins, отличные
от lock для `matcher`, `meta` и `test_api`. До решения совместимости SDK/lock
compile/launch не подтверждены. Это сведения координатора, исполнитель .05
не повторял эти команды и не считает их своими результатами проверки.

Read-only preflight: существующие CRUD/reconciliation и передачу workspace
в `/record` можно переиспользовать. Для iPhone нужны адаптивные header/actions,
прокрутка detail/форм при клавиатуре и компоновка контактов с увеличенным текстом.
Отдельный риск — долгоживущие workspace providers явно не слушают смену сессии;
будущий тест должен проверить, что поздний ответ после logout не возвращает
данные прежнего аккаунта. Этот риск исследован по исходникам, не исправлен и
не подтверждён runtime-тестом. Reuse tests: `workspace_crud_widget_test.dart`,
`contact_crud_widget_test.dart`, `profile_free_flow_test.dart` и
`workspace_record_start_test.dart`; их прежние результаты не объявляются iOS PASS.

Условие возобновления: обязательные проверки и независимый review .04 завершены
без блокирующих findings, coordinator передал write gate exact scope .05.
Независимый [REVIEW-FE-002.03-01](../reviews/REVIEW-FE-002.03-01.md) завершён
агентом `/root/ios_queue_review`: reviewed/complete, actionable findings нет.
Проверены blocker cards и учёт, функциональная реализация .03–.05 не выполнена.
Review документации не заменяет проверки зависимостей, не меняет status blocked
и не разрешает автоматически обойти последовательную очередь.
