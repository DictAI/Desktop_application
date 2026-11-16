---
id: "TASK-FE-002.06"
plan: "PLAN-FE-002"
title: "Добавить iOS микрофон, background recording и audio interruptions"
status: "review"
owner: "primary-agent"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.05"]
scope: ["lib/features/record/data/ios_audio_capture.dart", "lib/features/record/data/audio_capture.dart", "lib/features/record/presentation/record_notifier.dart", "ios/Runner/AudioSessionBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner/Info.plist", "ios/Runner.xcodeproj/project.pbxproj", "test/features/record/ios_audio_capture_test.dart", "test/features/record/ios_audio_smoke_app.dart", "docs/testing/IOS_AUDIO.ru.md", "docs/ai/tasks/TASK-FE-002.06.md"]
planned_paths: ["lib/features/record/data/ios_audio_capture.dart", "ios/Runner/AudioSessionBridge.swift", "test/features/record/ios_audio_capture_test.dart", "test/features/record/ios_audio_smoke_app.dart", "docs/testing/IOS_AUDIO.ru.md"]
reuses_tasks: ["TASK-FE-001.15", "TASK-FE-001.16", "TASK-FE-001.17", "TASK-FE-001.18", "TASK-FE-001.49"]
implementation_selected: true
---

# TASK-FE-002.06: Добавить iOS микрофон, background recording и audio interruptions

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

Добавить iOS микрофон, background recording и audio interruptions. Один завершённый этап iOS/iPhone очереди.

## Context

Текущее поручение: пользователь выбрал весь перечисленный iOS объём .04/.05/.06/.07/.08/.10
и разрешил до 10 параллельных агентов. Единственный writer этой карточки и её
текущего exact scope — primary-agent (после handoff от остановившихся ios_audio/ios_audio_finish). Выполняется выбранная реализация
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
Историческое поручение 2026-11-16 сначала разрешало только перепланирование;
текущее выбранное исполнение описано выше и в ADR-FE-011.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.15](../tasks/TASK-FE-001.15.md), [TASK-FE-001.16](../tasks/TASK-FE-001.16.md), [TASK-FE-001.17](../tasks/TASK-FE-001.17.md), [TASK-FE-001.18](../tasks/TASK-FE-001.18.md), [TASK-FE-001.49](../tasks/TASK-FE-001.49.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Через существующий AudioCapture создаётся настоящий допустимый PCM WAV; Start/Pause/Resume/Stop идемпотентны, permission denial/revocation и аппаратная ошибка понятны.
- [ ] NSMicrophoneUsageDescription объясняет запись встреч. AVAudioSession category/mode/routes и background audio выбраны для активной микрофонной записи; lock screen/background проверены на iPhone, запись не начинает работать скрытно.
- [ ] Incoming call/Siri/interruption, отключение гарнитуры/Bluetooth route change, media-services reset корректно меняют состояние. Прерванная запись не выглядит активной, автоматический resume разрешён только безопасной политикой.
- [ ] Финализация ограничена по времени/памяти, dispose освобождает session/observer; файл сохранён либо честно помечен неполным, нет обещания восстановления несохранённого WAV после принудительного kill.
- [ ] iOS не вызывает MacosAudioCapture/LinuxAudioCapture, ffmpeg/parec/ScreenCaptureKit; system audio и запись телефонного звонка не предлагаются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Pinned record — первая проверяемая возможность; узкий Swift bridge только для реально отсутствующих lifecycle/session hooks, обе стороны проверять. Background mode относится к активной записи, не даёт бессрочный polling/upload.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification реализации — 2026-11-17

Cwd: `/Users/mxdnght/dictai-app`; Flutter 3.41.3 / Dart 3.11.1,
macOS/Xcode, iPhone 17 Pro Simulator / iOS 26.5. `--no-pub`, исходный lock сохранён.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter --no-version-check test --no-pub test/features/record/ios_audio_capture_test.dart` | 21 tests PASS; `/tmp/dictai-ios-batch-audio-terminal-tests.log` | PASS | Mock channel/events; permission, revision/Start/Pause/Resume races, terminal faults, WAV и cleanup |
| Независимый `flutter --no-version-check test --no-pub test/features/record/ios_audio_capture_test.dart test/features/record/ios_wav_import_test.dart test/features/record/wav_validator_test.dart` | 83 tests PASS; reviewer `/root/ios_audio_review` | PASS | Host tests, не аппаратные notifications |
| `flutter --no-version-check build ios --simulator --debug --no-pub --target test/features/record/ios_audio_smoke_app.dart` и native capture | Build/link PASS; первый запуск FAIL checkpoint=start; после diagnostic два последовательных PASS capture | PASS повторов; исходный FAIL сохранён | `/tmp/dictai-ios-batch-audio-{build,capture,capture-diagnostic,capture-repeat}.log`; причина первого сбоя не установлена |
| Build того же target с `--dart-define=DICTAI_IOS_AUDIO_PHASE=permission_denied`; `simctl install`; `simctl privacy <UDID> revoke microphone com.dictai.app`; `simctl launch --console --terminate-running-process <UDID> com.dictai.app` | Build exit0/13.6s; native=permission_denied; явный `DICTAI_IOS_AUDIO PASS permission_denied`; launch exit0 | PASS | Реальное permission API Simulator; не отзыв разрешения на физическом iPhone |
| `dart format --output=none --set-exit-if-changed <27 changed/new Dart paths>`; `flutter --no-version-check analyze --no-pub --no-fatal-infos` | Format 27/0 changed; analyzer exit0, 7 прежних info вне выбранного scope | PASS | Общий format lib/test выявил 10 прежних файлов вне scope, их формат не менялся |
| `flutter --no-version-check build ios --simulator --debug --no-pub --target lib/main.dart --dart-define-from-file=/tmp/dictai-ios-nav-gateway.json`; install/launch/screenshot | Build exit0/12.3s; установлен обычный main, PID55639; визуально подтверждён Record с нижними вкладками | PASS | `/tmp/dictai-ios-resume-production-build.log`, `/tmp/dictai-ios-resume-production.png`; прежняя public gateway config, без credentials; mic grant восстановлен |
| Физический iPhone: слышимый звук/длинная запись, lock/background, звонок/Siri, Bluetooth/гарнитура, media-services reset, permission revoke, disk-full | Нет подготовленной подписи/устройства | NOT RUN | Обязательные physical criteria остаются открытыми; Simulator не заменяет iPhone |

Полный regression, doc/preservation checks и независимый review фиксируются
в актуальном интеграционном разделе этой карточки и PLAN-FE-002.

## Result реализации — 2026-11-17

Добавлен `IosAudioCapture` и узкий Runner `AudioSessionBridge`; существующий factory
выбирает его на iOS. `AudioCaptureEvents` передаёт native interruption/failure в
RecordNotifier; terminal fault не допускает позднего возврата в recording.
Start/Pause/Resume/Stop сериализованы, identity/revision/generation защищают от
поздних callback и старого dispose, timeout ограничивает ожидание, cleanup повторяем.

AVAudioRecorder пишет PCM16 mono 16kHz WAV; finish проверяет реальные RIFF bytes.
Session `.playAndRecord`/`.default`, Bluetooth/default speaker, explicit mic usage
и background audio настроены для активной записи. Каждый WAV имеет private tmp
directory, protection completeUntilFirstUserAuthentication и backup exclusion.
Interruption/input route change приостанавливают capture; resume только вручную.
Media-services/error переводят его в failure и освобождают session/observers.
Доступный исходник сохраняется, durable copy делает существующий upload journal.

Изменены точные paths из frontmatter: Dart adapter/interface/notifier, Swift
bridge/AppDelegate/project/plist, host/native smoke tests и IOS_AUDIO. Desktop
adapters/API/DTO/dependencies/ATS/signing не менялись; захват чужого звука и звонков
не добавлялся. Native smoke включает настоящий микрофон Simulator и валидирует
непустой WAV, pause/resume/cancel finish/idempotency и передачу session новому owner.

Полная .06 не verified/accepted: physical criteria открыты. Первый native start
сбой остался без установленной причины, два дальнейших capture PASS его не стирают.
Восстановление несохранённого WAV после force kill не обещается. Independent
review: [REVIEW-FE-002.06-01](../reviews/REVIEW-FE-002.06-01.md), общий batch
[REVIEW-FE-002.04-02](../reviews/REVIEW-FE-002.04-02.md); итоговый статус см. ниже.
Методика и ограничения — [IOS_AUDIO](../../testing/IOS_AUDIO.ru.md).

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/record/ios_audio_capture_test.dart; scoped format; flutter analyze; flutter build ios --simulator --debug | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Физический iPhone: реальный звук, screen lock/background, interruption/route changes, отказ mic, длинная запись; Simulator не заменяет этот smoke | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
