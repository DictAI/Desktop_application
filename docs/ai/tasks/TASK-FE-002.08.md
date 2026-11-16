---
id: "TASK-FE-002.08"
plan: "PLAN-FE-002"
title: "Собрать мобильный экран записи и безопасный Stop/уход"
status: "review"
owner: "primary-agent"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.07"]
scope: ["lib/features/record/presentation/record_screen.dart", "lib/features/record/presentation/finish_recording_dialog.dart", "lib/features/record/presentation/record_exit_guard.dart", "test/features/record/ios_record_flow_test.dart", "test/features/record/record_confirmation_test.dart", "docs/ai/tasks/TASK-FE-002.08.md"]
planned_paths: ["test/features/record/ios_record_flow_test.dart"]
reuses_tasks: ["TASK-FE-001.23", "TASK-FE-001.24", "TASK-FE-001.49"]
implementation_selected: true
---

# TASK-FE-002.08: Собрать мобильный экран записи и безопасный Stop/уход

## Новое требование поверх базовой .08 — 2026-11-17

Пользователь попросил добавить новый сценарий управления записью. Он вынесен
в [TASK-FE-002.20](TASK-FE-002.20.md), draft/implementation_selected=false:
основной tap ставит recording на паузу и возобновляет paused; на паузе доступны
зелёная «Отправить» и крестик с подтверждением удаления. Уход из recording/paused
предлагает отменить текущую локальную запись и выйти либо остаться.
Прежняя iOS-политика Stop/отправки при уходе заменяется этим новым требованием;
реализация .20 ещё не начата, текущий код .08 сохраняет прежнее поведение.

Статус review и критерии базовой .08 ниже описывают уже проверенный старый scope,
не реализацию новых требований. Накопленные результаты и независимые отчёты
не переписываются и не используются как PASS .20; новое evidence требуется отдельно.

## Историческая интеграционная Verification / Result базовой .08 — 2026-11-17

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

Собрать мобильный экран записи и безопасный Stop/уход. Один завершённый этап iOS/iPhone очереди.

## Context

Текущее поручение: пользователь выбрал весь перечисленный iOS объём .04/.05/.06/.07/.08/.10
и разрешил до 10 параллельных агентов. Единственный writer этой карточки и её
текущего exact scope — `primary-agent` после handoff от `/root/ios_record_ui`. Выполняется выбранная реализация
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
Первоначальный planning snapshot разрешал только перепланирование; реализация
теперь явно выбрана новым поручением выше.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.23](../tasks/TASK-FE-001.23.md), [TASK-FE-001.24](../tasks/TASK-FE-001.24.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria базовой .08 до дополнения .20

- [ ] На iPhone доступны mic/импорт WAV, workspace/без него и действующие language/mixed options; неподдерживаемый system audio скрыт, выбор snapshot фиксируется до Start.
- [ ] Record/Pause/Resume/Stop, таймер и ошибки отражают реальное состояние capture, не декоративную анимацию/фиктивные проценты.
- [ ] Stop, вкладки, Back/swipe и уход из workspace вызывают единое подтверждение: продолжить сохраняет запись, завершить даёт один finalized WAV и одну отправку; double tap безопасен.
- [ ] Блокировка/сворачивание не трактуется как подтверждённый Stop; interruption state приходит из .06. Политика принудительного logout отдельно безопасно освобождает recorder.
- [ ] Нет overflow на малом iPhone/landscape/увеличенном тексте; controls понятны VoiceOver и имеют удобную область касания.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Оба режима записи используют общий V2 flow. Anonymous означает без workspace, не без авторизации; legacy confirm не подключать.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification реализации mobile UI — 2026-11-16

Cwd: `/Users/mxdnght/dictai-app`; Flutter 3.41.3 / Dart 3.11.1 из
`/tmp/dictai-flutter-3.41.3/bin/`, macOS. Package configuration уже подготовлена;
SDK, pubspec и lock не менялись. Тесты изолируют capture и HTTP fakes; это host
unit/widget evidence, не доказательство реальной записи на iPhone.

| Command / scenario | Expected | Actual | Status | Limitation |
|---|---|---|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/record/presentation/record_screen.dart lib/features/record/presentation/finish_recording_dialog.dart lib/features/record/presentation/record_exit_guard.dart test/features/record/ios_record_flow_test.dart test/features/record/record_confirmation_test.dart` | Scoped Dart отформатирован | Проверка пяти файлов без изменений | PASS | Другие параллельные scopes не форматировались |
| `flutter --no-version-check analyze --no-pub lib/features/record/presentation/record_screen.dart lib/features/record/presentation/finish_recording_dialog.dart lib/features/record/presentation/record_exit_guard.dart test/features/record/ios_record_flow_test.dart test/features/record/record_confirmation_test.dart` | Нет diagnostics | Exit0, No issues found | PASS | Scoped analyzer; общий выполняет coordinator; log `/tmp/dictai-ios-record-ui-analyze.log` |
| `flutter --no-version-check test --no-pub test/features/record/ios_record_flow_test.dart test/features/record/record_confirmation_test.dart test/features/record/ordinary_flow_test.dart test/features/record/anonymous_flow_test.dart test/features/workspace/workspace_record_start_test.dart` | Mobile layout и существующие recording/upload/route guards сохранены | Exit0, 55 tests PASS | PASS | 11 новых UI tests, 8 guard scenarios повторены desktop/iOS, 28 существующих flow/route tests; log `/tmp/dictai-ios-record-ui-tests.log` |
| Initial scoped analyze/tests | Компиляция новых typed listener/tests | FAIL: ambiguous RecordState import и отсутствующий foundation import; затем исправлены `show InputDevice` и test import | FAIL, исправлен | Последний scoped analyze и 55 tests PASS; отдельная временная ошибка параллельной незавершённой UploadModal также исчезла после handoff owner |
| Initial accessibility test | Semantics handle закрывается до конца widget test | FAIL: disposal через addTearDown опаздывал для widget assertion; перенесён в конец test | FAIL, исправлен | Последние 55 tests PASS |
| Initial desktop regression | Сохранены desktop geometry и прежние fixture действия | FAIL: adaptive switch увеличил desktop height; исходный desktop toggle восстановлен, новый adaptive только iOS | FAIL, исправлен | Последние anonymous/ordinary/workspace-route tests PASS; профильный общий fixture имел отдельный async Files import timeout, передан root/files owner |
| `git diff --check -- <scope>`; полный tracked/no-index diff; YAML/локальные ссылки карточки | Diff без whitespace и корректная карточка | Scoped diff и новый test просмотрены целиком; frontmatter/links валидны | PASS | Сохранность общего baseline и отчёт всего batch проверяет coordinator |
| Общая iOS Simulator сборка/install/launch и интеграционный cross-feature smoke | Реальная сборка всех выбранных задач | Передано coordinator после source handoff | NOT RUN исполнителем .08 | Native/Xcode builds выполняет только root, чтобы не столкнуть параллельные сборки |
| Физический iPhone: microphone/lock/background/interruption/реальный swipe/VoiceOver | Подтверждённый device flow | Не выполнялось: device signing отсутствует | NOT RUN | UI тесты и fake capture не закрывают physical criteria .03/.06/.08 |
| Независимый review | Полная проверка implementation + документации другим агентом | Передано root для REVIEW-FE-002.04-02 | NOT RUN исполнителем .08 | Status implemented, не verified/accepted |

## Result реализации mobile UI — 2026-11-16

Изменены `record_screen.dart`, `finish_recording_dialog.dart`,
`record_confirmation_test.dart`; создан `ios_record_flow_test.dart`; обновлена
эта карточка. `record_exit_guard.dart` прочитан и оставлен без изменений:
существующий guard уже возвращает отказ route exit, использует единую confirmation
для Stop/вкладок/Back, не дублирует завершение и закрывает stale dialog при logout.
Router, notifier, AudioCapture, shared providers и UploadModal этим исполнителем
не менялись; публичные контракты согласованы с owners .06/.07.

На iOS отсутствуют desktop device picker, BlackHole/system audio controls и
ранний `refreshDevices` до действия пользователя. Record content ограничен
360 logical px с мобильными горизонтальными отступами 16 и прокруткой; fixed-width
дочерние controls получают ограничения родителя. Workspace/no-workspace и
language/mixed управляют тем же RecordNotifier. Кнопки Start/Stop, Pause/Resume,
Upload и создания workspace имеют доступные названия и targets не менее 48 px;
workspace selector/clear доступны отдельными controls. Диалог подтверждения
прокручивается и помещается на узком landscape с увеличенным текстом.

Таймер показывает прошедшее время активного состояния capture через Stopwatch:
стартует после подтверждённого `RecordStatus.recording`, останавливается при paused,
preparing/error, сбрасывается при новом starting. Это время активной записи по
state transitions, не sample-точная длительность WAV. UI Timer только обновляет
показание и освобождается при dispose; upload/poll/recorder им не управляются.
Interruption из .06 отражается existing paused/errorMessage, без автоматического
resume. Причина interruption показывается рядом со статусом и объявляется
семантически; фон/lock не интерпретируются UI как подтверждённый Stop.

Проверены 320/375/430 при text scale 1/2, landscape/scroll, доступность Start,
реакция таймера на paused/resume/error, маленький confirmation dialog. Existing
actual App/router guard scenarios теперь повторены при iOS 375×812 и desktop:
cancel/Escape, вкладки/Back, однократные WAV/POST при confirm, запрет ухода during
starting, invalid WAV и logout/401 cleanup. Desktop исходный toggle сохранён.

Status implemented означает готовый выбранный UI scope и локальные PASS checks.
Полная готовность iOS, физическая запись/VoiceOver/swipe/background и независимое
review ещё не заявляются; .09 lifecycle/upload recovery не реализована. Полные
acceptance criteria выше остаются открытыми до интеграционного/device evidence.
Commit/push/merge/release и accepted не выполнялись.

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/record/ios_record_flow_test.dart; scoped format; flutter analyze; iPhone smoke | frontend | Acceptance criteria | Первоначально не выполнялось | NOT RUN | Только planning snapshot |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS; на том этапе
реализация и её проверки не выполнялись. Эти прежние записи не заменяют текущие
Verification/Result выше. Приёмка и публикация отсутствуют.
