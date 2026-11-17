---
id: "TASK-FE-002.13"
plan: "PLAN-FE-002"
title: "Добавить iOS аудиоплеер и принадлежащий аккаунту cache"
status: "review"
owner: "/root"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.12"]
scope: ["lib/features/results/presentation/audio_player.dart", "lib/features/results/data/original_audio_cache.dart", "lib/features/results/presentation/result_detail_screen.dart", "ios/Runner/AudioSessionBridge.swift", "test/features/results/ios_audio_player_test.dart", "docs/ai/tasks/TASK-FE-002.13.md", "lib/shared/providers/providers.dart", "lib/features/results/data/documents_api.dart", "test/features/results/documents_api_test.dart", "test/features/results/ios_media_smoke_app.dart", "docs/testing/IOS_MEDIA.ru.md"]
planned_paths: ["lib/features/results/presentation/audio_player.dart", "lib/features/results/data/original_audio_cache.dart", "test/features/results/ios_audio_player_test.dart", "test/features/results/ios_media_smoke_app.dart", "docs/testing/IOS_MEDIA.ru.md"]
reuses_tasks: ["TASK-FE-001.30", "TASK-FE-001.44"]
implementation_selected: true
---

# TASK-FE-002.13: Добавить iOS аудиоплеер и принадлежащий аккаунту cache

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Добавить iOS аудиоплеер и принадлежащий аккаунту cache. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.30](../tasks/TASK-FE-001.30.md), [TASK-FE-001.44](../tasks/TASK-FE-001.44.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Реальный original WAV скачивается авторизованным DocumentsApi и поддерживает Play/Pause/seek с фактической длительностью.
- [ ] Cache ограничен объёмом и принадлежит account/audio/job; partial download, hash/length где доступны и network error не воспроизводятся как готовый файл.
- [ ] Audio session координируется с capture; start recording останавливает playback, interruption/наушники/lock/resume не запускают звук неожиданно.
- [ ] Нет обещания фонового плеера/lock screen controls: для первого этапа playback останавливается при уходе в background; активная background запись из .06 сохраняется.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Переиспользовать audioplayers, не вводить новую media dependency автоматически. Сегментный sample/editor будущего этапа не нужен текущему player.

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
| flutter test test/features/results/ios_audio_player_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: звук/seek, Bluetooth route change, playback→record, lock/background и account change | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.


## Verification реализации — 2026-11-17

Cwd `/Users/mxdnght/dictai-app`; Flutter 3.41.3 / Dart 3.11.1,
macOS/Xcode, подготовленные зависимости, без изменения pubspec/lock/signing.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| Первый `flutter test --no-pub test/features/results/ios_audio_player_test.dart test/features/results/documents_api_test.dart` | Ошибка компиляции теста (await void handler); 35 documents cases PASS | FAIL, исправлен | Test-only await удалён, повтор ниже |
| Повтор первых двух suites | 47 PASS; после новых cache race tests один тест ожидал queued failure до завершения fixture | FAIL, исправлен | Это ожидание создавало deadlock теста; порядок ожиданий исправлен |
| `flutter test --no-pub test/features/results/ios_audio_player_test.dart test/features/results/documents_api_test.dart --reporter expanded` | 50 PASS | PASS | `/tmp/dictai-ios-media-host.log`, затем добавлены adverse cases |
| `flutter test --no-pub test/features/results/ios_audio_player_test.dart test/features/results/documents_api_test.dart test/features/record/ios_audio_capture_test.dart test/features/results/ios_result_detail_test.dart --reporter expanded` | 96 PASS, exit0 | PASS | `/tmp/dictai-ios-media-targeted.log`; channel/player fakes и synthetic owned WAV, не hardware |
| Scoped `dart format` (изменённые Dart files) | Отформатированы; итоговая read-only проверка после handoff | PASS | Не меняет прежние out-of-scope files |
| `flutter analyze --no-pub --no-fatal-infos` | Initial visible-for-testing warning/ошибочный smoke getter исправлены; последний exit0, 8 info (7 прежних и затем исправленная test brace) | PASS с последующей delta | `/tmp/dictai-ios-media-analyze.log`; финальный rerun после freeze |
| `git diff --check` | Whitespace diagnostics нет | PASS | Проверка diff, не runtime |
| Реальный Simulator: native capture/timeout smoke | Выполняет coordinator/root отдельными сборками | NOT RUN автором | Фактическое evidence добавит coordinator; host фейки не подменяют Swift |
| Physical iPhone/Bluetooth/interruption/lock/качество звука | Не выполнялось | NOT RUN | Нет подготовленного устройства; полная hardware readiness не заявлена |
| Independent REVIEW-FE-002.13-01 | Назначен media_review | NOT RUN, ожидается | После final source freeze и native evidence |

## Result реализации — 2026-11-17

Реализованы original_audio_cache.dart и audio_player.dart; плеер вставлен в header
существующего result detail без изменения lazy transcript. Общие providers
собирают DocumentsApi/cache/controller/lifecycle. Получение original остаётся
U04 через общий авторизованный Dio, без job query/Range/public token URLs.
Optional maxBytes добавлен DocumentsApi и проверяет quota до записи; default
wire/validation limit сохранён. Квота кеша 256 MiB configurable до 1 GiB,
один completed original, serialized validation/eviction и decoder leases.
Удаление/close failure сохраняет owned references для безопасного повтора;
новый transfer не начинается поверх неочищенного собственного staging.

AudioSessionBridge расширен отдельным playback channel: identity acquire/release,
резервирование capture перед bounded stop/ACK handshake; поздний ACK и stale
release не затрагивают нового владельца. Controller сериализует все уже начатые
plugin commands, проверяет epoch после await, освобождает input после decoder
stop/dispose. После системного/foreground stop звук сам не возобновляется;
background capture сохраняет прежние правила. Final plugin bookkeeping error
после state=disposed отделён от decoder stop failure: released input безопасно
освобождается с видимым предупреждением, полная instance cleanup не заявляется.

Добавлены осмысленные cache/race/error/streamquota tests и explicit native
synthetic target ios_media_smoke_app.dart; методика в IOS_MEDIA.ru.md. Целевой
host набор 96 PASS. Native Simulator проверки ещё координируются root;
physical criteria остаются NOT RUN. Независимый implementation review предстоит.
Другие исходники/legacy/dependencies/signing/backend не менялись; accepted,
commit/push/release этим результатом не назначаются.


## Завершение host/Simulator scope — 2026-11-17

Owner передан coordinator `/root`. Независимый reviewer `/root/media_review_finish`
выявил F01 P2: derived streams audioplayers пересылают decoder errors каждому
listener. Исправлено обработкой ошибок во всех derived subscriptions и единой
обработкой raw eventStream. Regression использует реальные связи streams
закреплённого плагина; один error приводит к одному stop/dispose/release без
необработанного async exception.

Cwd `/Users/mxdnght/dictai-app`; macOS/Xcode26.5, Flutter3.41.3/Dart3.11.1,
Simulator iPhone17Pro/iOS26.5. Dependencies/lock/signing не изменены.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter test --no-pub test/features/results/ios_audio_player_test.dart test/features/results/documents_api_test.dart test/features/record/ios_audio_capture_test.dart test/features/results/ios_result_detail_test.dart --reporter expanded` | 97 PASS после F01; `/tmp/dictai-finish-media-fixed-tests.log` | PASS | Host fakes/synthetic files |
| `flutter build ios --simulator --debug --no-pub --target test/features/results/ios_media_smoke_app.dart --dart-define=DICTAI_IOS_MEDIA_PHASE=capture`; simctl install/privacy grant/launch --console | Xcode5.3s; stop/ACK before capture, valid native WAV after stale release; `DICTAI_IOS_MEDIA PASS capture` | PASS | `/tmp/dictai-finish-media-capture.log`, native simulator mic/synthetic tone; перед Dart-only F01 fix |
| Та же сборка с `DICTAI_IOS_MEDIA_PHASE=timeout`; simctl install/launch | Xcode10.7s; timeout before late ACK; новая capture пережила late ACK, WAV validated; `DICTAI_IOS_MEDIA PASS timeout` | PASS | `/tmp/dictai-finish-media-timeout.log`; перед Dart-only F01 fix; native handshake не менялся |
| `python3 /tmp/dictai_ios_max_build.py 13-finish` | Production main Simulator build PASS7.4s | PASS | До F01; финальная production сборка очереди повторяется после следующих native scopes |
| Physical iPhone/Bluetooth/lock/interruption/VoiceOver и real backend audio | Не выполнялось | NOT RUN | Signing identities=0, device gate .18 сохраняется |

Diff доступен в рабочем дереве, отчёт —
[REVIEW-FE-002.13-01](../reviews/REVIEW-FE-002.13-01.md).
Полные physical criteria и accepted не заявляются. Native Simulator проверки
не подменяют качество воспроизведения/записи и атрибуты защищённых файлов iPhone.

Final `flutter analyze --no-pub --no-fatal-infos`: PASS exit0, семь прежних info,
новых errors/warnings/info нет (`/tmp/dictai-finish-media-analyze.log`). Scoped
`dart format --output=none --set-exit-if-changed` source/test F01: PASS2 files,
0 changed; `git diff --check`: PASS. Production .13 build установлен и запущен
на указанном Simulator (до F01); production target/config восстановлены.


## Final integration перед push — 2026-11-18

Cwd frontend, тот же pinned SDK/macOS/Simulator. Полный
`flutter test --no-pub --reporter expanded`: PASS738/738,33s, log
`/tmp/dictai-finish-stage13-full-tests.log`. Scoped format всех26 изменённых/new
Dart files: PASS0 changed. Markdown266 links/whitespace: PASS. Analyze PASS7
прежних info. `python3 /tmp/dictai_ios_max_build.py 13-final`: PASS8.4s,
`simctl install`/`launch --terminate-running-process`: PASS. Этот final build
включает F01 fix. .DS_Store побайтово сохранён вне предлагаемого commit.
Independent .13-01 reviewed/complete, новых открытых findings нет.
Пользователь поручил commit/push и продолжение доступной очереди; physical
criteria/accepted не меняются.
