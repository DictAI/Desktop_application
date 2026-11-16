---
id: "TASK-FE-002.20"
plan: "PLAN-FE-002"
title: "Изменить управление записью: пауза, отправка и подтверждённая отмена"
status: "draft"
owner: "unassigned"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.08"]
scope: ["lib/features/record/presentation/record_screen.dart", "lib/features/record/presentation/record_notifier.dart", "lib/features/record/presentation/record_exit_guard.dart", "lib/features/record/presentation/discard_recording_screen.dart", "lib/features/record/presentation/discard_recording_dialog.dart", "lib/core/router/app_router.dart", "lib/core/shell/main_shell.dart", "test/features/record/ios_record_flow_test.dart", "test/features/record/record_confirmation_test.dart", "test/features/record/record_discard_test.dart", "test/core/router/ios_navigation_test.dart", "docs/ai/tasks/TASK-FE-002.20.md"]
planned_paths: ["lib/features/record/presentation/discard_recording_screen.dart", "lib/features/record/presentation/discard_recording_dialog.dart", "test/features/record/record_discard_test.dart"]
reuses_tasks: ["TASK-FE-002.06", "TASK-FE-002.08", "TASK-FE-001.49"]
implementation_selected: false
---

# TASK-FE-002.20: Изменить управление записью: пауза, отправка и подтверждённая отмена

## Goal

На iPhone основной кнопкой ставить запись на паузу и возобновлять её; из паузы
явно отправлять WAV либо удалять текущую запись с подтверждением. Уход с экрана
активной или приостановленной записи предлагает отменить её и выйти.

Это новая задача поверх базовой .08. Текущее поручение — добавить требования
в задачи; реализация, проверки приложения и приёмка ещё не выбраны.

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

## Verification

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

## Result

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
