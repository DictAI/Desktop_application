---
title: "DictAI: запросы на изменение backend для целевого frontend UX"
date: "2026-11-02"
status: researched
scope: backend-contract-impact-analysis
frontend_commit: 80959cc10eacabf45fbf461dbe596030e4e7277c
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
related_plan: PLAN-FE-001
implementation_authorized: false
---

# Backend change requests: будущие назначения и текущий UX

## 1. Назначение и статус

**Граница этапов 2026-11-02.** Требования BR-02/03/04 сохранены для будущей
backend-разработки, но не входят в текущую реализацию frontend. Сейчас нет editor,
локальных имён, contact binding, mock repository/демонстрации save или named export.
Текущая версия показывает backend Speaker labels и скачивает текущие server bytes.
.43/.45/.46/.47/.50/.51 — future C blocked; .44 и самостоятельная часть .48 остаются
current. Mock-прототип и unavailable production editor из прежней стратегии отменены.
Это не отмена согласованных будущих requirements; до backend нельзя делать их UI.


Основание — прямые продуктовые решения пользователя от 2026-10-26 в
[FRONTEND_TARGET_UX.ru.md](FRONTEND_TARGET_UX.ru.md), включая Skip, позднее назначение
и окончательное правило навигации. Источники прежнего wire и scope:
[BACKEND_API_CONTRACTS](BACKEND_API_CONTRACTS.ru.md),
[BACKEND_TARGET_SCOPE](BACKEND_TARGET_SCOPE.ru.md). Их содержимое не меняется.

Это запросы на согласование, не принятый API design, не backend task-карточки
и не разрешение реализации. **Окончательные новые URL, HTTP-методы, JSON fields,
статусы ошибок и migrations здесь намеренно не назначены.** BR-01…BR-07 — локальные
обозначения разделов, не task ID. Созданы frontend .43–.51; backend task ID не выданы.

**СОГЛАСОВАНО:** ручное имя или явный выбор контакта для конкретной записи;
имена переживают сеансы; назначение независимо от summary; voice profiles,
биометрическая идентификация и обязательный processing confirm не нужны.
**ОКОНЧАТЕЛЬНО СОГЛАСОВАНО 2026-10-26:** backend persistence после login/на других
устройствах; marker — валидный canonical transcript; snapshot имени при выборе
контакта, неизменный после rename/delete; один contact может иметь несколько Speaker
с предупреждением; имена во всех применимых transcript/summary TXT/PDF. Реализации
и wire этих новых server capabilities пока нет. Только frontend планирование.

## 2. Что уже подтверждено реализацией

Backend checkout `/Users/verliiar/phiziks_pr`, SHA из frontmatter совпадает с
исследованным API-срезом. Прочитаны реальные routers/handlers, canonical types/
validator/schema, workspace domain/handler и downstream renderer/worker.
Live API, модели, SMTP и download/playback не запускались.

| Источник | Подтверждённый факт |
|---|---|
| [results router](/Users/verliiar/phiziks_pr/services/results-service/internal/presentation/router.go:22) | R01/R02 и условно R03–R05 зарегистрированы; routes ручных назначений отсутствуют |
| [speech handler](/Users/verliiar/phiziks_pr/services/results-service/internal/presentation/handlers/speech_handler.go:30) | R03 имеет семь полей job/version/workspace/job_status/transcript_status/summary_status/summary_error; отдельной публичной diarization stage нет |
| [structured handler](/Users/verliiar/phiziks_pr/services/results-service/internal/presentation/handlers/speech_handler.go:72) | R04 отдаёт immutable canonical bytes при ready; иначе 202 status, включая failed/cancelled; artifact может вернуть 503 |
| [canonical types/validator](/Users/verliiar/phiziks_pr/contracts/speech/transcript.go:48), [schema](/Users/verliiar/phiziks_pr/contracts/speech/transcript.schema.json) | Speaker — ID и label; segments имеют speaker_id/start_us/end_us/text и words. Validator на строке 163 требует contiguous speaker_N и точные Speaker N, не имена людей |
| [processing orchestration](/Users/verliiar/phiziks_pr/services/speech-processing-service/internal/application/process_audio.go:235) | Внутренние ASR/diarization/fusion/validation/persistence предшествуют выдаче canonical; внутренние stages не являются frontend API |
| [ingest router](/Users/verliiar/phiziks_pr/services/audio-ingest-service/internal/presentation/router.go:22), [original handler](/Users/verliiar/phiziks_pr/services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go:81) | Есть V2 upload/session/original/grants; нет текущего speaker-fragment endpoint; U04 отдаёт owner-authorized WAV, не signed public storage URL |
| [participant domain](/Users/verliiar/phiziks_pr/services/workspace-service/internal/domain/participant.go:3), [workspace router](/Users/verliiar/phiziks_pr/services/workspace-service/internal/presentation/router.go:24) | Contact имеет ParticipantID/WorkspaceID/Name/Email; speaker ID или запись в этой модели не представлены |
| [создание контакта](/Users/verliiar/phiziks_pr/services/workspace-service/internal/presentation/handlers/add_participant_handler.go:11) | W07 требует name и email; name-only contact не поддержан; ответ содержит participant_id и сведения контакта |
| [render.go](/Users/verliiar/phiziks_pr/services/summarization-service/internal/v2/render.go:17) | Transcript TXT и вход summary используют canonical Speaker N; существующего overlay назначений нет |
| [summary worker](/Users/verliiar/phiziks_pr/services/summarization-service/internal/v2/worker.go:37) | Transcript text материализуется при canonical event; PDF/summary создаются независимо от позднейшего ввода пользователя, сохранённые chunk outputs имеют hashes |
| [notification worker](/Users/verliiar/phiziks_pr/services/notification-service/internal/durable/worker.go:115) | Lookup получателей и сохранённые delivery состояния самостоятельны; создание нового контакта не означает гарантированного пересчёта уже разрешённых recipients/resend |

Абсолютные ссылки — evidence на проверенном checkout; на другом компьютере
заменить `/Users/verliiar/phiziks_pr` на корень того же backend SHA. Это не пути
frontend. Содержательная информация в таблице самодостаточна для передачи агенту.

Во frontend существующий [LabelSpeakersModal](../../../lib/features/record/presentation/label_speakers_modal.dart)
использует [legacy session API](../../../lib/features/record/data/anonymous_session_api.dart)
для fragment/confirm, требует имя/email и может создать workspace. Он не доказывает
поддержку новых назначений: эти backend routes удалены, ordinary назначения нет,
связи с participant ID и нового persistence нет. Повторно включать их нельзя.

## 3. BR-01: canonical readiness, Speaker ID и интервалы

**Решено:** ждать валидный canonical transcript с результатами диаризации, независимо
от summary. Existing R03 (`speech-status`) и R04 (`structured`) достаточны:
после transcript ready получить R04 200 нужного audio/job; speakers и segments
с integer microseconds — подтверждённый источник ID/intervals. List done/job completed/
anonymous ready без canonical не заменяют этот marker. 202 failed/cancelled terminal,
artifact503 не трактовать как готовую форму. Отдельный early diarization API не нужен.

Сейчас waiting→готовый transcript, elsewhere→in-app notice с открытием результата,
restart→Results реализует current .48 с dedupe/owner/session guards. Будущий переход
к editor после backend подключает .50, не блокируя текущую .48. Для этого не нужны server push/NATS/WebSocket/SSE.
no_speech без speakers — успешный empty state, UNKNOWN не один установленный человек.

## 4. BR-02 и BR-03: серверные назначения и workspace contacts

### Согласованная цель, ещё отсутствующий контракт

Backend — authoritative источник имён после повторного login и на других устройствах.
Необходимы семантические операции **прочитать**, **сохранить/обновить** и **сбросить
назначение к Speaker N** для доступного результата. Это capabilities, а не утверждённые
URL/HTTP-методы/JSON. Read может стать отдельной проекцией/операцией по согласованию;
незаметно менять immutable canonical R04 или W06/W07 нельзя.

Условия будущего контракта:

- Verified owner из JWT, точный audio/job/version и Speaker ID его canonical;
  ID/таймкоды/canonical labels не переписываются. Предлагаемый namespace owner/audio/
  job/speaker — invariant изоляции, не назначенный wire field.
- Manual name, отсутствие имени/Speaker N либо выбранный реальный participant ID
  с **именем на момент назначения**. Историческое имя не меняется после contact rename/
  delete; поведение dangling ID должно сохранять display snapshot, не терять запись.
- Один contact может быть явно выбран для нескольких Speaker IDs; backend не вводит
  противоречащую этому уникальность. FE показывает warning, не merge или запрет.
- Для workspace contact принадлежит именно workspace записи и проверяется сервером;
  owner-only запись допускает manual/default без фиктивного workspace/контакта.
- Read/save независимы от summary pending/failed/ready; именование не создаёт новый
  model job, ASR/diarization/LLM retry или processing-confirm.
- Read error отличается от пустых назначений. Save atomicity/full-map vs patch,
  concurrency/conflict resolution, validation/limits и lost-response/idempotent retry
  должны быть согласованы; неизвестные текущие данные не перезаписываются молча.
- Tombstone/deletion, чужой owner/job/speaker и late requests получают определённый
  отказ; raw technical errors не раскрываются. Reset не удаляет контакт/результат;
  Skip ничего не подтверждает серверу и отдельного endpoint не требует.

Точные wire DTO, методы, status/error codes, server revision и discovery/freshness
пока **не утверждены**. Backend-команда выдаёт task ID/owner/срок/actual commit;
эти поля не заполняются вымышленными номерами frontend.

### Что уже есть и что откладывается до backend

W06 даёт contacts, W07 создаёт по реальным name/email. Contact model не содержит
Speaker ID, CRUD **не сохраняет** связь с записью. Name-only contact не согласован;
manual name не требует email, фиктивный адрес недопустим. Create-contact и save
assignment — разные операции: сохранить полученный ID после partial success,
при lost response reconciliation через текущие W06/409, без дублирования.

Контакт не учётная запись/роль и не право на результат. Создание после diarization
не гарантирует изменение уже разрешённых recipients/resend. Переименовать display
snapshot одной записи — не переименовать общий контакт.

Current contact CRUD существует отдельно в .13, без Speaker controls. Будущие
.43/.46/.47/.50 **все blocked** до принятого и реализованного backend-контракта.
Не создаются internal mock repository, persisted local names/drafts, demo form,
contact selection для Speaker или unavailable editor с Skip. Модель и обычный
API-клиент добавляются по готовому контракту, без обязательного repository слоя
на вырост. В будущей production интеграции нет fake success/local fallback;
текущая production версия вообще не содержит эту форму.

## 5. Экспорт и независимая summary

### BR-04: согласованный охват и backend-изменения

Цель — подтверждённые имена во **всех применимых transcript TXT/PDF и summary TXT/PDF**
там, где документ ссылается на соответствующего Speaker. Original WAV не меняется.
Это цель, не существующая возможность server renderer.

| Документ / область | Сейчас | Требование к будущему backend |
|---|---|---|
| Transcript UI | Canonical Speaker N, без frontend alias | Подтверждённая backend-проекция/assignment snapshot, без изменения canonical |
| Transcript TXT | RenderTranscript материализуется с Speaker N | Применить сохранённые имена, поддержать late update и подтверждаемую актуальность |
| Transcript PDF | Из сохранённого transcript text | Та же редакция имён, корректный renderer/cache/invalidation |
| Summary TXT | LLM chunks используют canonical Speaker N | Корректно отразить имена Speaker references, включая позднее назначение, без порчи spoken text/цитат |
| Summary PDF | Из сохранённого summary text | Та же политика и подтверждаемая готовность/актуальность |
| Уже отправленный email | Независимый delivery lifecycle | Изменение письма/resend/новые recipients не входят автоматически в этот запрос |

В будущей версии summary readiness **не gate** назначения; сейчас она не gate текущего transcript. Она может завершиться до/после сохранения
имён либо упасть; transcript/naming остаются доступны. Нельзя вновь ввести mandatory
confirm перед ASR/summary либо автоматически запускать model reprocess ради имени.

Нужно согласовать с backend: модель применения имён в summary (например, устойчивые
структурные Speaker references вместо blind replace); rendering после late rename;
документную доступность/failure/повтор чтения; связь с подтверждённой редакцией назначений
и поведение при concurrent edit/deleted result. «Annotation revision» здесь лишь
концепт freshness, не новое обещанное JSON поле или processing_version.
Готовый PDF со старыми Speaker N нельзя выдавать за именованный/актуальный.
User text безопасно экранируется, не становится Typst/template code; email не
раскрывается как display name. Original/canonical сохраняются неизменными.

FE .31 — базовый текущий download/save/open, честно с Speaker N. .51 **blocked** —
интеграция именованных документов после .50 и утверждённого/реализованного BR-04.
Новый endpoint может не понадобиться: сначала backend определяет контракт существующих
или новых document operations. Frontend не придумывает API и не заменяет server PDF
локальным renderer/подстановкой строк/необъявленной зависимостью.

## 6. BR-05: player сейчас, sample будущего editor

Existing owner-authorized U04 WAV достаточен для полноценного file-based
Play/Pause/seek. .30/.44 остаются current: stream-to-owned-cache до полного файла,
quota/cleanup/owner isolation, явные unavailable/TTL/partial/error. Range/resume/
Content-Length/ранний streaming start не обещаются. Anonymous original TTL семь дней.

R04 intervals + U04 также технически достаточны для bounded sample; API здесь
не отсутствует. Но выбор первой подходящей реплики .45 обслуживает future editor,
поэтому **продуктово отложен** вместе с ним до backend names. Это не блокирует
full player .44 или таймкоды .29 и не создаёт новый fragment endpoint.

Согласованная future семантика сохраняется: хронологически первая достаточно
длинная реплика без overlap; short/overlap → следующая, без ML/ranking/embeddings.
При отсутствии sample manual/contact/default/Skip остаются доступны в будущем
editor. Порог — локальная техническая настройка после выбора future задачи, не API.
Общий audio focus/cache, integer microseconds/real duration/stop/dispose проверяются;
никакого «чистого голоса» из mixed original или отдельного cache на каждого Speaker.

## 7. BR-06 и BR-07: Results, восстановление и lifecycle

Новые API не нужны для Stop/leave dialog, options до Start, workspace→Record,
контекстной навигации/уведомлений или pending uploads Results. До 202 server не знает
непринятый local upload: FE .20/.27 journal показывает его отдельно и повторяет те же
inputs/key. После принятого 202 — polling, 409 не обходится новым ключом автоматически.
После R02 — Results и owned cache/player/journal/notice cleanup текущего этапа, не physical server
destruction и не удаление выбранного пользователем WAV.

Будущий assignments API обязан соблюдать уже существующие ownership/tombstone и
session boundaries. .50 и будущие интеграционные проверки .51 проверяют server enforcement, не только frontend guards.
Workspace W03/W06 access caveats текущего кода остаются отдельным security gate;
новая ручная contact association их не исправляет и не выдаёт получателю доступ.
Current cache/journal не показываются другому owner и не логируются. Future names/
unsaved input также обязаны соблюдать эти границы, но сейчас их stores не создаются.

## 8. Минимальные изменения и блокировки

| Capability | Backend изменение | FE задача / готовность |
|---|---|---|
| Canonical-ready/IDs/intervals | Не нужно, existing R03/R04 | .22/.25/.48 по current contract |
| Original/full player | Не нужно, existing U04 | Current .30/.44, test fixtures существующего API и реальные platform checks |
| Sample редактора | R04/U04 есть; продуктовая зависимость от будущего names flow | Future .45, не gate .44 |
| Read/save/reset manual/contact assignments | Нужно новое согласование/реализация BR-02/03 | Future .43/.46/.47/.50 blocked; mock UI не создавать |
| Historical name snapshot/allowed multiple IDs | Новая server association semantics | Future .47/.50, только с backend evidence |
| Четыре именованных TXT/PDF/freshness | Нужны renderer/storage/contract changes BR-04 | .31 базовый export; .51 blocked |
| Ready notification/Results recovery/Stop guard | Не нужно | .12/.20/.27/.48/.49 |

Нет текущих backend task ID, которые автоматически обещают эти новые capabilities.
Старые TASK-002.14/.15/.16/.25/.30/.37 — source traceability существующего pipeline,
а не договорённость нового assignments API. Контракт согласуется и реализуется
**до** future .43/.46/.47/.50. Текущая .39 проверяет существующий стенд/доступ,
.40/.42 не требуют future names. До backend нет раннего mock milestone .43.
Полный порядок — [UX](FRONTEND_TARGET_UX.ru.md#7-порядок-реализации-и-блокировки)
и [PLAN-FE-001](../plans/PLAN-FE-001.md).

### Будущие проверки (не выполненные tests)

- Read/save → login/restart/другой клиент: те же имена; other owner/job/speaker/contact
  workspace отказ; canonical hash/processing IDs неизменны.
- Manual/default и contact snapshot; rename/delete contact сохраняет historical
  name; один contact на несколько IDs допустим; partial W07/save и safe retry/conflict.
- Summary pending/failed не блокирует операции; Skip не нужен серверу; late responses
  после logout/delete не resurrect state.
- Подтверждённые четыре named TXT/PDF, позднее изменение и freshness/failure policy;
  no blind replace/LLM reprocess, escaping и no arbitrary contact-email disclosure.
- Native Play/Pause/seek/end, TTL/404/503/incomplete download — current .44/.36/.37;
  sample — future .45. Memory/cache evidence отдельно от tiny fixtures.

## 9. Verification и Result

2026-11-02 пересмотрены только frontend planning docs. Backend, оба BACKEND_* и
уже созданный код не менялись этой коррекцией. Требования server persistence,
snapshot/multiple IDs, независимости от summary, late naming и четырёх применимых
именованных exports сохранены как future. Endpoints/JSON/server task ID не выдуманы.
Прежняя стратегия internal mock UI/local names отменена; текущий user flow самодостаточен.

Источники routes/schema/renderer/contact модели выше по-прежнему подтверждают
границу. Docs/hash/DAG/current-vs-future checks — PASS, независимый
[REVIEW-FE-001.01-06](../reviews/REVIEW-FE-001.01-06.md) — reviewed/complete, findings
исправлены и перепроверены; actual evidence — в PLAN/active-plan. Старый .01-05 был review иной редакции и не подменяет новый.
Runtime/API/model/native tests NOT RUN в этой коррекции; future проверки выше —
не отчёт об их выполнении. После review пользователь разрешил current implementation,
но commit/push/merge запрещены.
