---
title: "DictAI: целевая функциональность для планирования frontend"
date: "2026-10-24"
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
status: researched
scope: frontend-target-planning
api_contracts: FRONTEND_API_CONTRACTS.ru.md
---

# DictAI: целевой scope frontend

## 1. Назначение и границы документа

Документ предназначен для планирования отдельного Flutter/Dart frontend с учётом
реализованного backend и актуального направления его развития. Он дополняет
[FRONTEND_API_CONTRACTS.ru.md](FRONTEND_API_CONTRACTS.ru.md): тот документ описывает
фактический HTTP wire contract, этот — пользовательские сценарии, готовность,
зависимости и границы будущих frontend-работ.

Исследован backend `/Users/verliiar/phiziks_pr`, Git commit
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, дата среза — 2026-10-24.
SHA относится к backend; этот документ и существующий API-отчёт на момент
исследования не входят в указанный commit. Отдельный frontend snapshot здесь
не фиксируется. Рекомендации по frontend не являются отчётом о выполненных
изменениях Flutter-кода.

Это исследование, а не новая продуктовая спецификация, план реализации или
разрешение выполнять задачи. Новые task ID не создаются, существующие статусы
не изменяются. Предложения и открытые вопросы не становятся обязательными
требованиями без отдельного решения владельца.

Приоритет источников:

1. Для действующего API — зарегистрированные routes, handlers, DTO, persistence,
   тесты и startup/configuration.
2. Для целевого поведения — последние решения владельца, scope и Result
   конкретных task-карточек; зависимости — их YAML `depends_on`.
3. Планы и active-plan дают контекст. Их исторические абзацы могут содержать
   устаревшие статусы и пути удалённого runtime.
4. OpenAPI — дополнительный источник: часть его операций и DTO расходится с кодом.

Основания: [AGENTS.md](../../../AGENTS.md), [active-plan](../active-plan.md),
[PLAN-002](../plans/PLAN-002-speech-pipeline-rework.md),
[решения](../decisions.md), [архитектура](../architecture.md),
[клиентский flow](../../api-client-flow.ru.md).

Обозначения в таблицах: `.16` означает `TASK-002.16`; это ссылки на существующие
backend-задачи, а не предлагаемые frontend task ID. «Контракт есть» означает
подтверждённую кодом форму API. Приёмка backend-задачи не означает отдельного
frontend contract freeze, приёмки frontend или доступности production.

## 2. Целевой пользовательский сценарий batch-продукта

1. Пользователь регистрируется/входит и получает JWT через gateway.
2. Выбирает режим: запись в workspace либо запись только для владельца без workspace.
   Workspace и его контакты существуют независимо от распознанных speakers.
3. Frontend завершает локальную запись в допустимый WAV или выбирает готовый
   совместимый файл. Backend не управляет захватом микрофона/системного звука.
4. Frontend отправляет multipart upload с JWT и `Idempotency-Key`; для workspace
   передаёт `workspace_id`, для anonymous — исключает его. Можно задать язык
   `ru`/`en`, auto или mixed по действующим правилам формы.
5. Backend принимает durable job и возвращает HTTP 202, `audio_id`, `job_id`,
   `processing_version`, `status_url`, nullable `session_id`. Frontend сохраняет
   идентификаторы и различает окончание передачи файла и окончание обработки.
6. Backend выполняет подготовку, ASR, global diarization, timeline fusion и
   сохраняет canonical transcript. Speaker IDs локальны одной записи;
   display labels — `Speaker 1…N`, неизвестный speaker — `UNKNOWN`.
7. Frontend опрашивает status и получает canonical JSON после готовности.
   Текст доступен независимо от успешности summary. `no_speech` — успешный
   пустой результат, а не общая ошибка обработки.
8. Отдельно появляются полный transcript TXT/PDF и summary TXT/PDF.
   Пользователь может скачать original WAV. Ошибка summary/PDF не должна
   скрывать уже доступный canonical transcript или готовый TXT.
9. Backend отправляет уведомления: для workspace — owner и контакты участников,
   для anonymous — owner. Email-получатель не получает автоматически права
   чтения owner-only результата.
10. Пользователь видит свои последние V2 результаты, может скачать доступные
    документы и удалить результат по текущей семантике tombstone.

`anonymous` означает отсутствие workspace, а не отсутствие авторизации или
публичный доступ. В этом сценарии нет обязательного именования speakers,
confirm, создания участников по голосам или voice profiles.

Основания: решения ADR-005–009 в [decisions](../decisions.md),
[требования ordinary/anonymous](PLAN-002-requirements.md),
[upload/notifications](PLAN-002-upload-notifications-api.md),
[реальные ingest routes](../../../services/audio-ingest-service/internal/presentation/router.go),
[canonical result routes](../../../services/results-service/internal/presentation/router.go).

## 3. Согласованная функциональность и влияние на frontend

Перечень account/workspace операций фиксирует существующую возможность backend.
Он сам по себе не обязывает включать каждый административный экран в первый
frontend milestone. Остальной batch scope следует из принятого PLAN-002.

| Функциональность | Текущее состояние backend | Целевое поведение | Backend task ID | Необходимые изменения frontend | Готовность контракта | Зависимости/ограничения |
|---|---|---|---|---|---|---|
| Аккаунт и авторизация | Register/login/refresh/change-email/change-password реализованы | JWT через gateway; authenticated owner для обоих upload-режимов | Существующий auth; credential boundary также `.37` | Сверить auth DTO, обновление JWT, истечение сессии; logout локальный | Есть; login/refresh возвращают `token`, refresh требует `{}` и действующий JWT | Серверных logout/revocation и списка пользовательских сессий нет; новые такие API не запланированы текущими карточками |
| Workspace и контакты | CRUD реализован; voice-profile coupling удалён | Workspace и контакты для организации записи, доступа и рассылки; без voice identity | `.02`, `.25`, `.30` | Сохранить контакты name/email/IDs, убрать voice_profile_id и блокировки по отсутствию образцов | Есть; DTO owner field и пустые participants имеют особенности | Есть пробелы проверок доступа; контакт не равен аккаунту/роли или праву на результат |
| Загрузка в workspace | V2 upload реализован | Durable job после проверки файла и workspace access | `.08`, `.16`, `.22`, `.37` | Новый multipart endpoint; JWT, idempotency, сохранение job metadata; непустой список контактов не требуется owner | Есть | V2 gate, БД, storage, TLS, broker/worker; полный model E2E — `.17` |
| Запись без workspace | V2 anonymous upload/session реализованы | Owner-only обработка и уведомление без confirm и создания workspace | `.02`, `.16`, `.30`, `.37` | Отдельный выбор режима; nullable workspace; отсутствие confirm UI | Есть | JWT обязателен; anonymous source/session имеет expiry |
| Локальная запись, формат и язык | Backend принимает готовый WAV; live audio ingress отсутствует | Клиент завершает совместимый файл; RU/EN приоритетны, mixed/auto по возможностям engine | `.02`, `.08`, `.09`, `.16`, затем `.17/.29` | Проверить выход macOS/Linux recorder, размер/длительность; передавать только поддержанные options | Upload contract есть; фактический language capability set не принят окончательно | Не обещать MP3/M4A/OGG или все языки; качество определяется benchmark |
| Batch jobs и recovery | Persisted jobs, bounded workers, stage checkpoints, retries, inbox/outbox реализованы | Переживать restart/redelivery, повторять transient stage без лишнего пересчёта успешных stages | `.07–.13`, `.22`, `.28`; приёмка `.17` | Длительное ожидание, восстановление UI по сохранённым IDs, безопасный повтор upload | Есть upload/status; внутренние checkpoints не являются клиентским API | Принятый код не доказывает весь production resource/quality envelope |
| Canonical transcript | `dictai-transcript/v1` реализован | Структурированный текст, segments/words, исходные таймкоды, язык, nullable confidence и engine provenance | `.05`, `.06`, `.09`, `.11`, `.12`, `.15` | Dart DTO, таймлайн, корректная nullability и отдельное состояние no-speech | Есть: schema, Go validator, HTTP JSON | При `word_timing=unavailable` обязательно `words: []`; нельзя синтезировать confidence/timing |
| Диаризация и speakers | Recording-local global timeline и fusion реализованы | Детерминированные Speaker N, UNKNOWN/overlap, один ID на всей записи | `.05`, `.10`, `.11`, `.25`; качество `.17` | Заменить participant-oriented отображение на локальные speakers; учитывать overlap | Есть | Нет сопоставления людей между записями, API переименования/редактирования speakers |
| Статусы | Polling job/transcript/summary и anonymous session реализован | Показывать canonical до готовности summary, завершать ожидание по terminal status | `.13`, `.15`, `.16` | Раздельные UI states; backoff; сохранить job_id; не ждать только HTTP 200 | Есть; нет stage/percent/ETA/model failure detail | Projection может отставать; `structured` возвращает 202 также при failed/cancelled |
| Библиотека результатов и версии | Latest V2 job на audio владельца; pagination/date filters; известный job_id можно запросить явно | Собственная библиотека ordinary/anonymous результатов | `.15`, `.20` | Новый results repository; не считать result_id отдельным meeting ID; учитывать разные null/empty workspace представления | Есть | Нет server workspace filter и списка истории версий; legacy rows в список не входят |
| Удаление | Tombstone всех V2 versions owner/audio и очистка derived DB documents | Скрыть результат и не восстановить его redelivery | `.15`, `.20`; исторические данные `.27` | Подтверждение удаления с точным объяснением эффекта; обновить локальный список | Есть | Не является cancel или гарантией удаления всех physical bytes |
| Summary | Независимый bounded LLM downstream с checkpoints реализован | Summary без подстановки личностей; transcript остаётся при ошибке summary | `.14`, `.22` | Независимые вкладки/готовность, partial success, обработка summary_error | Есть | Требуются model credentials/config; лимиты/chunking; error codes не замкнутый frontend enum |
| Документы и original | TXT/PDF endpoints и protected original WAV реализованы | Детерминированный полный transcript; отдельные summary документы; скачивание owner | `.08`, `.14`, `.15`, `.16`, `.37` | JWT при скачивании, bytes вместо JSON; обработать независимую готовность документов и неполную передачу | Есть | PDF зависит от Typst, summary от LLM; не предполагать Range/streaming playback contract |
| Email | Durable recipients/delivery/recovery реализованы | Workspace: owner+контакты, anonymous: owner; dedup; uncertain без автоматического resend | `.02`, `.30` | Корректное описание получателей; не выводить «всем доставлено» из готовности результата | Политика есть; delivery-status/resend HTTP API нет | SMTP setup; ambiguous send требует отдельного ручного решения |
| Processing grants | Owner reissue/revoke и same-job authorization resume реализованы | Exact source/job/version access, checkpoints/budgets сохраняются при разрешённом resume | `.08`, `.37` | Original download можно реализовать; reauthorization UI требует discovery | Reissue/revoke есть; полный клиентский recovery flow не определён | Initial grant_id и authorization_failure не опубликованы; resume не общий retry |

Проверяемые источники по группам:

- Auth/workspace: [gateway](../../../services/gateway/internal/presentation/router.go),
  [auth routes](../../../services/auth-service/internal/presentation/router.go),
  [auth service](../../../services/auth-service/internal/service/auth_service.go),
  [workspace routes](../../../services/workspace-service/internal/presentation/router.go),
  [workspace service](../../../services/workspace-service/internal/service/workspace_service.go).
- Upload: [handler](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go),
  [application/DTO](../../../services/audio-ingest-service/internal/application/upload_v2.go),
  [transaction](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go),
  [WAV validator](../../../services/audio-ingest-service/internal/infrastructure/db/upload_wav.go).
- Speech: [canonical contract](../../../contracts/speech/README.md),
  [validator/types](../../../contracts/speech/transcript.go),
  [use case](../../../services/speech-processing-service/internal/application/process_audio.go),
  [job persistence](../../../services/speech-processing-service/internal/infrastructure/persistence/jobs.go),
  [messaging](../../../services/speech-processing-service/internal/infrastructure/messaging).
- Results: [status/canonical/documents](../../../services/results-service/internal/presentation/handlers/speech_handler.go),
  [list projection](../../../services/results-service/internal/infrastructure/persistence/postgres_result_repository.go),
  [delete transaction](../../../services/results-service/internal/infrastructure/persistence/speech_delete.go).
- Downstream: [summary worker](../../../services/summarization-service/internal/v2/worker.go),
  [deterministic renderer](../../../services/summarization-service/internal/v2/render.go),
  [notification implementation](../../../services/notification-service/internal),
  [recipient/delivery policy](PLAN-002-upload-notifications-api.md).
- Delegation: [ADR-003](ADR-003-batch-audio-delegation.md),
  [owner handlers](../../../services/audio-ingest-service/internal/presentation/handler/grants.go),
  [resume contract/registry](../../../contracts/speech/delegation/resume.go).

## 4. Незавершённые backend-этапы и зависимости

### 4.1 Снимок статусов

Изучены все 44 карточки `TASK-002.01`–`TASK-002.44` в [tasks](../tasks).
В frontmatter: 36 `accepted`, 4 `draft`, 1 `review`, 2 `blocked`, 1 `cancelled`;
`in_progress` нет. Не следует называть все эти задачи одновременно выполняемыми.

Незавершённые задачи:

| Задача | Статус | Точный depends_on | Ожидаемый результат и влияние на frontend |
|---|---|---|---|
| [TASK-002.17](../tasks/TASK-002.17.md) | draft | `.39`, `.04`, `.12`, `.13`, `.14`, `.15`, `.16`, `.20`, `.22`, `.23`, `.25`, `.26`, `.28`, `.29`, `.30` | Реальная CPU quality/robustness E2E-приёмка ordinary/anonymous на новом стеке. Блокирует утверждение production готовности; не блокирует реализацию клиента по имеющемуся wire contract |
| [TASK-002.18](../tasks/TASK-002.18.md) | review | `.04`, `.09`, `.10`, `.28` | Opt-in GPU runtime/config уже реализован; R18-01 исправлен и повторно проверен. NVIDIA hardware/image/full GPU smoke не подтверждены; публичный контракт сохраняется |
| [TASK-002.19](../tasks/TASK-002.19.md) | draft | `.17`, `.18` | Сравнение CPU/GPU/API и решение владельца. Выбор внешнего API создаёт отдельный adapter implementation plan; это не готовый provider selector для UI |
| [TASK-002.21](../tasks/TASK-002.21.md) | draft | `.06`, `.17` | Только дизайн live/progress/replay, protocol proposals и отдельный будущий implementation plan; live production implementation в scope нет |
| [TASK-002.24](../tasks/TASK-002.24.md) | blocked | `.17` | Новый routing/staging/runbook и явная политика in-flight jobs. Реальный production deployment требует отдельного разрешения |
| [TASK-002.29](../tasks/TASK-002.29.md) | draft | `.02`, `.26` | Воспроизводимый baseline, замороженный acceptance split и согласованные владельцем numerical quality gates. Не создаёт новый frontend endpoint |
| [TASK-002.31](../tasks/TASK-002.31.md) | blocked | `.24` | Evidence фактически состоявшегося production перехода; задача не разрешает deployment автоматически |

Остальные карточки accepted, кроме отменённой `.40`. Приёмка относится к
зафиксированному scope, а не обязательно к полному исходному названию задачи.

### 4.2 Ограниченная приёмка и семантический blocker quality

- [TASK-002.04](../tasks/TASK-002.04.md): принят provisional CPU выбор
  faster-whisper large-v3-turbo + pyannote Community-1. Это не окончательная
  production quality/runtime приёмка.
- [TASK-002.26](../tasks/TASK-002.26.md): принят benchmark harness в provisional
  scope. Кодовые доработки diagnostics/CLI завершены в
  [TASK-002.41](../tasks/TASK-002.41.md), но полноценный real baseline не подтверждён.
- [TASK-002.38](../tasks/TASK-002.38.md): приняты два текущих RU-разговора,
  текст/спикеры, automatic word times, viewer, hashes и owner receipts.
  Повторное прослушивание принятых версий не требуется.
- [TASK-002.39](../tasks/TASK-002.39.md): `accepted` по Result от 2026-10-23
  **только для `plan002-ru-local-bundle`**. Подготовлены два real RU records;
  owner подтвердил text/speakers/boundaries/continuity. EN/mixed, прочие
  quality/operational scenarios, полное покрытие splits и reviewer lock
  исключены именно из этой ограниченной приёмки. Полный benchmark
  `--require-ready` остаётся exit 2. Исходные строгие требования сохранены
  для отдельного расширения, а не объявлены выполненными.
- [TASK-002.42](../tasks/TASK-002.42.md): принят код строгого validator.
  Tiny synthetic tests не доказывают наличие real 1 GiB/two-hour assets.
- [TASK-002.28](../tasks/TASK-002.28.md): принят CPU profile/CI в описанном
  implementation/local-verification scope; полный real-model container/target
  platform E2E этим не подтверждён.
- [TASK-002.27](../tasks/TASK-002.27.md): принят design очистки исторических
  данных. Destructive execution не выполнено и требует отдельной авторизации.

Следствие для планирования: формально принятый `.39` не закрывает входные данные
для `.26/.29/.17`. Нужно отдельное решение, как оформить и выполнить остаток
полного dataset/acceptance milestone. Этот документ не переоткрывает `.39`,
не назначает новый task ID и не ослабляет требования validators/gates.

### 4.3 Последовательность готовности

```text
Полный dataset / acceptance readiness: остаток после ограниченной .39
  → реальные baseline runs через принятый harness .26/.41
  → согласование численных gates .29
  → CPU E2E .17 на окончательном новом стеке
  → routing/staging/runbook .24
  → отдельно авторизованный production deployment
  → production evidence .31

.04/.09/.10/.28 → opt-in GPU .18
.17 + .18 → runtime comparison/decision .19
.06 + .17 → live design .21 → отдельный будущий implementation plan
```

Это обзор milestone-порядка; полный task graph задаётся `depends_on`, а не
этой схемой. API/runtime removal `.25/.20` уже принят и предшествует `.17`.
GPU не блокирует CPU cutover; legacy rollback window не требуется.
Design `.27` не разрешает физическую очистку данных и не добавляет UI-функции.

## 5. Асинхронная модель и правила для клиента

### 5.1 Запуск и наблюдение

- Upload возвращает 202 после durable acceptance, не после распознавания.
- Повтор того же upload использует прежний `Idempotency-Key` и те же inputs.
  Изменение файла/options или deployment revisions может дать 409.
  Повтор upload не равен новому reprocess существующего audio.
- Для принятой версии использовать `?job_id=<job_id>` в result/status/document
  запросах. Без job_id выбирается latest job; это не API списка версий.
- Speech status содержит ровно публичные поля `job_id`, `processing_version`,
  nullable `workspace_id`, `job_status`, `transcript_status`, `summary_status`,
  nullable `summary_error`.
- `job_status`: `queued/running/completed/failed/cancelled`.
  `transcript_status`: `pending/ready/failed/cancelled`.
  `summary_status`: `pending/ready/failed`. Это разные состояния, не один enum.
- В canonical JSON nullable не означает необязательный ключ: схема требует
  наличие ключей, в том числе `confidence`, `language`, `workspace_id` и массивов.
  При `word_timing=unavailable` массив `words` пуст, а при `no_speech` пусты
  `speakers` и `segments`. Не восстанавливать искусственные интервалы из текста.
- `structured` возвращает 200 с canonical JSON или 202 со status при
  неготовом transcript, **в том числе failed/cancelled**. После terminal status
  не продолжать бесконечный polling в ожидании 200.
- `transcript_status=ready` отражает projection; временно недоступный/corrupt
  artifact всё равно может дать 503. Не подменять это пустым транскриптом.
- Anonymous session имеет собственные `queued/running/ready/failed/cancelled/expired`,
  `confirm_required=false`. Это не публичный job enum и не общий статус документов.
- Results list `pending/done/failed` также является отдельной проекцией;
  `done` не означает готовую summary.

### 5.2 Partial success и действия пользователя

После canonical persistence ошибки summary/render/notify не должны запускать
ASR заново или уничтожать транскрипт. Готовность canonical JSON, TXT, PDF и
summary различается. Документ может возвращать 404 до появления bytes;
это само по себе не означает отсутствие audio. Download URL требует JWT.
Неполную передачу original необходимо считать неуспешной.

В backend есть внутренний owner-scoped `Repository.Cancel`, отмена active work,
checkpoints и cancellation handling. **Зарегистрированного публичного HTTP
cancel endpoint нет.** Нельзя придумывать route на основании внутреннего метода.
Требования описывают cancellation SLA, но публичный contract ещё нужен отдельно.

Processing grant reissue — специальный authorization resume того же job.
Новый resume исключает completed/cancelled/deleted jobs и произвольную model
failure; checkpoint/attempt budgets не сбрасываются. Сохранённый idempotent
replay может вернуть прежний 202 уже после завершения/удаления job — это не
новое возобновление. Initial `grant_id` и `authorization_failure` не выдаются
upload/status/structured, поэтому законченный пользовательский recovery UI
сейчас не обеспечен. Revoke grant не означает cancel job или logout.

Источники: [status handler](../../../services/results-service/internal/presentation/handlers/speech_handler.go),
[session projection](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go),
[cancel persistence](../../../services/speech-processing-service/internal/infrastructure/persistence/jobs.go),
[resume implementation](../../../contracts/speech/delegation/resume.go),
[processing grants handler](../../../services/audio-ingest-service/internal/presentation/handler/grants.go).

### 5.3 Лимиты и ожидание

- Файл: PCM/IEEE-float RIFF WAVE, до 1 GiB (1,073,741,824 bytes) и 7200 s;
  8–192 kHz, 1–8 каналов. MP3/M4A/OGG, RF64/WAVE_FORMAT_EXTENSIBLE не принимаются.
- `language` — пусто/ru/en; `mixed=true` требует пустого `language`.
- Нельзя полагаться на стабильный HTTP 413: превышение multipart body может
  дать 400 `audio_required`. Общего унифицированного error envelope нет.
- Upload занят: 429 `upload_busy`, `Retry-After: 5`; это отличается от общего
  gateway rate limit. Upload request context — 15 минут, внешний proxy может
  иметь иной timeout.
- Anonymous source/session TTL — 7 дней. Это не общий retention всех результатов.
- Целевой CPU envelope: 8 GiB worker RAM, 10 GiB temp/job, default model
  concurrency 1, queue p95 ≤15 min, processing p95 RTF ≤2 на заданном load/hardware.
  Hard processing timeout по требованиям — `max(30 min, 3 × duration)`, до 6 h.
  Это требования, **не подтверждённые production SLA и не публичный ETA**.
- Наличие внутренних stage attempts/Prometheus metrics не добавляет stage progress
  в status JSON. У клиента нет утверждённых percent/queue position/ETA.

Источники: [операционные требования](PLAN-002-requirements.md),
[upload handler](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go),
[WAV validation](../../../services/audio-ingest-service/internal/infrastructure/db/upload_wav.go),
[внутренняя observability](../../../services/speech-processing-service/internal/infrastructure/observability/http.go),
[CPU runbook](../../../infra/speech-cpu.md).

## 6. Исключено, заменено или не входит в продуктовый scope

| Элемент | Решение и следствие для frontend | Источник |
|---|---|---|
| Voice profiles, persistent embeddings, cross-record identity, participant-to-speaker mapping | Исключены новой моделью. Не создавать профиль, не записывать голосовой образец ради upload | ADR-006/009 в [decisions](../decisions.md), [TASK-002.25](../tasks/TASK-002.25.md) |
| Anonymous confirm/speaker fragments | Удалены. Не добавлять обязательное подтверждение или создание workspace после обработки | [TASK-002.16](../tasks/TASK-002.16.md), [TASK-002.25](../tasks/TASK-002.25.md) |
| Старый WhisperX-service, legacy upload/results paths, consumers и fallback | Удалены из runtime. Нет требования поддерживать старый клиент/старые результаты через compatibility adapter | [TASK-002.20](../tasks/TASK-002.20.md), ADR-009 |
| Ожидание legacy rollback window перед removal | Заменено порядком `.25/.20 → .17 → .24/.31` | [cutover/retirement plan](../plans/PLAN-002-cpu-cutover-retirement.md) |
| AMI review | `.40` cancelled; не blocker и не выполненная проверка. Английский язык из product target не исключён | [TASK-002.40](../tasks/TASK-002.40.md) |
| Прежний полный scope `.38` | Заменён минимальным RU scope; расширенный benchmark не объявлен готовым | [решение по .38](../decisions.md), [Result .39](../tasks/TASK-002.39.md) |
| Offline annotation/import/viewer/benchmark/alignment | `.03`, `.26`, `.32–.36`, `.38–.39`, `.41–.44` — evaluation/supporting tools. Не переносить их web UI и команды в продукт без отдельного решения | [evaluation/speech](../../../evaluation/speech), [code completion plan](../plans/PLAN-002-code-completion.md) |
| YouTube intake `.43` и forced alignment `.44` | Не означают наличие product API «загрузить YouTube URL» или «запустить alignment» | [RU intake plan](../plans/PLAN-002-ru-youtube-intake.md), [alignment plan](../plans/PLAN-002-ru-word-alignment.md) |

Whisper-family модели не запрещены: исключён старый сервис/его API, а не семейство
моделей. Временные внутренние embeddings inference разрешены, но не выдаются и
не сохраняются DictAI как voice identity.

Chat/history/user prompts, публичное sharing, invitations/roles, speaker editing,
универсальный retry/reprocess и пользовательский runtime selector не подтверждены
актуальными задачами как согласованные обязательные product features.
Их отсутствие нельзя превращать в обещание «появятся после завершения PLAN-002».

`GET /workspaces/{workspace_id}/meetings` и `GET /meetings/{meeting_id}` есть
только в OpenAPI, без routes/handlers. Это не доказательство актуального roadmap.

## 7. Будущие возможности без готового пользовательского контракта

| Возможность | Что согласовано/реализовано | Чего не хватает | Условие начала зависимой frontend-реализации |
|---|---|---|---|
| Live/incremental transcript | Согласован дальнейший дизайн `.21` после batch acceptance | Transport SSE vs WebSocket, routes, envelope, stable segment IDs, revisions, ordering/dedup, partial/final, speaker corrections, reconnect/replay | Принятый `.21` и отдельный implementation plan/contracts; сама `.21` не реализует сервер |
| Batch stage progress | Есть private stage metrics `.23`; `.21` должна отделить progress от replay/live | Публичная модель stage/progress; semantics percent/ETA, если они вообще нужны | Решение и внешний contract; не читать внутренний Prometheus из клиента |
| Пользовательская отмена | Внутренняя отмена `.13`, требования `.02`, E2E checks `.17` | HTTP command, ответы/idempotency, внешнее отображение cancel-requested/ack/terminal | Отдельно утверждённый публичный API; `.17` не обещает его автоматически |
| Authorization recovery | `.37` accepted, reissue/revoke routes есть | Discovery grant_id, обнаружение authorization_failure, согласованный UI action | Источник необходимых данных и contract; не угадывать ID |
| Retry/reprocess/version history | Есть automatic stage retry, upload idempotency и query известного job_id | Команда новой обработки/summary retry, правила версий и список истории | Сначала продуктовый scope и новый API; не заменять повторным upload без решения |
| Sharing/доступ контактов | Owner-only canonical/original; contacts используются для email | Если требуется — политика прав, sharing/invitation API, доступ получателя к результату | Отдельное business/security решение; текущие tasks не обещают sharing |
| Delivery management | `.30` реализует per-recipient state и operator handling uncertain | Public delivery-status/resend API | Только если такой UI выбран владельцем; сейчас это не обязательный экран |
| Физическая очистка/общий retention | `.27` accepted design; anonymous source TTL известен | Общая пользовательская политика source/canonical/documents, execution scope и права удаления | Утверждённая lifecycle policy; текущий DELETE не доказывает уничтожение всех bytes |
| Chat и новые AI-команды | Есть async summary `.14` | Нет chat API/history/актуальной задачи на них | Отдельное подтверждение scope и контракт; не подключать provider из Dart по предположению |

Согласованное направление не равно согласованному wire format. В mock DTO нельзя
добавлять придуманные `progress`, `stage`, `segment_id`, `revision`, `grant_id` или
новые terminal enums в существующие ответы. Концептуальные UX-макеты возможны
отдельно, с явной пометкой proposal и без заявления о готовой интеграции.

## 8. Разделение frontend-работ

Это рекомендации для будущего backlog, не новые task-карточки и не разрешение
сразу выполнять перечисленное. «Сейчас» означает достаточность известного
контракта; проверка на живом backend всё равно требует тестового deployment.

### 8.1 Можно реализовывать сейчас

- Backend client/DTO по существующим операциям: auth, workspace/contacts,
  V2 upload, results/status/canonical, documents/original.
- Согласование auth wire details: `token`, refresh с `{}` и действующим JWT,
  `new_email`/`new_password`; локальный logout и переход на login после expiry.
- Удаление зависимостей пользовательского flow от voice profiles/confirm.
- Canonical Dart-модель, nullable поля и преобразование integer microseconds
  в UI-время; локальные Speaker N, UNKNOWN, overlap, no-speech.
- Разделение repository/UI states для upload, job, canonical, summary, документов.
- Подготовка локального recorder/file validation к WAV-контракту на macOS/Linux.
  Platform permissions/build/smoke должны проверяться в отдельном выбранном scope.
- JWT при скачивании, относительные API URL, bytes/JSON parsing и корректная
  обработка неполного download. Имя документа клиент выбирает сам.
- Тестирование DTO/error/status mapping по текущему коду и существующему API-отчёту.

Scope экранов account/workspace, UX playback и способ хранения локального job
state следует выбрать при frontend-планировании; наличие API не задаёт дизайн.
Riverpod/GoRouter/Dio — способы организации клиента, не новые требования backend.

### 8.2 Можно реализовывать с mock-данными по существующим контрактам

- Полный ordinary/anonymous batch flow с реальными DTO upload response.
- Polling, повтор после transient network error и восстановление UI по job_id;
  сохранение idempotency key для того же запроса до однозначного результата.
- Queued/running/completed/failed/cancelled, projection pending, artifact 503.
- Canonical ready при summary pending/failed; TXT готов при отсутствии PDF.
- No-speech, длинный текст, UNKNOWN, overlap, отсутствующие word timestamps.
- Results pagination/date filters, anonymous workspace empty strings в list
  против null в canonical/status, delete/tombstone responses.
- Upload 400/401/403/409/429/503, expired anonymous session, download failures.
- Получение original и локальный playback по таймкодам без предположения о
  серверном Range/streaming контракте.

Это те же функции, которые затем проверяются на настроенном backend. Mocks
позволяют начинать до `.17/.24/.31`, но не доказывают model quality или deployment.
Для реального live ещё нет утверждённого протокола, который можно достоверно mock-нуть.

### 8.3 Необходимо отложить до контракта или готовности backend

- Привязку кнопок cancel/retry/reprocess и recovery grant к серверным действиям —
  до API/discovery из раздела 7.
- Реальный live transport, partial/final revisions и reconnect — до `.21` и
  последующей реализации; progress percent/ETA — до отдельной публичной модели.
- Sharing, историю версий, editing speakers, chat и delivery management —
  до выбора scope и контрактов; они не входят автоматически в первый release.
- Утверждение production качества, throughput и полного recovery — до `.17`
  с baseline/gates. Их нельзя заменить успешным запуском mock frontend.
- Production проверку и выпуск интеграции — согласовать с `.24/.31`, фактическим
  deployment и политикой old in-flight jobs; не ждать GPU ради CPU milestone.

## 9. Достаточность FRONTEND_API_CONTRACTS.ru.md

API-отчёт достаточен как source-driven база для текущего batch-клиента: он
описывает 25 реализованных внешних операций, DTO, ограничения, примеры, статусы,
удалённые пути и prerequisites. Он уже отмечает отсутствие live/cancel/chat,
grant discovery и другие открытые вопросы. Его статус `researched` не является
приёмкой frontend или отдельным утверждением всех будущих контрактов.

Для планирования полного будущего продукта его нужно читать вместе с этим
scope-документом и backend task Result. Особенно важно ограничение `.39`:
слова «dataset/tooling accepted» не подтверждают complete canonical benchmark.

Пока отсутствуют утверждённые будущие спецификации live/progress/cancel/recovery,
версий/reprocess/sharing и общей lifecycle policy из раздела 7. Некоторые из
них лишь вопросы, а не требования. Часть может вообще не войти в продукт после
согласования. Этот документ не заполняет пробелы выдуманными endpoints/JSON.

OpenAPI [contracts/api/openai.yml](../../../contracts/api/openai.yml) расходится
с кодом: в API-исследовании зафиксированы 25 фактических операций, 18 в spec,
16 совпадающих после нормализации trailing slash, 9 отсутствующих в spec и
2 spec-only. Совпадение URL не гарантирует совпадение DTO/status. Генерация
Flutter-клиента только по текущему OpenAPI требует предварительной сверки и
отдельно согласованного обновления spec; существующая spec здесь не меняется.

## 10. Открытые вопросы и ограничения

1. Какой frontend batch milestone выбран: какие account/workspace экраны,
   экспорт и playback входят в первую поставку? Live остаётся отдельным направлением.
2. Как оформить и закрыть остаток full dataset после limited acceptance `.39`?
   Кто предоставляет реальные inputs/acceptance evidence для baseline/gates?
3. Каковы согласованные terminal UI actions, polling/backoff и client deadlines
   при длительном pending? Числовые model error/stage детали публично отсутствуют.
4. Нужны ли cancel, повтор summary/ASR, version history и authorization recovery
   в первом milestone? Если нужны, какие backend tasks закрывают внешние API?
5. Как решить существующие workspace access особенности: GET detail без
   owner-check, participant_id vs account user_id, missing workspace errors?
   Текущий UI не должен обещать полноценную membership/roles модель.
6. Должны ли email-получатели открывать результат? Сейчас документы owner-only;
   contact/email не создаёт доступ. Sharing требует отдельного решения.
7. Каков общий retention source/canonical/documents и точная пользовательская
   семантика delete/expiry? Anonymous TTL 7 дней не отвечает на все вопросы.
8. Какова судьба legacy результатов и старых jobs/sessions? Совместимость
   отменена, historical bytes сохранены, автоматическая миграция в новый UI не обещана.
9. Кто предоставляет test base_url/TLS и deployment с V2 gate, миграциями,
   broker TLS/ACL, source grants/mTLS, MinIO versioning, offline models,
   artifact storage, workspace/auth dependencies, LLM/Typst/SMTP по scope проверки?
10. Каков подтверждённый language capability set и reference hardware/load?
    RU/EN приоритетны; качество всех языков и точный ETA не обещаны.
11. Нужен ли replay готового текста, batch progress или настоящий streaming?
    Это разные сценарии; будущая `.21` должна их разделить.
12. Требуется ли синхронизация OpenAPI до code generation? Кто принимает
    согласованный контракт для отдельного frontend repository?

Наличие routes означает кодовую реализацию, а не работающий deployed сервис.
V2 gate/router может вернуть 503, но штатный startup при отсутствии обязательных
TLS/artifact/config prerequisites может завершиться до HTTP. Через gateway
в таком окружении возможен 502. Отдельные JSON endpoints не подтверждают полный
обычный/anonymous model E2E, SMTP delivery или production SLA.

## 11. Навигация по планам и supporting work

Все планы текущего `docs/ai/plans/` относятся к PLAN-002 или его supporting work:

| План | Значение для frontend-планирования |
|---|---|
| [speech-pipeline-rework](../plans/PLAN-002-speech-pipeline-rework.md) | Основной target, этапы и реестр; исторические состояния проверять по карточкам |
| [jobs-delivery](../plans/PLAN-002-jobs-delivery.md) | `.12/.13/.22`: durable processing/recovery; не клиентский event stream |
| [downstream-cpu](../plans/PLAN-002-downstream-cpu.md) | `.14/.15/.23/.28`: canonical/results/documents/metrics/profile; часть legacy описаний историческая |
| [upload-notifications](../plans/PLAN-002-upload-notifications.md) | `.16/.30`: два upload-режима и email policy; сосуществование legacy отменено позднее ADR-009 |
| [profile-api-retirement](../plans/PLAN-002-profile-api-retirement.md) | `.25`: убрать profile/confirm coupling; contacts сохранить |
| [legacy-runtime-retirement](../plans/PLAN-002-legacy-runtime-retirement.md) | `.20`: новый-only runtime и результаты; прежние пути не восстанавливать |
| [cpu-cutover-retirement](../plans/PLAN-002-cpu-cutover-retirement.md) | Порядок removal/acceptance/cutover и separate deployment |
| [data-retirement](../plans/PLAN-002-data-retirement.md) | `.27`: cleanup design, не выполненное уничтожение данных |
| [delegation-implementation](../plans/PLAN-002-delegation-implementation.md) | `.37`: exact-version grants и same-job authorization resume |
| [available-code](../plans/PLAN-002-available-code.md) | История выбора кодовых этапов и ограничений; старые статусы не текущий roadmap |
| [code-completion](../plans/PLAN-002-code-completion.md) | `.34/.41/.42`: supporting tools, не production dataset или E2E; review-статусы в плане устарели |
| [dataset-completion](../plans/PLAN-002-dataset-completion.md) | Сужение ручного scope, отмена AMI, выделение полного benchmark; поздний Result `.39` уточняет limited acceptance |
| [ru-review-completion](../plans/PLAN-002-ru-review-completion.md) | `.34–.36`: review tooling, не экран продукта |
| [ru-youtube-intake](../plans/PLAN-002-ru-youtube-intake.md) | `.43`: локальный intake, не URL upload API |
| [ru-word-alignment](../plans/PLAN-002-ru-word-alignment.md) | `.44`: automatic proposal word times, не новая пользовательская API-команда |

Кодовая карта [code-map.md](../code-map.md) — навигационный индекс, не источник
готовности функций. CodeGraph CLI/MCP/root index в среде исследования отсутствуют;
использованы прямое чтение и `rg`, без установки/индексации/config changes.

## 12. Verification и Result

Создан только этот документ по прямому запросу пользователя. API-отчёт не
редактируется. Backend/frontend source, зависимости, спецификации, plans/tasks,
статусы, migrations и deployment не входят в изменяемый scope.

Проверки выполнены 2026-10-24 из корня backend. Результаты предыдущих task
verification и API-исследования являются историческим evidence, а не повторно
запущенными тестами текущего документа. Для проверок ниже использованы Git и
Python 3 standard library, без установки зависимостей или изменения окружения.

| Проверка | Результат |
|---|---|
| `git rev-parse HEAD`, task frontmatter и Result | PASS: SHA совпадает с frontmatter документа; 44 карточки, ограниченная приёмка `.26/.39` и design-only `.27` учтены |
| Согласованность с API-отчётом, routes и decisions | PASS при source review: upload/status/canonical/documents/grants, ADR-005–009, SMTP policy и отсутствие будущих routes сверены; это не runtime test |
| Python: разрешение локальных Markdown-ссылок | PASS: все 92 ссылки ведут в существующие файлы/директории |
| Python: task graph и таблица незавершённых задач | PASS: 44 уникальных ID, нет отсутствующих dependencies/циклов; статусы и точный порядок depends_on всех 7 незавершённых карточек совпадают с таблицей |
| Полный no-index diff нового Markdown; `git diff --check`; `git diff --no-index --check /dev/null docs/ai/research/FRONTEND_TARGET_SCOPE.ru.md` | PASS: новый файл целиком проверен, whitespace/conflict markers не найдены; exit 1 обычного no-index diff означает наличие нового файла, whitespace check даёт exit 0 |
| SHA-256 baseline до/после и Git status | PASS: все 586 исходных tracked-файлов и существующий API-отчёт неизменны, 587/587 hashes совпали; новый файл — только этот документ, прежний untracked output сохранён |
| Независимый read-only review | PASS: `/root/review_frontend_target_scope` не участвовал в написании, сверил scope/контракты/решения/status/dependencies/92 links; actionable findings и открытых P0/P1/P2/P3 нет; reviewer ничего не записывал |
| Runtime/model/DB/SMTP/production tests | NOT RUN: изменяется только planning documentation |

Reviewer проверил содержательную часть документа, включая уточнение required
nullable keys/arrays; таблица Verification затем заполнена автором по фактическим
результатам. Отдельный review-файл не создавался: findings переданы автору
read-only сообщением. Документальный review не устанавливает production readiness
и не является приёмкой результата пользователем.

Документ остаётся `researched`. Он не принимает backend/frontend задачи,
не меняет утверждённые API и не разрешает commit/push/deployment.
