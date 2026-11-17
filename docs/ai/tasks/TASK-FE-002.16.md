---
id: "TASK-FE-002.16"
plan: "PLAN-FE-002"
title: "Завершить удаление, account isolation и cleanup iOS flow"
status: "review"
owner: "/root/cleanup_prep_finish"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.15"]
scope: ["lib/features/results/presentation/results_notifier.dart", "lib/features/results/presentation/result_detail_notifier.dart", "lib/features/results/data/original_audio_cache.dart", "lib/features/record/data/pending_upload_store.dart", "lib/features/results/data/pending_job_store.dart", "lib/shared/providers/providers.dart", "lib/features/record/presentation/anonymous_record_notifier.dart", "lib/features/record/presentation/label_speakers_modal.dart", "lib/features/record/data/audio_ingest_api.dart", "lib/features/record/data/anonymous_session_api.dart", "test/features/results/ios_account_cleanup_test.dart", "docs/ai/tasks/TASK-FE-002.16.md", "lib/core/storage/ios_file_policy.dart", "ios/Runner/StoragePolicyBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_file_policy_test.dart", "ios/RunnerTests/RunnerTests.swift", "lib/features/record/data/dto/anonymous_session_dto.dart", "lib/features/record/data/ios_wav_import.dart", "test/features/record/ios_wav_import_test.dart", "lib/features/record/presentation/record_notifier.dart", "test/features/record/record_discard_test.dart", "lib/features/results/presentation/processing_notifier.dart", "test/features/results/processing_recovery_test.dart", "test/features/results/ios_result_detail_test.dart", "lib/features/results/data/documents_api.dart", "test/features/results/documents_api_test.dart", "ios/Runner/AudioSessionBridge.swift", "lib/features/record/data/ios_audio_capture.dart", "test/features/record/ios_audio_capture_test.dart", "test/features/results/ios_ready_notice_test.dart"]
planned_paths: ["test/features/results/ios_account_cleanup_test.dart", "lib/core/storage/ios_file_policy.dart", "ios/Runner/StoragePolicyBridge.swift", "test/core/storage/ios_file_policy_test.dart"]
reuses_tasks: ["TASK-FE-001.32", "TASK-FE-001.33", "TASK-FE-001.34"]
implementation_selected: true
---

# TASK-FE-002.16: Завершить удаление, account isolation и cleanup iOS flow

## Реализация и границы — 2026-11-18

Продолжение выбранной очереди по прямому поручению пользователя «закончи задачи
предыдущего агента, и запуш их». База реализации `3665fae`; dependency .15 имеет
завершённые host/Simulator checks и независимый review. Owner main cleanup —
`/root/cleanup_prep_finish`; native/storage writer — `/root/filepolicy_prep_finish`.
Exact scope дополнен координатором до записи необходимыми consumers/tests;
source/tests frozen после 262 targeted PASS. Status review, без заявления о
полной physical verification или приёмке. Commit/push выполняет coordinator;
разрешение не распространяется на Store upload или release.

R02 204 и result-not-found 404 синхронно ограждают все версии audio: очищаются
список/detail/notice, отменяются polls/summary/original requests, закрываются
плеер и share sheet. Cache удаляет собственные bytes после освобождения decoder
lease. Подтверждённое R02 также удаляет соответствующие accepted receipts; поздняя
страница/ответ не восстанавливает удалённое. Неудача локального pruning оставляет
удаление действующим и показывает безопасную ошибку cleanup.

Pinned R03 `job_id` 403/404 ограждает только соответствующий ProcessingKey:
несуществующая версия не доказывает отсутствие других jobs того же audio.
Независимый reviewer сверил это с backend `92ad6e4572a3b12a601ba3ab7e5cc385a21694ae`.
Latest R03 без `job_id` используется для audio-wide отсутствия результата.
Отсутствие canonical artifact и TTL анонимной U03 сессии не превращаются в
удаление записи. Сохраняются безопасный unavailable progress и независимость summary.

Logout/401/account change сначала отзывают session generation и UI, затем после
native stop/dispose и завершения durable copy удаляются только точные owned пути
неотправленного WAV. Поздний matching native response может сохранить путь только
для cleanup; он не возвращает status и не принимает путь чужого recorder ID.
Error release также сохраняет ownership до logout/dispose. Внешний Files source
и пользовательские exports не удаляются.

Политика хранения: pending/unknown outcome остаются в owner-specific durable
journal с исходным idempotency key для явного same-owner replay; автоматического
POST при login/restart нет. После logout другой аккаунт получает отдельный store
и не может прочитать/отправить чужой local ID. Лимиты journal — 64 entries/2 GiB
source на owner, исходный WAV — до 1 GiB; cache — один original до 256 MiB;
TXT/PDF download — локальный бюджет 64 MiB на файл. Эти значения являются
клиентскими ограничениями хранения, не новым backend wire contract.

IosFilePolicy применяется до записи и проверяет готовые owned files после записи.
Native bridge preflight отклоняет symlinks/hardlinks/outside paths; backup exclusion
проверяется resource attributes, protection — actual file attributes. Shared
`dictai-pending-v1` root защищается metadata-only; рекурсивный обход затрагивает
только selected owner и выполняется под тем же journal lock, что rename/cleanup.
Так повреждённый journal A не блокирует B и owner writes не гоняются с обходом.

На физическом iPhone обязательны readback `.completeUntilFirstUserAuthentication`
и backup exclusion; отказ или отсутствие bridge прекращает запись/копирование.
Xcode26.5/iOS26.5 Simulator фактически не возвращает `.protectionKey` ни для
файлов, ни для каталогов после setAttributes. Только compile-time Simulator
ветка явно возвращает `protection: unsupportedInSimulator`,
`protectionVerified: false`, `environment: simulator`; backup exclusion всё равно
проверяется. На устройстве такого fallback нет. Simulator PASS ниже не доказывает
Data Protection, first-unlock/lock/background поведение физического iPhone.

После проверки всех production/test imports удалён неиспользуемый legacy cluster:
anonymous_record_notifier, label_speakers_modal, audio_ingest_api,
anonymous_session_api и anonymous_session_dto; удалены их providers. Текущий V2
owner-only режим сохранён. Desktop platform adapters, зависимости, SDK/lock,
разрешения и HTTP contracts не менялись.

## Verification реализации — 2026-11-18

Cwd всех команд `/Users/mxdnght/dictai-app`; macOS26.5.2 arm64, Xcode26.5/17F42,
Flutter3.41.3 (`48c32af034`)/Dart3.11.1 из `/tmp/dictai-flutter-3.41.3`, prepared
packages; pub get, SDK и lock updates не выполнялись.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded test/features/record/pending_upload_store_test.dart test/features/record/ios_wav_import_test.dart test/features/record/record_discard_test.dart test/features/record/ios_audio_capture_test.dart test/features/results/processing_recovery_test.dart test/features/results/results_library_test.dart test/features/results/ios_result_detail_test.dart test/features/results/ios_audio_player_test.dart test/features/results/ios_document_export_test.dart test/features/results/documents_api_test.dart test/features/results/ios_account_cleanup_test.dart test/features/results/ios_ready_notice_test.dart test/core/storage/ios_file_policy_test.dart` | 262/262 PASS, exit0, 4s; `/tmp/dictai-cleanup-final-targeted2.log` | PASS | Host fake HTTP/native channel/Keychain; synthetic WAV/canonical |
| `/tmp/dictai-flutter-3.41.3/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/record/data/ios_audio_capture.dart lib/features/record/data/ios_wav_import.dart lib/features/record/data/pending_upload_store.dart lib/features/record/presentation/record_notifier.dart lib/features/results/data/documents_api.dart lib/features/results/data/original_audio_cache.dart lib/features/results/data/pending_job_store.dart lib/features/results/presentation/processing_notifier.dart lib/features/results/presentation/result_detail_notifier.dart lib/features/results/presentation/results_notifier.dart lib/shared/providers/providers.dart test/features/record/ios_audio_capture_test.dart test/features/record/ios_wav_import_test.dart test/features/record/record_discard_test.dart test/features/results/documents_api_test.dart test/features/results/ios_account_cleanup_test.dart test/features/results/ios_ready_notice_test.dart test/features/results/ios_result_detail_test.dart test/features/results/processing_recovery_test.dart` | 19 files/0 changed, exit0 | PASS | Native writer отдельно проверил 2 policy Dart paths |
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check analyze --no-pub` | No issues, exit0, 1.8s | PASS | 7 прежних info исчезли вместе с удалёнными legacy files |
| `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination id=EFF90604-B7F5-4B2B-9A95-7AC2B9E257B6 -parallel-testing-enabled NO -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO` | Native writer: 9/9 PASS, 27.8s; `/tmp/dictai-filepolicy-xctest-review-f02-20261118.log` | PASS | Actual backup attrs/ownership/links/broken other-owner fixture; protection readback unsupported в Simulator, не physical PASS |
| Simulator capture media smoke, target `test/features/results/ios_media_smoke_app.dart` | Coordinator build27.4s/install/launch PASS; `CHECK stopped_and_acknowledged_before_capture`, `CHECK valid_capture_after_stale_release`, `PASS capture` | PASS | iPhone17Pro/iOS26.5 Simulator; `/tmp/dictai-finish-20261118-capture-smoke.log`; physical mic/lock не проверены |
| Simulator export phase с `--dart-define=DICTAI_IOS_MEDIA_PHASE=export` | Coordinator explicit build8.0s, TXT/PDF/WAV sheet/cancel и early cancel CHECK, `PASS export` | PASS | `/tmp/dictai-finish-20261118-export-smoke-final.log`; запуск с SIMCTL_CHILD сначала повторил capture и не засчитывается как export |
| `git diff --check`; `rg -n -e anonymous_record_notifier -e label_speakers_modal -e audio_ingest_api -e anonymous_session_api -e anonymous_session_dto -e audioIngestApiProvider -e anonymousSessionApiProvider -e AnonRecordNotifier -e LabelSpeakersModal lib test` | Whitespace clean; references не найдены (rg exit1 ожидаем) | PASS | Полный tracked/untracked diff отдельно проверяет coordinator/reviewer |
| Первичные targeted/fixture runs | Intended old expectations для pinned404 UI/notice и новые auth/anonymous receipt fixture исправлены; финальный 262 PASS | FAIL, исправлен | Логи `/tmp/dictai-cleanup-targeted.log`, `-targeted2.log`, `-newtests.log`, `-final-targeted.log`; FAIL не выдаётся за PASS |
| Первичные native passes/diagnostic | Строгий protection readback дал FAIL 89.0s/46.4s/42.7s; diagnostic подтвердил отсутствие Simulator attribute; затем capability handling и F02 fix | FAIL, ограничение установлено | История native8 PASS30.2s заменена final9 PASS27.8s; Data Protection физически NOT RUN |
| `python3 /tmp/dictai_ios_max_build.py 16-final`; `xcrun simctl install/launch` | Coordinator: production main Simulator build PASS7.2s/install/launch PASS exit0; `/tmp/dictai-task-fe-002.16-final-build.log` | PASS | Main target/config восстановлены; iPhone17Pro/iOS26.5 Simulator, не hardware |
| `python3 /tmp/dictai-finish-20261118-device-build.py` (`flutter build ios --debug --no-codesign --no-pub --target lib/main.dart`, прежний approved origin) | Coordinator: unsigned device compile PASS26.0s exit0; `/tmp/dictai-finish-20261118-unsigned-device-build.log` | PASS | Строгая device-only native ветка компилируется; подписи, установки и запуска на iPhone нет |
| Физический iPhone: delete при playback/poll/download, logout при recording/upload, A→B/relaunch/first unlock/lock/backup attributes | Не выполнялось | NOT RUN | Нужны signing/device и .18 evidence; Simulator не заменяет hardware |
| Независимый implementation review `REVIEW-FE-002.16-01` | `/root/cleanup_review_finish`: 168 focused tests/format21 PASS по evidence coordinator; F01–F04 исправлены в выбранном scope, финальный verdict reviewed/complete, открытых actionable findings нет | PASS | Independent source review не self-review; final organizational report завершает reviewer, не приёмка |

## Result реализации — 2026-11-18

Независимый [REVIEW-FE-002.16-01](../reviews/REVIEW-FE-002.16-01.md) завершён: reviewed/complete, F01–F04 fixed with evidence; independent168 tests и format21 PASS. Host/Simulator gate пройден, physical критерии остаются NOT RUN.

Изменены main source consumers: `results_notifier.dart`, `result_detail_notifier.dart`,
`processing_notifier.dart`, `pending_job_store.dart`, `original_audio_cache.dart`,
`documents_api.dart`, `pending_upload_store.dart`, `ios_wav_import.dart`,
`ios_audio_capture.dart`, `record_notifier.dart`, shared providers и эта карточка.
Новые main tests — `test/features/results/ios_account_cleanup_test.dart` (9 scenarios);
дополнены 7 существующих test files из exact scope. Удалены 5 legacy files выше.
Native writer добавил `lib/core/storage/ios_file_policy.dart`,
`ios/Runner/StoragePolicyBridge.swift`, `test/core/storage/ios_file_policy_test.dart`;
изменил AppDelegate registration, PBX source membership, AudioSessionBridge readback
и RunnerTests (9 содержательных XCTest вместо пустого testExample).

Подтверждён host gate deletion/session/owned cleanup и native Simulator backup /
containment gate. Начальные review findings исправлены: F01 audio-wide R02 отменяет
все версии, F02 root/owner traversal изолирован и сериализован, F03 error release
не теряет owned path, F04 pinned404 не закрывает живые sibling jobs. Регрессии
проверяют реальный journal filesystem, held HTTP replies, leases, системный share
через injectable channel/sheet, same-owner recovery и отсутствие чужого POST.

Остаточные ограничения: отказы native stop/file deletion сохраняют точный owned
путь для повторного cleanup, не разрешают удалять внешние файлы или обходить
native release. OS-denied cleanup нельзя объявить выполненным; process death
оставляет временные app-owned staging под управлением sandbox/OS и повторного
жизненного цикла. Durable pending остаётся на диске для recovery с квотой owner.
Невыполненные physical criteria остаются открыты; `accepted` не присваивается.

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Завершить удаление, account isolation и cleanup iOS flow. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.32](../tasks/TASK-FE-001.32.md), [TASK-FE-001.33](../tasks/TASK-FE-001.33.md), [TASK-FE-001.34](../tasks/TASK-FE-001.34.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] R02 delete инвалидирует список/detail/polls/player/cache/notice; tombstone/404 не возвращает старый результат через late response.
- [ ] Logout/401/account A→B освобождают capture/audio session, requests/listeners/timers и UI; B не видит файлы/labels/jobs A.
- [ ] Удаляются только принадлежащие приложению копии с явной политикой pending recovery и disk quota/backup exclusion/file protection; пользовательские Files originals/exports сохранены. Нативная file policy проверяет реальные resource/protection attributes, а не наличие Dart-флага.
- [ ] Legacy anonymous/voice/confirm consumers удалены после проверки импортов/тестов; desktop platform files не удаляются попутно и новые architecture layers не создаются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Для file protection/backup exclusion добавить узкий StoragePolicyBridge с Dart-обёрткой и включением Swift в Runner; проверить реальные iOS attributes и поведение при блокировке, без новых packages. Перед удалением legacy расширить exact scope лишь для найденных потребителей внутри выбранного retirement; при внешнем scope сообщить finding, не удалять код вслепую. Старые desktop hardware adapters не становятся iOS runtime.

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
| flutter test test/features/results/ios_account_cleanup_test.dart test/core/storage/ios_file_policy_test.dart; scoped format; flutter analyze; поиск всех импортов удаляемых файлов | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: delete во время playback/poll/download, logout во время recording/upload, A→B, relaunch и lock | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
