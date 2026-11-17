---
id: "TASK-FE-002.09"
plan: "PLAN-FE-002"
title: "Адаптировать upload и восстановление к iOS suspend/resume"
status: "review"
owner: "/root/recovery_prep"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.20"]
scope: ["lib/features/record/presentation/record_notifier.dart", "lib/features/record/data/pending_upload_store.dart", "lib/features/results/data/pending_job_store.dart", "lib/features/results/presentation/processing_notifier.dart", "lib/shared/providers/providers.dart", "lib/core/lifecycle/ios_lifecycle_observer.dart", "test/features/record/ios_upload_recovery_test.dart", "docs/ai/tasks/TASK-FE-002.09.md"]
planned_paths: ["lib/core/lifecycle/ios_lifecycle_observer.dart", "test/features/record/ios_upload_recovery_test.dart"]
reuses_tasks: ["TASK-FE-001.19", "TASK-FE-001.20", "TASK-FE-001.21", "TASK-FE-001.22", "TASK-FE-001.25", "TASK-FE-001.34"]
implementation_selected: true
---

# TASK-FE-002.09: Адаптировать upload и восстановление к iOS suspend/resume

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Уточнение зависимости — 2026-11-17

Перед recovery реализуется [TASK-FE-002.20](TASK-FE-002.20.md): новые pause/send
и подтверждённая отмена локальной записи. Очередь .08 → .20 → .09. Отменённая
ещё до отправки запись не должна попадать в pending journal и восстанавливаться
как upload. Явная отправка из паузы использует существующую durable подготовку.
Текущим поручением выбраны обе реализации; .20 прошла host/Simulator checks
и независимый REVIEW-FE-002.20-02 до передачи scope .09. Прежняя линейная
зависимость .08 заменена.

## Goal

Адаптировать upload и восстановление к iOS suspend/resume. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 первоначально разрешало только перепланирование;
текущая реализация выбрана поручением 2026-11-17, см. раздел выше.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.19](../tasks/TASK-FE-001.19.md), [TASK-FE-001.20](../tasks/TASK-FE-001.20.md), [TASK-FE-001.21](../tasks/TASK-FE-001.21.md), [TASK-FE-001.22](../tasks/TASK-FE-001.22.md), [TASK-FE-001.25](../tasks/TASK-FE-001.25.md), [TASK-FE-001.34](../tasks/TASK-FE-001.34.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Перед отправкой durable journal владеет копией WAV/options/key; временный picker/capture path не единственная сохраняемая ссылка.
- [ ] При suspend/network loss/termination pending upload сохраняется; после resume/relaunch проверяется результат и используется тот же Idempotency-Key, после сохранённого 202 восстанавливается job polling без повторной загрузки.
- [x] UI различает byte upload, queued/running/terminal и unknown outcome; нет обещания фоновой передачи на обычном Dio или постоянно работающего Timer в фоне.
- [x] Polling приостанавливается/возобновляется по iOS lifecycle и текущей сессии без duplicate timers/requests; late completion после logout отбрасывается.
- [ ] Offline retry/backoff ограничен; file protection при lock и закрытый файл дают безопасную ошибку/отложенное восстановление, данные следующего аккаунта не открываются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Нативный background URLSession/новые backend API не добавляются автоматически. Отправка восстанавливается при возвращении приложения; долгий background recording не означает долгий background network.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Реализация и Verification — 2026-11-17

Sole writer `/root/recovery_prep`; baseline перед .09:
`/var/folders/nk/dn15wj451d90zxf_gxkbdgjr0000gn/T/dictai-max-stage-09-1uislbox/`.
Cwd всех команд: `/Users/mxdnght/dictai-app`; macOS arm64,
Flutter 3.41.3 / Dart 3.11.1 (`/tmp/dictai-flutter-3.41.3`), подготовленные
packages, без SDK/dependency/lock обновлений.

Добавлен `IosLifecycleObserver` и nullable `iosLifecycleObserverProvider`:
на iOS resumed разрешает polling, inactive/hidden/paused его приостанавливают.
Один observer не меняет состояние capture и не останавливает background запись.
BatchSession снимает listener при отзыве сессии; повторный resumed не создаёт
повторного восстановления. Принятые receipts восстанавливаются при открытии
сессии/возвращении в foreground; unknown pending остаются доступны для явного
replay прежнего ключа и owned WAV, без автоматического POST.

ProcessingNotifier отменяет HTTP/timers при suspend, сохраняет job state и
отклоняет поздний ответ по generation/token. Journal restore сохраняет актуальную
сессию через suspend/resume race; остановленная/чужая сессия не публикуется.
Terminal/401 не начинают автоматический retry после resume. Error backoff и
remaining deadline сохраняются через suspend, включая ограниченный Retry-After;
явный refresh остаётся доступным. PendingUploadStore различает повреждённые bytes
и временный FileSystemException: protected/unavailable source или metadata
не помечаются необратимо изменёнными/повреждёнными и повторяются после доступа.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter test --no-pub --reporter expanded test/features/record/ios_upload_recovery_test.dart` | Финальный повтор: 10/10 PASS; observer registration/disposal, suspend/token/late response, terminal/401, capped backoff/deadline, restore race, initial suspended session, accepted relaunch без POST, unknown same-key replay, transient storage, POSIX permissions, logout | PASS | Синтетические WAV/fixtures/Dio и host lifecycle; не устройство |
| `/tmp/dictai-flutter-3.41.3/bin/flutter test --no-pub --reporter expanded test/features/record/ios_upload_recovery_test.dart test/features/results/processing_recovery_test.dart test/features/record/pending_upload_store_test.dart test/features/results/ios_results_library_test.dart test/features/results/results_library_test.dart test/features/record/ordinary_flow_test.dart test/features/record/anonymous_flow_test.dart test/features/record/record_discard_test.dart` | 122/122 PASS; .10 foreground/layout/replay и .20 discard сохранены; последующая delta только усилила assertion реального401, targeted10 повторён PASS | PASS | Host unit/widget, не backend/physical suspend |
| `/tmp/dictai-flutter-3.41.3/bin/dart format --output=none --set-exit-if-changed lib/core/lifecycle/ios_lifecycle_observer.dart lib/features/results/presentation/processing_notifier.dart lib/shared/providers/providers.dart lib/features/record/data/pending_upload_store.dart test/features/record/ios_upload_recovery_test.dart` | 5 files, 0 changes | PASS | Только changed/new .09 Dart |
| `/tmp/dictai-flutter-3.41.3/bin/flutter analyze --no-pub --no-fatal-infos` | Exit0, 7 прежних prefer_const info в legacy audio_ingest_api/label_speakers_modal, без errors/warnings | PASS | Legacy info вне .09 не исправлялись |
| Initial author compile/analyze attempts | Await синхронного Binding callback, protected hasListeners assertion и curly-brace diagnostic исправлены; последующие targeted10/analyze PASS | FAIL, исправлен | Не app/runtime failure, предыдущие ошибки не скрыты |
| `git diff --check`; полный .09 source/test diff | Whitespace diagnostics нет; изменение строго в назначенных exact paths | PASS | Новые файлы прочитаны отдельно; общий baseline/scopes проверяет coordinator |
| Simulator production build | Выполняет coordinator после source freeze | NOT RUN исполнителем | Результат root фиксируется отдельно |
| Физический iPhone: airplane mode, lock/protected storage, suspend/kill/relaunch до ответа/после202, server duplicate-job evidence | Не выполнялось: подготовленной подписи/DDI нет | NOT RUN | POSIX permission probe не доказывает iOS file-protection attributes; native policy .16 отдельно |
| Независимый REVIEW-FE-002.09-01 | Проверку проводит `/root/acceptance_review` после source freeze | В работе | Review outcome хранится в назначенном report; не accepted |

## Result реализации — 2026-11-17

Изменены `lib/features/record/data/pending_upload_store.dart`,
`lib/features/results/presentation/processing_notifier.dart`,
`lib/shared/providers/providers.dart` и эта карточка. Созданы
`lib/core/lifecycle/ios_lifecycle_observer.dart` и
`test/features/record/ios_upload_recovery_test.dart`. .20 RecordNotifier/UI,
PendingJobStore, API/DTO, native/signing, dependencies и пользовательские Files
не менялись. Source/tests переданы coordinator и reviewer в frozen состоянии.

Host поведение подтверждено: accepted jobs восстанавливаются без POST; unknown
исход отправляется только явным retry с прежним journal key/bytes/options;
поллинг не продолжается при suspended lifecycle и не публикует ответы старого
аккаунта. .10 библиотека сохраняет фильтры/пагинацию и не повторяет draft без tap.
Нет обещания background Dio, force-kill survival текущей несохранённой записи,
native OS attributes или реального backend E2E. Полные physical criteria
сохраняются открытыми; status review не равен verified/accepted.
Публикация и приёмка .09 не выполнялись.

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/record/ios_upload_recovery_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: airplane mode во время upload, background/kill/relaunch до ответа и после 202; нет duplicate job по журналу и backend evidence | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
