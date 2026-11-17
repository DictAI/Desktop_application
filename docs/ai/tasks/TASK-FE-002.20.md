---
id: "TASK-FE-002.20"
plan: "PLAN-FE-002"
title: "Изменить управление записью: пауза, отправка и подтверждённая отмена"
status: "review"
owner: "/root/record_controls"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.08"]
scope: ["lib/features/record/presentation/record_screen.dart", "lib/features/record/presentation/record_notifier.dart", "lib/features/record/presentation/record_exit_guard.dart", "lib/features/record/presentation/discard_recording_screen.dart", "lib/features/record/presentation/discard_recording_dialog.dart", "lib/core/router/app_router.dart", "lib/core/shell/main_shell.dart", "test/features/record/ios_record_flow_test.dart", "test/features/record/record_confirmation_test.dart", "test/features/record/record_discard_test.dart", "test/core/router/ios_navigation_test.dart", "docs/ai/tasks/TASK-FE-002.20.md"]
planned_paths: ["lib/features/record/presentation/discard_recording_screen.dart", "lib/features/record/presentation/discard_recording_dialog.dart", "test/features/record/record_discard_test.dart"]
reuses_tasks: ["TASK-FE-002.06", "TASK-FE-002.08", "TASK-FE-001.49"]
implementation_selected: true
---

# TASK-FE-002.20: Изменить управление записью: пауза, отправка и подтверждённая отмена

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Result реализации — 2026-11-17

Sole writer `/root/record_controls` реализовал exact .20 scope. Изменены
`record_screen.dart`, `record_notifier.dart`, `record_exit_guard.dart`,
`main_shell.dart`, `ios_record_flow_test.dart`, `record_confirmation_test.dart`
и эта карточка; созданы `discard_recording_screen.dart`,
`discard_recording_dialog.dart`, `record_discard_test.dart`.
`app_router.dart` и `ios_navigation_test.dart` прочитаны и не менялись:
существующий `onExit` принимает FutureOr<bool> нового guard, сохраняя намерение
GoRouter (route/query/extra) до успешного удаления. API/native/dependencies,
пользовательские WAV, журналы и desktop Stop/guard сохранены.

На iOS основная кнопка ставит capture на паузу/возобновляет его; на паузе
появляются зелёная текстовая «Отправить» и крестик. Отправка использует один
существующий finish/journal/V2 POST с сохранённым snapshot options. Крестик
показывает окно удаления и остаётся в Record, уход/намеренный logout — отдельную
страницу отмены; «Остаться»/Back/закрытие не изменяют capture/паузу. Forced401
не ждёт подтверждения, старые страницы/диалоги закрываются по identity.
Operation revision не позволяет позднему подтверждению завершить новый flow.

Новый идемпотентный discard резервирует действие, ждёт pause/resume и native
dispose, затем удаляет ровно собственный capture source. Не вызывает finish,
journal или POST; не удаляет родительскую папку/соседние/импортированные файлы.
Ошибки dispose/удаления сохраняют ownership и явный повтор удаления; Send,
Start и Resume остаются заблокированными до cleanup. Interruption во время
подтверждения сохраняется, открытия окон не запускают скрытый Stop/Resume.

Status review означает передачу готового host implementation на независимую
проверку [REVIEW-FE-002.20-02](../reviews/REVIEW-FE-002.20-02.md).
Полная .20 не verified/accepted: физический iPhone/реальный swipe/VoiceOver,
interruption и кнопочные сценарии на устройстве не выполнялись. Отдельная
приёмка .03 с physical exceptions не выдаётся за hardware PASS этой задачи.

## Verification реализации — 2026-11-17

Cwd всех команд `/Users/mxdnght/dictai-app`, macOS, закреплённый SDK
`/tmp/dictai-flutter-3.41.3` (Flutter3.41.3/Dart3.11.1), подготовленный lock.
Команды автора `/root/record_controls`, Simulator evidence отдельно от root.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter test --no-pub test/features/record/record_discard_test.dart test/features/record/ios_record_flow_test.dart test/features/record/record_confirmation_test.dart test/core/router/ios_navigation_test.dart test/features/record/ios_audio_capture_test.dart test/features/record/ordinary_flow_test.dart test/features/record/anonymous_flow_test.dart test/features/workspace/workspace_record_start_test.dart --reporter expanded` | 102/102 tests, exit0; новый discard suite23 cases | PASS | Host/fake capture/channel/HTTP и synthetic WAV; не устройство |
| `dart format --output=none --set-exit-if-changed` с девятью изменёнными/новыми Dart paths, перечисленными в Result | 9 files, 0 changed, exit0 | PASS | Dart SDK по закреплённому пути выше |
| `/tmp/dictai-flutter-3.41.3/bin/flutter analyze --no-pub --no-fatal-infos` | exit0, 7 прежних info, 0 errors/warnings, новых info нет | PASS | Семь прежних info вне .20 scope не исправляются |
| Initial new test harness runs | FAIL debug platform override lifecycle и pending fixture auth timers; переведён на explicit iOS theme и teardown внутри widget callback; final102 PASS | FAIL, исторический | Ошибки нового fixture, не заявлены успешными прогонами |
| Simulator production main build/install/launch/render, root | Intermediate build7.9s и build7.0s PASS, финальный repeat после revision hardening выполняет coordinator | PASS, intermediate | Idle render smoke; не реальный mic/buttons, финальный build evidence добавляет root |
| Physical iPhone pause/resume/send/discard, navigation swipe/VoiceOver/interruption | Не выполнялось, подготовленной подписи нет | NOT RUN | Full physical acceptance открыта |
| Independent implementation review .20-02 | Передано `/root/acceptance_review`, source/tests frozen | IN REVIEW | Итог в назначенном report; self-check не заменяет review |

## Goal

На iPhone основной кнопкой ставить запись на паузу и возобновлять её; из паузы
явно отправлять WAV либо удалять текущую запись с подтверждением. Уход с экрана
активной или приостановленной записи предлагает отменить её и выйти.

Это новая задача поверх базовой .08; реализация выбрана последующим поручением
2026-11-17. Код и host tests готовы, независимое review выполняется; полные
physical criteria и пользовательская приёмка не заявляются.

## Context

Прямое поручение пользователя 2026-11-17: повторное нажатие во время записи
ставит её на паузу; появляется зелёная кнопка отправки; нажатие кнопки паузы
возобновляет запись. При попытке уйти во время записи/паузы нужен экран с
предложением отменить запись; на паузе нужен крестик с подтверждением удаления.

[PLAN-FE-002](../plans/PLAN-FE-002.md), [реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [iOS UX](../research/IOS_TARGET_UX.ru.md),
ADR-FE-012 в [decisions](../decisions.md). Зависимость —
[базовый мобильный Record .08](TASK-FE-002.08.md); следом выполняется
[recovery .09](TASK-FE-002.09.md). Старые .08 checks/review сохраняют evidence
прежнего интерфейса, новые критерии ими не подтверждены.

Проверены текущие исходники: главная кнопка RecordScreen вызывает прежний
Stop/confirmFinish, Pause/Resume находится отдельно; guard предлагает
«Продолжить запись» / «Завершить и отправить». RecordNotifier умеет togglePause
и finishRecording, но не имеет явного действия discard. AudioCapture.dispose
освобождает recorder, сохраняя исходник; reset не удаляет активную запись.
Поэтому одного изменения иконок недостаточно. Router/нижние вкладки используют
общий guard, auth/session уже инвалидируют устаревшие операции.

Новые требования заменяют прежнюю iOS-политику Stop/выхода с отправкой только
для текущей ещё не отправленной записи. Desktop-поведение, импортированный
пользовательский WAV, pending uploads/jobs и готовые серверные результаты
сохраняют свои правила. API cancel/delete для серверной обработки не добавляются.

## Acceptance criteria

- [ ] В idle основная кнопка начинает запись. При recording повторное нажатие
  этой же кнопки вызывает реальную паузу capture, без финализации, upload и
  окна Stop. В paused основная кнопка паузы/продолжения возобновляет ту же запись.
  Timer исключает паузу; состояние/semantics отражают фактический capture.
- [ ] На паузе появляется отдельная зелёная кнопка «Отправить». Нажатие
  финализирует один WAV и вызывает одну существующую V2-отправку. Возобновление
  скрывает действия паузы. Double tap и гонки pause/resume/send не создают
  дублирующий recorder/WAV/POST; исходный snapshot workspace/language сохраняется.
- [ ] На паузе виден крестик с доступным названием «Удалить запись».
  Нажатие открывает окно «Удалить запись?» с пояснением потери текущей записи,
  безопасным действием «Оставить запись» и подтверждением «Удалить».
  Отказ/Back/закрытие окна сохраняют paused и WAV; автоматического resume нет.
  Подтверждение удаляет текущую запись и возвращает idle на экране Record.
- [ ] Попытка ухода через вкладки/Back/swipe/другой маршрут во время recording
  или paused открывает отдельный экран предложения отмены записи с действиями
  «Остаться» и «Отменить запись и выйти». До подтверждения исходный переход
  заблокирован. «Остаться»/Back сохраняют запись и исходное состояние, включая
  паузу; уход не вызывает неявную отправку. При подтверждённой отмене текущая
  запись удаляется и выполняется исходно выбранный переход ровно один раз.
- [ ] Намеренный logout пользователя при recording/paused использует тот же
  экран до выхода из аккаунта: «Остаться» не вызывает logout. Принудительный
  401/expiry не блокируется подтверждением; применяется существующий безопасный
  session cleanup без неявной отправки и без доступа нового аккаунта к записи.
- [ ] Открытие окна/экрана подтверждения само по себе не останавливает запись
  и не возобновляет паузу. Системное interruption меняет capture-state по .06;
  закрытие подтверждения не отменяет этот факт. Новая запись/смена сессии делает
  старые подтверждения недействительными; logout/401 не оставляют зависший экран.
- [ ] Подтверждённая отмена — отдельная идемпотентная операция notifier:
  освобождает capture/subscription/timer и удаляет только принадлежащий текущему
  capture локальный исходник после завершения записи в файл. Нет journal entry,
  POST, восстановления отменённой записи или удаления чужого/импортированного WAV.
  Cleanup failure честно показан, не выдаётся за успешное удаление; разрешён
  повтор. Во время Starting/finalization/upload взаимоисключающие действия
  заблокированы; поздний ответ не может отправить отменённую запись.
- [ ] Controls и подтверждения доступны на iPhone 320/375/430 logical px,
  landscape и text scale 2, с VoiceOver/удобными hit targets. Отправка обозначена
  текстом/иконкой помимо зелёного цвета. Desktop Stop/guard regression сохранён.
- [ ] Назначен implementer и один writer общих notifier/router/shell файлов;
  проверки выполнены и независимый review завершён с явными physical limits.
  `accepted` требует отдельной приёмки пользователя.

## Implementation notes

Использовать существующий notifier, CaptureStatus, V2 journal и guard; отдельный
state-management слой, пакет, backend endpoint и платформенные разрешения
не требуются. Не подменять discard вызовом finishRecording/upload или reset.
Перед удалением сохранить identity/owned path и дождаться native cleanup;
удалять только собственный файл, без рекурсивной очистки tmp или пользовательских
Files. Безопасность cleanup проверяется также при logout и позднем callback.

Новый экран подтверждения ухода и окно крестика имеют разные исходы навигации:
после удаления крестиком остаёмся в Record; после подтверждения ухода выполняем
сохранённое назначение. Исходный route/query/extra учитываются, старое намерение
перехода не переживает смену сессии. Один guard предотвращает вложенные
подтверждения и повторные taps. Нынешний FinishRecordingDialog может остаться
для desktop; не переносить прежнюю iOS отправку из него в экран отмены.

Scope будущей реализации перечислен точно во frontmatter, новые файлы также
в planned_paths. Запись в AudioCapture/native/plugins/API/dependencies этим
scope не назначается. Пересечения .06/.08/.09 выполняются последовательно:
.08 → .20 → .09; эта карточка не запускает .09 автоматически.

## Исторический план Verification

Cwd: `/Users/mxdnght/dictai-app`; закреплённый Flutter 3.41.3 / Dart 3.11.1,
подготовленный lock без обновления SDK/packages. Команды ниже — план реализации.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `dart format --output=none --set-exit-if-changed <Dart scope>`; `flutter analyze --no-pub` | frontend / pinned SDK | Changed Dart format и diagnostics проверены | Не запускалось | NOT RUN | Сейчас только планирование; прежние info фиксировать отдельно |
| `flutter test --no-pub test/features/record/ios_record_flow_test.dart test/features/record/record_confirmation_test.dart test/features/record/record_discard_test.dart test/core/router/ios_navigation_test.dart` | frontend / fakes, synthetic owned WAV | Повторный tap→pause→resume; зелёная send только на паузе; один POST; X confirm/cancel; recording/paused leave/back/swipe; navigation/session races; own-file cleanup/retry | Не запускалось | NOT RUN | record_discard_test — planned path, host tests не доказывают hardware |
| `flutter test --no-pub test/features/record/ios_audio_capture_test.dart test/features/record/ordinary_flow_test.dart test/features/record/anonymous_flow_test.dart test/features/workspace/workspace_record_start_test.dart` | frontend / pinned SDK | Capture/session и оба V2 режима, desktop regression сохранены | Не запускалось | NOT RUN | Будущая проверка shared notifier/guard изменений |
| `flutter build ios --simulator --debug --no-pub` с действующей public gateway config; Simulator UI smoke | frontend / macOS/Xcode | Сборка/запуск и сценарии кнопок/подтверждений | Не запускалось | NOT RUN | Не заменяет iPhone |
| Физический iPhone: реальный pause/resume, send/cancel, Back/swipe, VoiceOver и interruption во время подтверждения | iPhone / подготовленная подпись | Нет скрытого Stop/resume/upload или потери чужих файлов | Не запускалось | NOT RUN | Нужны устройство/подпись; physical gates .03/.06 сохраняются |

## Verification текущего planning diff — 2026-11-17

Cwd: `/Users/mxdnght/dictai-app`; Python3/Ruby Psych, Git, macOS.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `python3 /tmp/check_dictai_record_controls_plan.py` | YAML/ID/DAG20 задач, .08→.20→.09, таблица/scope/planned paths, локальные ссылки, selected IDs, baseline355/HEAD/staging проверены | PASS | Checker вне repo, только документы; лог `/tmp/dictai-record-controls-plan-doc-check.log` |
| `git diff --check`; incremental diff шести документов и полный новый task/review | Whitespace diagnostics нет, изменения ограничены назначенным planning scope | PASS | Новые файлы отдельно checked через no-index, source/tests сохранены |
| Независимый `/tmp/review_dictai_record_controls_plan.py` | Reviewer подтвердил YAML/DAG/table/selection/links и preservation baseline355 | PASS | Самостоятельная проверка другого агента; не приложение |
| Flutter format/analyze/tests/build, Simulator/iPhone smoke | Не запускались в этом поручении | NOT RUN | Код/конфигурация не менялись; runtime критерии .20 ещё не реализованы |

Независимый planning-review: [REVIEW-FE-002.20-01](../reviews/REVIEW-FE-002.20-01.md),
reviewer `/root/record_controls_plan_review`; итоговые completion/findings — в отчёте.
Ранее завершённые runtime checks .08 не переносятся на новые требования.

## Исторический Result планирования

2026-11-17: добавлена draft-карточка по прямому поручению пользователя.
Обновлены iOS UX/ADR, очередь плана, ссылка из .08 и dependency .09.
Implementation_selected=false, implementer unassigned; код и тесты не менялись.
Baseline355: только6 изменённых документов и2 новых planning/review файла;
остальные349 файлов, включая весь source/tests/platform/dependencies/старые
review reports и посторонний .DS_Store, побайтово сохранены.
Documentation checks и independent planning review фиксируются в актуальном
разделе PLAN-FE-002/active-plan и
[REVIEW-FE-002.20-01](../reviews/REVIEW-FE-002.20-01.md).
Новые UI-сценарии не implemented/verified/accepted. Commit/push/release не поручены.


## Итог coordinator build — 2026-11-17

Cwd frontend, macOS/Xcode26.5, pinned Flutter3.41.3. После final freeze
`python3 /tmp/dictai_ios_max_build.py` (production main, Simulator debug,
--no-pub, сохранённый public HTTPS define без credentials): PASS exit0,
Xcode7.3s. `xcrun simctl install`/`launch --terminate-running-process`: PASS.
Предыдущий render Record idle визуально проверен, screenshot вне repo
`/tmp/dictai-ios-max-screen.png`; аппаратная запись и interaction smoke
не выполнялись. Intermediate builds7.9s/7.0s не заменяют final build.
Независимый reviewer повторил102 tests/format9 PASS, исходники/tests frozen.
Полная physical readiness не заявлена; accepted отсутствует.
