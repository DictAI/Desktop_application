---
title: "DictAI: текущий UX на существующем backend и целевой будущий UX"
date: "2026-11-02"
status: researched
scope: current-and-future-product-boundary
frontend_commit: 80959cc10eacabf45fbf461dbe596030e4e7277c
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
related_plan: PLAN-FE-001
implementation_authorized: false
---

# DictAI: текущий и целевой UX

## 1. Статус, границы и источники

Прямое решение владельца 2026-11-02: сейчас нужен минимально необходимый,
**полноценный** frontend по реально существующим API. Это не demo/prototype.
Согласованные решения 2026-10-26 о переименовании не отменены, но реализация
отложена до backend. Этот документ заменяет прежнее разрешение mock-ready
редактора и локальных имён. Frontmatter implementation_authorized=false относится
к этой коррекции документации, не отменяет отдельное поручение исполнять current
план после его независимого review. Commit/push/merge запрещены.

[AGENTS](../../../AGENTS.md), [WORKFLOW](../WORKFLOW.md),
[архитектура](../architecture.md), [active-plan](../active-plan.md),
[PLAN-FE-001](../plans/PLAN-FE-001.md), все 51 [карточка](../tasks/),
[API snapshot](BACKEND_API_CONTRACTS.ru.md), [backend target](BACKEND_TARGET_SCOPE.ru.md),
[будущие backend requests](FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md).
BACKEND_* — неизменённые исторические копии с backend-контекстом ссылок.

СОГЛАСОВАНО — решение продукта; ФАКТ — source-backed API; ТЕХНИЧЕСКОЕ — способ
реализации в выбранной задаче, не новый API; ОТКРЫТО — нужен backend/operator.
У текущего backend нет read/save Speaker names, contact binding или named export.
W06/W07 создают contacts, а не Speaker assignments. R04 canonical содержит исходные
speaker_N/Speaker N и UNKNOWN, их не заменяет frontend-only alias.

### 1.1 Сохранённая реализация

.01/.02 уже accepted владельцем, не переделываются и не проверяются повторно.
.03/.05/.06/.07/.10 имеют implementation review и сохраняются. .04 остаётся
частичной с неполным native runtime smoke. Начатые .18 (два файла), .21 (три файла)
и исследование .22 сохранены, пока без tests/analyze/review этих drafts.
Статусы не сбрасываются из-за изменения требований; этот документ не принимает код.

## 2. Текущий UX: полноценный сценарий без назначения имён

Ниже требуемое поведение current этапа, не утверждение, что существующий UI уже
полностью адаптирован. В исходном frontend ещё есть legacy confirm/LabelSpeakersModal;
их retirement остаётся в текущих .24/.33, без создания нового editor.

1. Login/register; оба режима записи авторизованы JWT, anonymous означает только
   отсутствие workspace, не публичный доступ.
2. Выбрать workspace либо owner-only режим. Workspace contacts редактируются
   отдельно как name/email; они не распознанные люди и не обязательны для записи.
3. До Start выбрать mic/system/language/mixed; immutable snapshot. Для выбранного
   готового WAV параметры валидируются до отправки. Нет универсального MP3/M4A
   transcoding и нет подмены расширения вместо WAV bytes.
4. Start/Pause/Resume с честной поддержкой adapter. Stop либо уход с active/paused
   записью открывает «Завершить запись?»; «Продолжить запись»/Escape/закрытие не
   вызывают stop/upload. «Завершить и отправить» выполняет один finalized WAV →
   preflight → journal → upload, без preview и double-submit.
5. V2 multipart c JWT и неизменным Idempotency-Key; 202 означает durable job, не
   готовый transcript. Отдельны byte progress upload и processing state, без stage/ETA.
6. Waiting опрашивает настоящий status. Валидный R04 200 нужного job показывает
   transcript **с исходными backend labels**. No_speech — успешное пустое состояние,
   UNKNOWN/overlap/timings сохраняются; summary не gate.
7. В другом разделе — ненавязчивое in-app notice с действием открыть результат,
   без forced redirect. После закрытия приложения — Results, без startup redirect.
8. В результате полноценный Play/Pause/seek original WAV, текущие transcript TXT/PDF
   и summary TXT/PDF по готовности. Server bytes не изменяются; нет локального rename,
   контактов в Speaker row, «Сохранить имя», «Назначить» или бессмысленного Skip.
9. Pending uploads восстанавливаются через Results: до 202 те же bytes/options/key,
   после сохранённого 202 только job polling. R02 delete → Results, cleanup owned
   player/polls/cache; logout/session change изолируют данные, user source не удаляется.

### 2.1 Карта текущих экранов и кнопок

| Экран | Доступные действия |
|---|---|
| Login/register | Войти/зарегистрироваться, loading/error/повтор; register не автологин |
| Workspaces/detail | Реальные CRUD, contacts name/email, «Новая запись» с workspace |
| Record | Workspace/owner-only, mic/system/language до Start, Start/Pause/Resume/Stop |
| WAV picker | Выбрать допустимый WAV/options, проверка и отправка; без Stop dialog для готового файла |
| Stop/leave dialog | Только «Продолжить запись» / «Завершить и отправить» |
| Waiting/detail | Реальные queued/running/terminal состояния и безопасный retry чтения |
| Transcript/result | Backend Speaker labels/text/timings, независимая summary, player, реальные downloads/delete |
| Results | Pagination/date filters, Open/Восстановить/Delete, различимые server jobs/local sends |
| Shell | In-app ready notice, guard активной записи; нет naming/draft controls |

Точный route vs вложенное состояние detail — технический выбор в scope existing
GoRouter. Ожидающий может остаться на том же route, где waiting сменяется transcript;
переход не должен заново отправлять WAV. ОС window-close interception/discard/фоновая
запись не добавляются автоматически. Forced logout/401 выполняет безопасный cleanup.

### 2.2 Реальные состояния и ограничения

- Job queued/running/completed/failed/cancelled, transcript pending/ready/failed/
  cancelled, summary pending/ready/failed — разные состояния, не один isDone.
- R03 ready/list done/anonymous ready не заменяют валидный R04 200. 202 может
  содержать terminal failed/cancelled; artifact503 не пустой готовый transcript.
- Upload offline/lost response не доказывает отказ, 409 не обходится новым key.
  Summary/PDF failure не скрывает transcript или готовый TXT.
- Permission/device/mix failure не даёт silent system→mic fallback. WAV проверяется
  по RIFF fmt/data/bytes/rate/channels/битности/длительности/лимитам, а не MIME.
- U04 скачивается авторизованно потоком в полностью завершённый owned файл, не
  1 GiB в RAM. Range/ранний playback не обещаны. Anonymous original TTL семь дней,
  expired/unavailable audio не блокирует чтение transcript.
- HTTP 401/logout/late responses учитывают owner/session/job; raw technical body,
  credentials и audio/transcript не попадают в логи. Contact не право на результат.
- Only real actions: безопасный GET/local retry, восстановление той же upload,
  выбор параметров/устройства/login. Public cancel/reprocess/regenerate API нет.

## 3. Целевой будущий UX: имена после backend

**Не текущая реализация.** Требования сохранены для .43/.45/.46/.47/.50/.51.
Не создавать сейчас editor, sample UI для идентификации, local names store,
mock repository/demo save, fake contact relation или неработающие кнопки. В текущем
приложении нет unavailable формы назначения «пока сервер не готов».

### 3.1 Назначение, контакты и сохранение


Для каждого обнаруженного Speaker ID: исходный **Speaker N**, sample button,
необязательное ручное имя, **Оставить Speaker N**; для workspace дополнительно
выбор существующего контакта и создание нового. Без workspace только manual/default.

- Contact select сохраняет реальный ID **и имя на момент назначения**. Rename/delete
  общего контакта не меняет историческое имя записи; Speaker ID не становится ID человека.
- Один contact на нескольких IDs допустим с предупреждением, без merge сегментов.
- W07 требует name/email. Только имя остаётся manual, фиктивный email не создаётся.
- Создание contact и сохранение связи — разные outcomes. После W07 success/save failure
  использовать полученный ID при retry; lost contact response reconcile через W06/409.
- Выбор не даёт membership/access и не гарантирует включения в уже разрешённые email
  recipients/resend. Редактирование имени записи не переименовывает общий контакт.

**«Сохранить и продолжить»** после подтверждённого серверного save открывает transcript.
**«Пропустить»** сразу открывает transcript с ранее подтверждёнными именами/Speaker N,
не удаляя назначения; форма доступна позднее из результата/Results.

Состояния: loading existing / ready / dirty / saving / saved / offline/error/conflict /
server capability unavailable. Read failure не равен пустым назначениям и не позволяет
их слепо перезаписать. Dirty Skip/Back/уход обязательно предупреждает. **Будущее техническое правило:** остаться либо перейти без отправки, не выдавая
несохранённый ввод за server save. Поведение offline/dirty ввода согласуется с
реальным read/save контрактом; локальное хранилище имён не является его заменой.
Forced security cleanup не показывает draft следующему аккаунту.


### 3.2 Backend — источник сохранённых имён

После утверждения и реализации BR-02/03 реальные read/save/reset и server access
позволят переживать login/restart/другое устройство. Историческое имя contact —
snapshot, не текущее значение общей записи; несколько Speaker IDs одного контакта
не сливают segments. Summary не gate. Canonical не меняется, human labels — отдельная
подтверждённая серверная проекция. Wire/revision/concurrency/limits ещё не назначены.

Прежний обязательный frontend interface+mock (.43) и persistent offline draft (.46)
не являются необходимой архитектурой. Форма хранит незавершённый ввод по реальной
семантике будущего контракта; local persistence не подменяет backend. Тесты этой
будущей функции планируются после контракта, не ради текущей демонстрации UI.

### 3.3 Первый подходящий sample и именованный экспорт

После backend naming редактор может использовать первую подходящую реплику по
canonical intervals: хронологически, положительный interval/достаточная длина,
пропуск short/overlap к следующей. Без ML ranking/embeddings/выделения чистого голоса.
При отсутствии sample доступны manual/contact/default/Skip, не server reprocess.
Microseconds/real duration/end/error ограничивают playback, общий .44 cache/audio
focus переиспользуется без отдельного player на каждого Speaker. Нового fragment
API для этого не требуется; .45 отложена продуктово вместе с редактором, не из-за
отсутствующего original API. Full Play/Pause/seek нужен и остаётся текущим .44.

Все применимые transcript TXT/PDF и summary TXT/PDF должны отражать подтверждённые
имена, включая late rename/freshness. Это future BR-04/.51; нынешние документы
остаются Speaker N байт-в-байт. Blind replace, новый local PDF renderer, ASR/LLM
reprocess и resend не заменяют backend. Summary independent; original неизменен.

### 3.4 Будущая навигация

Только после реализации backend + editor: waiting canonical→назначение;
elsewhere→notice с переходом к назначению; restart→Results→назначение. Save/Skip
ведут к transcript и не открывают форму снова по poll/summary event. Позднее
назначение доступно из результата. Этот future wiring входит в .50, не заставляет
текущую .48 ждать .47. Dirty input guard не отменяет forced security cleanup.

## 4. Матрица согласованных UX-решений

| Решение | Согласованная функция | Текущий этап | Будущий этап / граница |
|---|---|---|---|
| UX-01. | Stop→подтверждение→WAV/upload без preview | Текущий .23/.24/.49 | Сохранено без нового API |
| UX-02. | Параметры до Start | Текущий .18/.23/.24/.49 | Workspace/без него, mic/system/language snapshot |
| UX-03. | Назначение после canonical-ready | Сейчас R04→транскрипт .22/.25/.28/.48 | Будущий editor .43/.46/.50, не ждать summary |
| UX-04. | Sample/manual/contact/default для Speaker | Сейчас только исходные labels; full player .44 | Будущие .43/.45/.46/.47/.50 после backend |
| UX-05. | Без workspace: manual/Speaker N | Сейчас owner-only с backend Speaker N | Future manual/default без фиктивного workspace/email |
| UX-06. | Нет voice profiles/auto identity | Текущие .11/.14/.33 удаляют legacy coupling | Не возвращается и в будущей версии |
| UX-07. | Имена между login/устройствами | Не реализовывать локальное имя/store/mock | Future authoritative backend .50 |
| UX-08. | Summary не gate | Сейчас transcript/player/export по независимой доступности | Future editor/read/save также не ждут summary |
| UX-09. | Waiting→автопоказ готового результата | Сейчас transcript .48 | Future переход к editor подключит .50 |
| UX-10. | Elsewhere→in-app ready notice | Сейчас открыть detail/transcript без forced redirect | Future notice может открыть editor по .50 |
| UX-11. | После restart entry из Results | Сейчас восстановление .20/.25/.27/.48 | Future сохранённые имена загружаются с backend |
| UX-12. | Встроенные Play/Pause/seek | Текущий .44/U04; полноценный player | Sample editor — отдельная будущая .45 |
| UX-13. | Leave active record→warning | Текущий .49 | Сохранено, не editor dirty guard сейчас |
| UX-14. | Pending uploads→Results recovery | Текущие .20/.27, те же inputs/key | Не assignment drafts |
| UX-15. | Delete→Results | Текущий .32/R02 и owned cleanup | Future annotation cleanup сверяется по будущему контракту |
| UX-16. | Workspace→Новая запись | Текущие .12/.23/.49 | Без требования profiles/contacts |
| UX-17. | Причина и только доступные действия | Текущий error/recovery flow | Не придумывать reprocess/cancel/regenerate API |
| UX-18. | Пропустить→transcript | Сейчас нет editor и кнопки Skip; transcript сразу | Future .46/.50, без стирания подтверждённых имён |
| UX-19. | Позднее назначение из результата | Сейчас только повторный просмотр результата | Future .46/.50 и named export .51 |

## 5. Ошибки, восстановление и экспорт

| Ситуация текущего этапа | Поведение |
|---|---|
| Capture/device/permission/invalid WAV | Понятная причина/реальный local retry или корректный input; без fake upload success |
| Lost response/offline upload | Сохранённые inputs/key, Results recovery; не duplicate upload из build |
| 409 | Явный conflict, не новая операция автоматически |
| 429/502/503 | Ограниченное чтение/та же recovery upload по её состоянию; Retry-After необязателен |
| Job/transcript failed/cancelled, session expired | Terminal, остановить ожидание; нет server retry/cancel controls |
| Summary failed/document unavailable | Transcript/доступные exports продолжают работать, не regeneration promise |
| Original unavailable/incomplete | Нет playback partial файла; transcript доступен, GET/local retry |
| R02 success | Results и owned cleanup, не physical destruction/удаление user source |
| 401/logout/другой owner | Login/session cleanup, late ответы не раскрывают старые данные |

Future assignment read/save/conflict и named-document freshness сохраняются в BR,
но не создают текущие error states/forms/stubs. Backend email lifecycle независим:
готовность результата или добавление contact не доказывают доставку/resend/access.

## 6. Влияние на карточки и реализацию

Current .29 исключает .43/name overlay; .44 полноценный player; .48 current notice
и transcript; .31 current server exports. .32/.34/.35–.42 не требуют несуществующих
names repositories/drafts или future E2E. Contacts остаются в .13, новый editor —
future .47. Приоритет .12/.13 повышен до P1: это реальные рабочие workspace сценарии.
Тестовые fakes действующего API/оборудования в .06/.35 сохраняются, runtime mock
будущего бизнеса исключён. Уже выполненное и непроверенные drafts не удаляются.

## 7. Порядок реализации и блокировки

Полный DAG — [PLAN-FE-001](../plans/PLAN-FE-001.md). Current 45 задач: .01–.42,
.44/.48/.49. Future C blocked: .43/.45/.46/.47/.50/.51. Текущая очередь не имеет
transitive prerequisites из future. .39/.40/.42 — текущие external evidence gates,
а не ожидание names API. .04 требует настоящего Keychain runtime evidence; Linux,
разрешённый стенд/PKI/accounts/model quality/staging/cutover не заменяются unit fakes.

## 8. Открытые вопросы

Для текущего этапа: actual test-origin/TLS/accounts/runtime, права workspace и
операторское решение по security, настоящие macOS/Linux/memory/E2E receipts.
Для будущего: read/save/reset wire, validation/concurrency/unknown outcome,
historical contact snapshot и named-document freshness/summary projection.
Backend task ID/owner назначает backend-команда; отдельного раннего diarization
API, live/voice identity/sharing/resend/OS-close interception current этап не требует.

## 9. Verification и Result

Коррекция только planning docs. Уже созданный frontend/backend код, dependencies,
принятые .01/.02 и immutable BACKEND_* сохраняются. Новые задачи не создаются;
49 существующих карточек содержат stage decision, 01/02 неизменны.
Source/schema/renderer/route evidence актуального backend подтверждает отсутствие
assignments и исходные Speaker labels. Docs checks/hash/DAG/links/diff и независимый
[REVIEW-FE-001.01-06](../reviews/REVIEW-FE-001.01-06.md) завершены: PASS, reviewed/complete, F01/F02 independently fixed, открытых findings
нет. Прежний review .01-05 проверял другую стратегию и не подменяет новый. Runtime tests NOT RUN
в этой коррекции; после её review отдельно разрешено продолжение current плана.
