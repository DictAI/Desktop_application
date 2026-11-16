---
id: "TASK-FE-002.07"
plan: "PLAN-FE-002"
title: "Импортировать WAV из Files в sandbox приложения"
status: "review"
owner: "primary-agent"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.06"]
scope: ["lib/features/record/data/ios_wav_import.dart", "lib/features/record/presentation/upload_modal.dart", "lib/features/record/data/wav_validator.dart", "test/features/record/ios_wav_import_test.dart", "docs/ai/tasks/TASK-FE-002.07.md"]
planned_paths: ["lib/features/record/data/ios_wav_import.dart", "test/features/record/ios_wav_import_test.dart"]
reuses_tasks: ["TASK-FE-001.18", "TASK-FE-001.23", "TASK-FE-001.31"]
implementation_selected: true
---

# TASK-FE-002.07: Импортировать WAV из Files в sandbox приложения

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

Импортировать WAV из Files в sandbox приложения. Один завершённый этап iOS/iPhone очереди.

## Context

Текущее поручение: пользователь выбрал весь перечисленный iOS объём .04/.05/.06/.07/.08/.10
и разрешил до 10 параллельных агентов. Единственный writer этой карточки и её
текущего exact scope — `primary-agent` после handoff от `/root/ios_files`. Выполняется выбранная реализация
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
Историческое planning поручение 2026-11-16 предшествовало выбранной реализации;
актуальное разрешение и scope описаны выше и в ADR-FE-011.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.18](../tasks/TASK-FE-001.18.md), [TASK-FE-001.23](../tasks/TASK-FE-001.23.md), [TASK-FE-001.31](../tasks/TASK-FE-001.31.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Files picker принимает WAV из локальных Files/iCloud/provider; отмена и provider download/error не создают отправку.
- [ ] Выбранный внешний URL/временный путь копируется в принадлежащий приложению sandbox, security-scoped access ограничен временем операции; произвольный путь не считается постоянным.
- [ ] Валидируются реальные WAV bytes и существующие лимиты, не только расширение; большой файл обрабатывается потоком без полной копии в Dart memory.
- [ ] M4A/MP3 и неподдержанный WAV получают понятную ошибку без фиктивного переименования/ffmpeg; partial copy/disk full очищаются, оригинал пользователя не удаляется.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Использовать существующий file_picker, проверив фактическую iOS семантику пути/copy. Native bridge создавать лишь при необходимости; новые document UTTypes не обещают поддержку новых кодеков.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification текущей реализации — 2026-11-16

Cwd: `/Users/mxdnght/dictai-app`. SDK `/tmp/dictai-flutter-3.41.3/bin/`,
Flutter 3.41.3 / Dart 3.11.1, macOS. Existing package_config и pubspec.lock
соответствуют выбранному SDK; pub get, новые зависимости и native changes
этой частью не выполнялись.

| Command / scenario | Expected | Actual | Status | Limitation |
|---|---|---|---|---|
| `dart format --output=none --set-exit-if-changed lib/features/record/data/ios_wav_import.dart lib/features/record/presentation/upload_modal.dart test/features/record/ios_wav_import_test.dart` | Формат без изменений | 3 files formatted, 0 changed | PASS | Scoped format |
| `dart analyze lib/features/record/data/ios_wav_import.dart lib/features/record/presentation/upload_modal.dart test/features/record/ios_wav_import_test.dart` | Нет diagnostics | No issues found, exit0 | PASS | Только собственный Dart scope; общий analyze делает coordinator |
| `flutter --no-version-check test --no-pub test/features/record/ios_wav_import_test.dart test/features/record/wav_validator_test.dart test/features/record/anonymous_flow_test.dart` | Import/validation/UI и существующая owner-only запись не регрессируют | 70 tests PASS, exit0; из них 17 новых import/widget tests | PASS | Log `/tmp/dictai-ios-files-tests.log`; synthetic files, не реальный iCloud |
| `git diff --check -- lib/features/record/presentation/upload_modal.dart docs/ai/tasks/TASK-FE-002.07.md`; новые source/test целиком, no-index whitespace | Нет whitespace и незапрошенного source diff | Проверено по own scope | PASS | Общая сохранность и shared integration проверяются coordinator |
| iOS source audit pinned `file_picker 8.3.7` | Подтвердить семантику полученного пути | `FilePickerPlugin.m:212–225`: UIDocumentPickerModeImport; `:411–433`: move Inbox copy в app tmp; Dart `withData:false` | Source evidence | Это чтение кода, не runtime test security scope/provider |
| Independent review | Отдельный reviewer проверяет importer/modal/tests/docs | Передано coordinator для .04-02/.06-01 review | NOT RUN | Implementer не заменяет независимый review |
| Simulator native Files picker / iCloud / provider offline / physical iPhone / реальный disk full | Реальное системное взаимодействие и права | Не выполнялось исполнителем | NOT RUN | Native build и Simulator smoke делает coordinator; physical подпись отсутствует. Fake IO/channel tests не подменяют эти проверки |

## Result текущей реализации — 2026-11-16

Добавлен `lib/features/record/data/ios_wav_import.dart`, адаптирован
`lib/features/record/presentation/upload_modal.dart`, добавлен
`test/features/record/ios_wav_import_test.dart`. Existing `WavValidator` использован
без изменения: реальные RIFF bytes, encoding/rate/channels/duration и 1 GiB limit.
Новых native bridges и ручного security-scoped URL access нет: pinned plugin
использует импорт документа, а не долговременный внешний URL. Он передаёт
временную sandbox copy, которой нельзя доверять как постоянному пути.

Importer сериализует pick/copy между владельцами: plugin использует общий
`tmp/<basename>` и может заменять одноимённый файл. После выбора создаётся
отдельная уникальная `dictai-wav-import-*` directory; WAV копируется блоками
64 KiB, проверяется до и после копирования, проверяются source size/modified.
Ни весь WAV, ни содержимое provider не загружаются в Dart memory целиком.
Реальное disk-full/write/read исключение получает безопасную ошибку без пути;
finally закрывает handles и удаляет только собственную partial staging copy.

UploadModal показывает preparing state, собственное имя файла, ошибки и
адаптивный scroll с клавиатурой/text scale. На iOS отсутствует desktop drag hint;
на desktop drag/drop сохранён, но теперь также асинхронно валидирует и копирует.
`UploadLanguageControls` сохранил API; dropdown укладывается на узкой ширине.
Cancel/remove/dispose/auth/session/workspace invalidation очищают только owned
copy и отбрасывают поздний picker/copy. Исходник пользователя и plugin cache не
удаляются; `clearTemporaryFiles()` не вызывается (plugin удаляет весь app tmp).

При Upload владение staging передаётся в async call существующего
`RecordNotifier.uploadFile`. Он делает durable account-owned journal copy до POST;
modal pop не удаляет WAV раньше времени. Staging удаляется после завершения этого
call, независимо от результата; повторное нажатие не создаёт второй upload.
Общий notifier/API/DTO/journal этим scope не менялись. Завершение процесса до
journal prepare может оставить private tmp до очистки ОС; suspend/relaunch recovery
из .09 не заявляется реализованным. При отказе ОС в удалении остаётся только
private temporary staging; чужие пути не используются как cleanup fallback.

Тесты подтверждают unique copies/source preservation; отмену/stale return;
сериализацию picker; MP3/M4A/fake WAV/oversize rejection; safe provider/destination
errors; cleanup при partial stream failure/cancel; реальные channel arguments
`withData:false`, custom WAV, single pick; widths 320/375/430 text2+keyboard;
landscape; ownership через modal pop/upload completion, double tap, session
invalidation и remove/close cleanup. New fixture tests исправлены после первых
итераций FakeAsync/IO ожиданий; финальный набор 70 PASS.

Known integration adjustment: старый `profile_free_flow_test.dart` вызывает
DragTarget callback и сразу `pumpAndSettle`; после async import ему нужен
`tester.runAsync` для real fixture IO. Передано root; вне write scope этой части.

Status implemented: source/targeted checks готовы; обязательные physical provider
criteria и независимый review не объявляются пройденными. Accepted/commit/push/
merge/release не выполнялись. Исторические planning записи ниже сохранены.

## Историческая Verification до реализации

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/record/ios_wav_import_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone Files: локальный/iCloud WAV, cancel, missing provider/offline, большой файл и недостаток места | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result до реализации

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
