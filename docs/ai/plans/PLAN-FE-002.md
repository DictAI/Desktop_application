---
id: "PLAN-FE-002"
title: "DictAI для iOS/iPhone на существующем Flutter и batch API"
status: "ready"
owner: "primary-agent"
selected_tasks: []
planning_authorized: true
implementation_authorized: false
frontend_commit: "44ace4d"
requirements_revision: "ios-2026-11-16"
---

# PLAN-FE-002: DictAI для iOS/iPhone

## Goal

Работающее приложение для iPhone: вход → рабочее пространство либо запись без
workspace → микрофон или WAV из Files → V2 upload → готовый транскрипт →
прослушивание и экспорт → безопасные удаление/выход. Flutter/Riverpod/GoRouter/Dio
и существующие API сохраняются; Swift используется для узких iOS-возможностей.
Целевой сценарий включает запись с заблокированным экраном и обработку audio
interruptions, восстановление загрузки после suspend и использование iOS Files.

Поручение пользователя 2026-11-16: переписать/добавить задачи под iOS. Сейчас
разрешены только планирование и изменение flow. Реализация карточек не выбрана;
планирование не разрешает её автоматически. Review выполняется агентами внутри
процесса; пользователь видит конечный результат и существенные ограничения.

## Current state

Проверенный checkout `44ace4d`, исходный git status чистый. `ios/` отсутствует,
`.metadata` перечисляет root/macOS, есть macOS/Linux исходники. В pubspec Flutter
>=3.41.3 / Dart >=3.11.0, record ^5.1.2 (lock: 5.2.1, record_darwin 1.2.2), audioplayers, file_picker, path_provider,
flutter_secure_storage; совместимость конкретного iOS target ещё не доказана.

- MainShell: Row/sidebar 220; RecordScreen: фиксированные 360; UploadModal: 480.
- RecordNotifier capture factory выбирает macOS/Linux; MicrophoneCapture отказывает
  вне macOS. Наличие record plugin не делает текущую запись совместимой с iOS.
- Готовы компоненты auth, secure storage без plaintext fallback, workspace/contact,
  V2 upload/options/WAV preflight, durable upload/job journals, polling, canonical/
  documents/results API, library. Detail route/viewer/player ещё не завершены.
- Backend/API snapshots в docs/ai/research — исторические источники с внешними
  путями; актуальный backend/стенд/качество не подтверждены этим планированием.
  Контракт и реальную интеграцию проверяем read-only, backend не изменяем.

Это source-аудит, не runtime test. Ранее записанные 552 Flutter tests и macOS
smoke относятся к прежнему diff: iOS build, запись, Files и Keychain NOT RUN.
Подробности: [architecture](../architecture.md), [iOS UX](../research/IOS_TARGET_UX.ru.md),
[ADR-FE-009/010](../decisions.md), [WORKFLOW](../WORKFLOW.md).

## Task graph

Первый порт выполняется по одной задаче за раз, чтобы shared router/providers,
Runner/Info.plist, capture/notifier и result detail имели одного writer. Поэтому
очередь .01 → .02 → … → .19 содержит и функциональные, и интеграционные зависимости.
Граф не означает выбор реализации. Переход внутри выбранной очереди требует
checks и внутреннего независимого review без блокирующих findings; accepted
остаётся явной приёмкой пользователя, без промежуточных запросов review.

```text
.01 baseline → .02 Runner → .03 Keychain/HTTPS → .04 navigation → .05 workspaces
→ .06 iOS audio → .07 Files import → .08 Record → .09 lifecycle/upload recovery
→ .10 Results → .11 detail → .12 transcript → .13 player → .14 export
→ .15 ready notice → .16 cleanup → .17 regression → .18 iPhone E2E → .19 candidate
```

## Tasks

Owner unassigned относится к будущей реализации; planner/coordinator всех
документов — primary-agent. До старта выбранной задачи назначается один writer.

| ID | Title | Status | Dependencies | Owner | Write scope |
|---|---|---|---|---|---|
| [TASK-FE-002.01](../tasks/TASK-FE-002.01.md) | Зафиксировать iOS toolchain, deployment target и manifest Runner | ready | none | unassigned | Exact paths в карточке |
| [TASK-FE-002.02](../tasks/TASK-FE-002.02.md) | Добавить iOS Runner и воспроизводимую simulator-сборку | draft | TASK-FE-002.01 | unassigned | Exact paths в карточке |
| [TASK-FE-002.03](../tasks/TASK-FE-002.03.md) | Подтвердить iOS Keychain, авторизацию и HTTPS | draft | TASK-FE-002.02 | unassigned | Exact paths в карточке |
| [TASK-FE-002.04](../tasks/TASK-FE-002.04.md) | Сделать мобильную навигацию и экран входа | draft | TASK-FE-002.03 | unassigned | Exact paths в карточке |
| [TASK-FE-002.05](../tasks/TASK-FE-002.05.md) | Адаптировать workspaces и контакты для iPhone | draft | TASK-FE-002.04 | unassigned | Exact paths в карточке |
| [TASK-FE-002.06](../tasks/TASK-FE-002.06.md) | Добавить iOS микрофон, background recording и audio interruptions | draft | TASK-FE-002.05 | unassigned | Exact paths в карточке |
| [TASK-FE-002.07](../tasks/TASK-FE-002.07.md) | Импортировать WAV из Files в sandbox приложения | draft | TASK-FE-002.06 | unassigned | Exact paths в карточке |
| [TASK-FE-002.08](../tasks/TASK-FE-002.08.md) | Собрать мобильный экран записи и безопасный Stop/уход | draft | TASK-FE-002.07 | unassigned | Exact paths в карточке |
| [TASK-FE-002.09](../tasks/TASK-FE-002.09.md) | Адаптировать upload и восстановление к iOS suspend/resume | draft | TASK-FE-002.08 | unassigned | Exact paths в карточке |
| [TASK-FE-002.10](../tasks/TASK-FE-002.10.md) | Адаптировать библиотеку результатов и восстановление отправок | draft | TASK-FE-002.09 | unassigned | Exact paths в карточке |
| [TASK-FE-002.11](../tasks/TASK-FE-002.11.md) | Добавить единый мобильный экран результата | draft | TASK-FE-002.10 | unassigned | Exact paths в карточке |
| [TASK-FE-002.12](../tasks/TASK-FE-002.12.md) | Показать большой транскрипт с говорящими и таймкодами | draft | TASK-FE-002.11 | unassigned | Exact paths в карточке |
| [TASK-FE-002.13](../tasks/TASK-FE-002.13.md) | Добавить iOS аудиоплеер и принадлежащий аккаунту cache | draft | TASK-FE-002.12 | unassigned | Exact paths в карточке |
| [TASK-FE-002.14](../tasks/TASK-FE-002.14.md) | Экспортировать документы и WAV через iOS Files/share sheet | draft | TASK-FE-002.13 | unassigned | Exact paths в карточке |
| [TASK-FE-002.15](../tasks/TASK-FE-002.15.md) | Связать готовность результата с lifecycle и уведомлением внутри приложения | draft | TASK-FE-002.14 | unassigned | Exact paths в карточке |
| [TASK-FE-002.16](../tasks/TASK-FE-002.16.md) | Завершить удаление, account isolation и cleanup iOS flow | draft | TASK-FE-002.15 | unassigned | Exact paths в карточке |
| [TASK-FE-002.17](../tasks/TASK-FE-002.17.md) | Закрепить iOS batch-сценарий регрессионными проверками | draft | TASK-FE-002.16 | unassigned | Exact paths в карточке |
| [TASK-FE-002.18](../tasks/TASK-FE-002.18.md) | Подтвердить реальный iPhone E2E и platform readiness | draft | TASK-FE-002.17 | unassigned | Exact paths в карточке |
| [TASK-FE-002.19](../tasks/TASK-FE-002.19.md) | Подготовить iOS candidate и требования TestFlight/App Store | draft | TASK-FE-002.18 | unassigned | Exact paths в карточке |

## Перенос PLAN-FE-001

Старые ID, статусы, evidence и готовый код сохранены. Все 51 карточка помечены
historical_not_selected и ссылаются на этот план; selected_tasks старого плана
очищен, сам план blocked для исполнения. Перенос не означает отмену/приёмку
старого результата или разрешение повторно реализовать уже готовые компоненты.

| Прежние задачи | Решение для iOS |
|---|---|
| .01–.10 | Reuse toolchain/auth/network/storage/contracts; iOS перепроверка .01–.04 |
| .11–.14 | Reuse profile-free workspace/contact CRUD; мобильная адаптация .05 |
| .15/.16 | Reuse AudioCapture/lifecycle опыт; новый iOS adapter .06, desktop код сохраняется |
| .17/.37 | Linux capture/build отложены, не входят в iOS gate |
| .18–.25 | Reuse WAV/upload/DTO/journals/polling, iOS Files/Record/lifecycle в .06–.09 |
| .26/.27 | Reuse Results data/list; iPhone library .10 |
| .28/.29/.44 | Незавершённые detail/transcript/player перенесены в .11–.13 |
| .30/.31 | Reuse DocumentsApi, iOS export .14 |
| .32–.35 | Delete/legacy cleanup/account isolation/regression перенесены в .16/.17 |
| .36/.38–.42 | macOS/Linux release gate заменён iOS baseline/device/backend/candidate .01/.18/.19 |
| .48/.49 | Reuse Stop/guard; iOS gestures/lifecycle/ready notice .08/.15 |
| .43/.45/.46/.47/.50/.51 | Будущие speaker names/contact assignment/named export по-прежнему ждут backend и отдельного выбора |

Это перенос существующей frontend интеграции на iOS, не разрешение создавать
новые backend endpoints/tasks. Immutable BACKEND_* snapshots не редактируются.

## Verification strategy

Для текущего planning diff: frontmatter/ID, dependency DAG/status table,
exact paths/planned_paths, ссылки, сохранность исходников/старых task статусов,
полный tracked/untracked diff и внутренний независимый planning-review.
Flutter/analyze/build/audio/backend E2E сейчас NOT RUN: функциональный код не меняется.

При реализации: format/analyze/targeted tests для каждого Dart scope, затем
общий regression; simulator build для Runner; физический iPhone для Keychain,
микрофона, background/lock/interruption/route changes, Files/export, suspend и
account isolation. Реальный HTTPS backend нужен для .18, модельное качество и
workspace security не выводятся из успешного UI/fixtures. Archive/signing/Store
validation проверяются отдельно, без автоматической публикации.

## Risks and decisions

- iPhone — основной target. Минимальная iOS версия выбирается в .01 по pinned
  dependencies. iPad — адаптивная работоспособность и безопасный share popover,
  отдельный iPad UX не обязателен первому этапу. Android не входит в эту очередь.
- iOS mic + WAV Files import; захват звука звонков/других приложений, ScreenCaptureKit,
  ReplayKit/broadcast extension не входят. Запись на фоне проверяется на iPhone.
- AVAudioSession/permission, file protection и lock/interruptions — реальные gates.
  Продолжение записи при force quit и бессрочная фоновая загрузка не обещаются.
- Upload восстанавливается по journal/key при возвращении приложения; не вводим
  background URLSession/push/APNs без отдельного решения. Ready notice — in-app.
- Public HTTPS endpoint, физический iPhone, signing/team и backend/operator могут
  быть недоступны: записать blocker и продолжать только независимый выбранный scope.
- App Store account deletion/privacy policy/review access проверяются в .19.
  Неподдержанное удаление аккаунта — release blocker, не повод придумывать endpoint.
- Нет MP3/M4A transcoding, speaker renaming/editor/live/chat или production fake data.
  Новые packages, permissions и signing changes разрешаются только в выбранном
  exact scope с обоснованием; текущий planning diff их не вносит.

## Completion

Приложение готово после выполнения выбранных .01–.19 с реальными gates и
внутренним независимым review; приёмка остаётся за пользователем. Готовый план
не означает готовое приложение и не разрешает commit/push/release. Текущее поручение меняет документы; переход к реализации требует
выбора новых задач пользователем.

## Verification / Result текущего перепланирования

2026-11-16: подготовлены 19 новых карточек, активный iOS-план, UX, перенос 51
исторической карточки и правила внутреннего review в AGENTS/WORKFLOW/README.
Implementation, platform config, зависимости и исторические reviews не меняются.
Doc checks и [независимый review](../reviews/REVIEW-FE-002.01-01.md) завершены.
Reviewer `/root/ios_planning_review` подтвердил исправление F01–F03 P2/F04 P3;
открытых actionable findings нет. Status ready — подготовленный план к выбору,
не реализованность новых задач и не accepted.

Проверки документации выполнены из `/Users/mxdnght/dictai-app`, локальное
окружение Python 3 / Ruby Psych 3.1.0. Checker и baseline расположены в `/tmp`,
не входят в продуктовый diff.

| Command / scenario | Cwd / environment | Actual | Status | Limitation |
|---|---|---|---|---|
| `python3 /tmp/check_dictai_ios_plan.py` | frontend / Python 3, Ruby Psych 3.1.0 | 19 новых задач; YAML, ID/table, DAG, exact/planned paths, новые ссылки и ordered shared scopes проверены; 51 прежний task status и всё историческое содержимое сохранены; 197 protected file hashes без изменений | PASS | Локальный doc checker; не тест приложения |
| `git diff --check` | frontend / Git | Whitespace ошибок нет | PASS | Новые файлы дополнительно проверены checker/no-index diff |
| Полный tracked diff и `git diff --no-index /dev/null <new-doc>` | frontend / Git | Проверены doc-only изменения и новые документы; код/dependencies/platforms/старые reviews/BACKEND_* сохранены | PASS | no-index exit 1 означает найденный diff |
| Flutter analyze/test/build; device/backend smoke | Не выполнялось | Изменены только документы | NOT RUN | Не относится к scope; готовность iOS не утверждается |
| Независимый planning-review и delta | Агент ios_planning_review, только назначенный report | REVIEW-FE-002.01-01 reviewed; F01–F04 fixed with evidence, открытых findings нет | PASS | Только planning diff, отдельно от runtime checks |
