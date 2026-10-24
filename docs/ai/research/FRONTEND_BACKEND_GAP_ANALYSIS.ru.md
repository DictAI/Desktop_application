---
title: "Аудит frontend DictAI и сопоставление с целевым backend"
date: "2026-10-24"
status: researched
plan: PLAN-FE-001
frontend_commit: b45c8c4dfe927a872182c7508fa85e01f83a9f0c
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
---

# Frontend DictAI: gap analysis для PLAN-FE-001

## Источники и пределы вывода

Это source-аудит для [PLAN-FE-001](../plans/PLAN-FE-001.md), без реализации.
Проверены текущие Dart clients/DTO/providers/notifiers/routes/screens,
Swift MethodChannel/capture/conversion, entitlements/Info.plist, Linux runner/CMake,
SDK constraints/lock, тесты, launch config с редактированием значений при чтении.

Frontend HEAD: `b45c8c4dfe927a872182c7508fa85e01f83a9f0c`.
Backend snapshot: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`.
Файлы docs/ai до работы уже были untracked; исследованный commit не включает
эти документы. До записи сохранён SHA-256 baseline: frontend 107 файлов,
backend 589 файлов. Аудит не доказывает запуск приложения/сервисов.

Контракты: [BACKEND_API_CONTRACTS](BACKEND_API_CONTRACTS.ru.md),
[BACKEND_TARGET_SCOPE](BACKEND_TARGET_SCOPE.ru.md).
Их 25 реализованных HTTP-операций не равны готовому deployment.
Исходные relative ссылки внутри снимков относятся к backend, правила — в
[architecture](../architecture.md). Новые ссылки этого аудита относятся к frontend.

API ID A/W/U/R ниже взяты из API-снимка. FE suffix .08 означает TASK-FE-001.08;
backend .16 — TASK-002.16. Это разные пространства ID.

## Пользовательский путь и модули

Сейчас: login/register → shell Record/Workspaces/Results. Ordinary запись требует
workspace, UI дополнительно требует contacts/profiles, записывает WAV и после
upload показывает success по audio_id. Anonymous использует отдельный recorder,
собирает M4A/OGG, загружает legacy API, опрашивает session и открывает обязательную
форму speaker names/emails/confirm. Results — список с legacy downloads.

Целевой batch: login → workspace либо owner-only → finalized WAV/preflight →
один V2 upload с durable identity → accepted job → restart-safe polling →
canonical Speaker N → независимый summary/TXT/PDF/original → delete/logout.
Anonymous по-прежнему требует JWT, но не workspace/confirm/profile.
Backend не начинает локальную запись и не выдаёт live stream.

| Область | Текущее поведение и evidence | Цель/изменения | Контракт; backend ID | FE tasks; готовность/блокировки |
|---|---|---|---|---|
| Auth/JWT | [AuthApi](../../../lib/features/auth/data/auth_api.dart) уже читает token, но refresh без {}, change fields password/email; [notifier](../../../lib/features/auth/presentation/auth_notifier.dart) не очищает error через null copyWith; [router](../../../lib/core/router/app_router.dart) проверяет только наличие token | Сохранить register→login, исправить существующие client fields и session/expiry; не добавлять refresh_token/server logout/новый account settings scope | A01–A05; .37 | .04/.08/.09/.34; A/B, gate живого auth .39 |
| Workspace | [WorkspaceDto](../../../lib/features/workspace/data/dto/workspace_dto.dart) уже поддерживает owner_user_id/owner_id; [WorkspaceApi](../../../lib/features/workspace/data/workspace_api.dart) корректно принимает null participants; create/list/delete есть | Сохранить совместимые DTO, fixtures на variants, rename/update в UI, корректные permission errors | W01–W05; .25 | .10–.12; source contract есть, membership semantics требуют .39 |
| Contacts | [ParticipantDto](../../../lib/features/workspace/data/dto/participant_dto.dart) содержит voiceProfileId; notifier умеет edit, UI в основном add/delete | Только name/email/IDs; edit UX, объяснение recipients без ложного доступа к результатам | W06–W09; .25/.30 | .10/.11/.13; B mocks, owner policy .39 |
| Голосовые профили | [detail notifier](../../../lib/features/workspace/presentation/workspace_notifier.dart) load вызывает getVoiceProfiles и способен сломать весь detail; [detail UI](../../../lib/features/workspace/presentation/workspace_detail_screen.dart) library/record/upload/assign; [RecordScreen](../../../lib/features/record/presentation/record_screen.dart) blocks пустой workspace/нет profiles | Удалить coupling, profile fields/UI/API/provider. Пустой workspace owner не обязан заполнять contact/образцы ради записи | U01, W06; .16/.25/.20 | .11/.14/.33; утверждённое removal, не будущая функция |
| Микрофон | [RecordNotifier](../../../lib/features/record/presentation/record_notifier.dart) WAV 16k mono; [AnonRecordNotifier](../../../lib/features/record/presentation/anonymous_record_notifier.dart) opus Linux/aac macOS | Общий injectable capture lifecycle, WAV для обеих форм; pause/stop/dispose/permission и утрата device | U01/U02; .08/.16 | .15/.18/.23/.24; A/B, native smoke отдельно |
| macOS system audio | [Dart wrapper](../../../lib/features/record/data/system_audio_service.dart), [AppDelegate](../../../macos/Runner/AppDelegate.swift), [Swift](../../../macos/Runner/SystemAudioRecorder.swift): AAC temp → целый input buffer → conversion; mix держит два полных buffers и output | Bounded conversion/mix, валидный RIFF output, подключить к anonymous; pause только если синхронен для всех источников, без silent mic fallback | U01/U02; .08/.16 | .16/.23/.24/.36; реальные capture/format/RSS ещё не проверены |
| Linux system audio | Оба notifiers дублируют pactl/parec; kill без wait; ffmpeg failure отдаёт mic-only; [runner](../../../linux/runner/my_application.cc)/[CMake](../../../linux/CMakeLists.txt) — desktop shell | Один adapter, CLI prerequisites, drain/wait/timeout/cleanup, явная ошибка потери источника | U01/U02; .08/.16 | .17/.23/.24/.37; нужен реальный Linux host |
| V2 upload | [AudioIngestApi](../../../lib/features/record/data/audio_ingest_api.dart), [AnonymousSessionApi](../../../lib/features/record/data/anonymous_session_api.dart) используют удалённые paths, без key/job/version; [UploadModal](../../../lib/features/record/presentation/upload_modal.dart) FileType.audio | WAV 1 GiB/2h, ru/en/auto/mixed, multipart/key/accepted DTO; не придумывать MP3 transcoding/413 | U01/U02; .16/.22/.37 | .18–.20/.23/.24; A/B, live upload требует стенд |
| Anonymous | [legacy session DTO](../../../lib/features/record/data/dto/anonymous_session_dto.dart) processing/confirmed + speakers/fragments; [modal](../../../lib/features/record/presentation/label_speakers_modal.dart) собирает name/email и создаёт workspace через confirm | authenticated owner-only/no workspace; session V2 и общий job; no mandatory confirm, terminal failed/cancelled/expired | U02/U03; .16/.25/.30 | .21/.24/.25/.33; B; нет speaker editing/sharing |
| Асинхронность/restart | Timer.periodic async может перекрываться; state RAM-only; ordinary done сразу на audio_id; results polling теряет filter/page | Durable upload journal + accepted jobs, bounded poll/generation, owner namespace, restart без нового upload, 202terminal handling | U01–U03, R01/R03; .13/.15/.16/.22 | .20/.21/.25/.34/.35; B, real recovery .40 |
| Canonical/speakers | Canonical API/DTO/viewer отсутствуют; старый SegmentDto seconds, speakers требуют fragments/identity | v1 required nullable keys, microseconds, word_timing, UNKNOWN/overlap, local labels, no-speech; виртуализированный длинный text | R04, §8; .05/.06/.10/.11/.15 | .22/.28/.29; A/B; quality зависит от .17/.29 backend |
| Transcript/summary | [ResultDto](../../../lib/features/results/data/dto/result_dto.dart) list status; [ResultsScreen](../../../lib/features/results/presentation/results_screen.dart) кнопки по isDone; нет detail route | Раздельные job/transcript/summary/doc availability, canonical ready при summary failed, document404 vs artifact503 | R03–R05; .14/.15 | .21/.22/.25/.28/.29/.31; B; LLM/Typst prerequisites |
| Results/delete | [ResultsApi](../../../lib/features/results/data/results_api.dart) R01/R02 совпадают, pagination теряется; [notifier](../../../lib/features/results/presentation/results_notifier.dart) update сбрасывает filters, delete не координирует journal | Latest V2 owner library, pagination/date filters, known job_id; hide всех versions без обещания physical delete/cancel | R01/R02; .15/.20/.27 | .26–.28/.32/.34; contract есть; legacy results не мигрируются автоматически |
| Export/original | Legacy summary/transcript/audio endpoints; весь файл в List<int>; имя audio.mp3; HOME/Downloads и xdg-open на всех Unix | 4 document kinds + original WAV с JWT, bounded download/atomic save, correct filenames/platform open | R05/U04; .14/.15/.16/.37 | .30/.31/.36/.37; A/B; Range не обещан |
| Errors/security/config | [Dio](../../../lib/core/network/api_client.dart) безусловные body logs; as Map при non-JSON; [storage](../../../lib/core/storage/secure_storage.dart) preferences; [providers](../../../lib/shared/providers/providers.dart) HTTP hardcode; launch содержит значение ключа | Secure store, no secret/log leaks, typed safe errors, config/TLS/timeouts, namespace reset; provider secrets не в binary | §2/§9; .37 | .02–.09/.34/.39; workspace security gate не исправляется клиентской проверкой |
| Тестирование/выпуск | [widget_test](../../../test/widget_test.dart) 0 bytes; [native test](../../../macos/RunnerTests/RunnerTests.swift) template; no integration harness/release evidence | Unit/widget/state/race paths, platform checks, opt-in real backend gate и release acceptance без публикации | Все batch API; .17/.24/.31 | .06/.35–.42; real E2E/release C blocked |
| Неподключённый chat | [ChatPanel](../../../lib/features/record/presentation/chat_panel.dart) и [AnthropicService](../../../lib/features/record/data/anthropic_service.dart) есть, router/RecordScreen их не подключают | Не подключать/не развивать в batch. Token/key storage и secret hygiene покрываются security tasks, отдельный chat product не придумывается | Chat backend API отсутствует | Нет обязательной chat task; физическое удаление dormant code — отдельный выбор |

## Что сохраняется

Сохраняются Material 3/dark theme [app](../../../lib/app.dart),
[цвета](../../../lib/core/theme/app_colors.dart), [тема](../../../lib/core/theme/app_theme.dart),
[main shell/sidebar](../../../lib/core/shell/main_shell.dart), login/register tabs,
workspace grid/detail/контактные поля, record/device/workspace selectors, file-picker
dialog, results cards/loading/empty/error layouts. Они меняют state/data bindings
и подписи там, где старый смысл ложен, но не требуют полного визуального redesign.

Сохраняются Flutter/Riverpod StateNotifier/GoRouter/Dio и ручной DTO mapping.
Нет необходимости вводить codegen, новый общий domain/repository framework,
CI, другой router, state library или backend SDK. Узкие injectable capture,
journal/export/polling services нужны для конкретного lifecycle и тестов,
а не для переписывания всех features.

Уже совместимы token response, register→login, Bearer header для protected paths,
workspace owner field variants/null participants, R01/R02 families и empty-string
workspace в ResultDto. Это нужно зафиксировать regression tests, а не объявлять
всё приложение несовместимым по каждому полю.

## Сквозные зависимости и риски

- Shared providers, router, record_screen, workspace_notifier, results_notifier
  и result_detail_screen имеют последовательных writers. Полные scopes —
  в карточках; даже категории A/B не дают права параллельной записи.
- Удаление voice DTO до consumers сломает build; .11 сначала отвязывает consumers,
  .14 удаляет API/wiring. Аналогично .33 завершает retirement после V2 wiring.
- После logout текущие глобальные providers могут хранить чужой account state;
  .09 делает auth lifecycle, .34 проверяет полностью собранный batch.
- Mac full-file buffers опасны для длинных записей. Tiny test не подтверждает
  bounded RSS или реальную двухчасовую обработку; .16/.36 требуют evidence.
- Linux kill без join может дать незавершённый RIFF. Отсутствующий tool/monitor
  не должен превращаться в бесшумный mic-only «успех».
- Stop/upload/reset пока тесно связаны. Pending source нельзя удалить до
  определённого acceptance; после restart нельзя слепо загрузить снова с новым key.
- UI list done не означает summary ready; наличие transcript projection не
  гарантирует читаемый artifact. Отдельные private NATS/metrics не UI API.
- JWT logout не отзывает ранее выданные токены на backend; существующего server
  logout нет. Local namespace — только клиентская изоляция, не server authorization.

## Состояние среды и секреты

Чтением SDK cache подтверждены Flutter 3.38.1 / Dart 3.10.0; Flutter-команды
при аудите не запускались. Lock требует Dart >=3.11.0, тогда как pubspec допускает
>=3.3.0; toolchain .01 должен выбрать реальную совместимую версию, а не просто
повысить минимальную строку. Linux build на macOS не считается проверкой.

.vscode/launch.json прочитан только с редактированием значений; наличие ключа
подтверждено, действительность не проверялась. В новые документы значения,
пароли/JWT, private URLs и аудио не скопированы. .02 устраняет значение из дерева,
rotation/revoke и history rewrite не выполняются автоматически.

## Backend gates и то, что нельзя обещать

Снимок содержит 36 accepted, 4 draft, 1 review, 2 blocked, 1 cancelled backend tasks.
Accepted .26 — harness/provisional, .39 — limited RU local bundle, а не полный
acceptance dataset. Нужно отдельное backend решение по оставшейся full readiness,
затем baseline/gates .29, CPU E2E .17, staging/cutover .24, production evidence .31.
.18 GPU review и .19 runtime decision не являются gates CPU frontend.
.21 — только будущий live-дизайн, не обещание готового streaming API.
.27 — design cleanup, не выполненная физическая очистка.

Workspace GET detail/access и participant_id/account semantics имеют пробелы;
frontend не может исправить server access control. .39 FE запрашивает решение
владельца/команды без выдуманного backend task ID. Email recipients не получают
автоматического права читать owner-only result.

Не входят в mandatory batch: voice profiles/embeddings/confirm/legacy compatibility;
live/SSE/WebSocket/progress percent/ETA, server cancel/reprocess, grant recovery
без discovery, chat/history, public sharing/invitations/roles, speaker editing,
version-history UI, GPU/provider selector, URL/YouTube ingestion.
Это либо отменённые функции, либо неподтверждённые будущие направления;
никакие route/body для них не выдумываются. Для новых направлений нужен отдельный
выбор scope и API, не просто статус «все backend tasks закрыты».

## Verification и Result аудита

Статическое сопоставление источников и снимков выполнено. Нативная запись,
network API, model quality, Keychain/secret-service и сборки не запускались.
Проверки документации/graph/paths/diff и независимый review фиксируются в
плане и [review record](../reviews/REVIEW-FE-001.01-01.md). Это не приёмка приложения.
