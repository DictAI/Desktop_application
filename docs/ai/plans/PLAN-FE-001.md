---
id: PLAN-FE-001
title: "Полноценный DictAI Flutter на существующем batch backend"
status: in_progress
owner: primary-agent
selected_tasks: ["TASK-FE-001.03", "TASK-FE-001.04", "TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07", "TASK-FE-001.08", "TASK-FE-001.09", "TASK-FE-001.10", "TASK-FE-001.11", "TASK-FE-001.12", "TASK-FE-001.13", "TASK-FE-001.14", "TASK-FE-001.15", "TASK-FE-001.16", "TASK-FE-001.17", "TASK-FE-001.18", "TASK-FE-001.19", "TASK-FE-001.20", "TASK-FE-001.21", "TASK-FE-001.22", "TASK-FE-001.23", "TASK-FE-001.24", "TASK-FE-001.25", "TASK-FE-001.26", "TASK-FE-001.27", "TASK-FE-001.28", "TASK-FE-001.29", "TASK-FE-001.30", "TASK-FE-001.31", "TASK-FE-001.32", "TASK-FE-001.33", "TASK-FE-001.34", "TASK-FE-001.35", "TASK-FE-001.36", "TASK-FE-001.37", "TASK-FE-001.38", "TASK-FE-001.39", "TASK-FE-001.40", "TASK-FE-001.41", "TASK-FE-001.42", "TASK-FE-001.44", "TASK-FE-001.48", "TASK-FE-001.49"]
frontend_commit: 80959cc10eacabf45fbf461dbe596030e4e7277c
requirements_revision: current-backend-2026-11-02
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
---

# PLAN-FE-001: DictAI на существующем batch backend

## Текущее решение и разрешение

2026-11-02 пользователь выбрал минимально необходимую, **полноценную работающую**
версию по реальным backend API. Переименование Speaker/выбор контакта для Speaker,
сохранение назначений и именованные документы — согласованный будущий этап,
не текущая очередь. Временного editor, local names, mock repository, недоступной
формы с Skip или подмены Speaker N frontend-ом сейчас нет.

Сначала выполняется коррекция документации и её независимый review, без изменения
кода/dependencies/backend. После этого пользователь прямо поручил сразу продолжить
все оставшиеся **current** задачи по DAG, с checks и независимым review перед
переходом. Принятые .01/.02 не переоткрываются, готовый код не переделывается.
2026-11-07 пользователь поручил продолжить текущий этап и после проверок и
независимого review отправлять каждую завершённую задачу отдельным коммитом в
`origin/main`. Публикацию выполняет координатор. Приёмка остаётся за владельцем.
Параллельные агенты разрешены при раздельных scopes и одном coordinator.

## Источники и actual state

[AGENTS](../../../AGENTS.md), [WORKFLOW](../WORKFLOW.md),
[архитектурный snapshot](../architecture.md), [активный реестр](../active-plan.md),
[текущий и целевой UX](../research/FRONTEND_TARGET_UX.ru.md),
[будущие backend requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md).
[BACKEND_API_CONTRACTS](../research/BACKEND_API_CONTRACTS.ru.md) и
[BACKEND_TARGET_SCOPE](../research/BACKEND_TARGET_SCOPE.ru.md) — неизменённые копии
backend SHA из frontmatter, не текущая продуктовая очередь. Относительные ссылки
в этих копиях разрешаются в backend-контексте, описанном в architecture.

Наличие backend route/source не равно настроенному стенду/качеству моделей.
Ни один новый assignments/named-export HTTP контракт не найден; workspace contacts
W06–W09 не хранят Speaker ID. R04 canonical сохраняет speaker_N/Speaker N и UNKNOWN,
renderer текущих документов использует эти метки. Новые endpoints не назначаются.

На момент коррекции 2026-11-02: .01/.02 accepted владельцем; .03/.05/.06/.07/.10 имеют code review.
.04 частично реализована: OS storage/migration и tests есть, native runtime smoke
ещё не завершён. Debug/локальный Release builds созданы, но сборка не заменяет smoke.
.18 содержит два непроверенных новых файла; .21 — три, tests/analyze/review NOT RUN.
.22 in_progress после исследования, её код ещё не создан. Их status и файлы сохранены.
Коррекция планирования не подтверждает эти реализации и не сбрасывает работу.

## Goal: текущая полноценная версия

1. Регистрация/вход/JWT, обе формы записи под авторизацией.
2. Реальные workspace и name/email contact CRUD. «Новая запись» переносит workspace
   в Record; контакты не обязательны для записи и не являются speaker assignments.
3. До Start выбираются workspace/без него, mic/system, ru/en/auto/mixed. Поддержанный
   Pause/Resume, Stop и уход требуют подтверждения без случайного stop и без preview.
4. Получить finalized допустимый WAV либо выбрать готовый файл; проверить bytes/
   формат/лимиты; сохранить durable отправку и отправить V2 multipart один раз.
5. HTTP 202 сохранить как accepted job, не готовый transcript. Восстановление
   потерянного ответа/перезапуска использует те же inputs/key, после 202 — polling.
6. Получить canonical R04 нужного job и показать **исходные backend Speaker labels**,
   текст/timings/overlap/UNKNOWN/no_speech. Нет именования или кнопок его имитации.
7. Transcript, summary и documents независимы. Ожидающий видит готовый transcript;
   в другом разделе — in-app notice без redirect; после restart — Results.
8. Полноценный встроенный Play/Pause/seek по original WAV, реальные доступные
   transcript TXT/PDF, summary TXT/PDF и original WAV, без изменения server bytes.
9. R02 delete возвращает в Results; polls/player/cache/session cleanup и logout
   не раскрывают данные следующему account и не удаляют пользовательский source.

Нет voice library/automatic identity, legacy confirm, live/chat/sharing, server
cancel/reprocess/regenerate или новых account settings/admin экранов. Не добавлять
универсальный framework/domain/repository слой, новый transport stack или архитектуру
на гипотетические изменения. Узкие API/DTO/ports допускаются при конкретной нужде
действующего контракта, bounded IO и тестирования; сохраняются Riverpod/GoRouter/Dio.

## Текущий и будущий этапы

- **Current:** 45 задач — .01–.42, .44, .48, .49. Они включают уже выполненное и
  внешние host/стенд/quality gates; выбор не делает все задачи ready.
- **Future:** .43/.45/.46/.47/.50/.51, category C, blocked. Требования сохраняются,
  implementation исключена из selected_tasks до backend evidence и нового выбора.
- **A:** существующий wire/локальная поддержка/verification gates текущей версии.
- **B:** текущие UI/state/recovery по реальным API. Test fakes существующего wire/
  оборудования разрешены; runtime mock будущего бизнеса не разрешён.
- **C:** продуктовая функция будущего этапа ждёт backend. У .45 R04/U04 уже есть,
  но отдельный sample нужен будущему editor, а общий player остаётся .44 сейчас.

Категории: A=27, B=18, C=6.
Формальные статусы на момент коррекции 2026-11-02: accepted=2, blocked=10, draft=31, in_progress=3, review=5. Текущий статус — в таблице Tasks и карточках.

### Смешанные задачи сохранены в текущем этапе

- .29 показывает canonical напрямую, её зависимость от .43 удалена.
- .44 — полный реальный player/cache; будущая sample/editor инфраструктура не строится.
- .48 — ready→transcript/notice/Results. Только будущий editor entry перенесён в .50;
  зависимость .47 удалена. .44 добавлена для порядка shared detail writers.
- .31 — все текущие документы/WAV, будущий named export только .51.
- .32/.34 — cleanup/isolation действующих journal/jobs/cache/player/notices;
  будущие repositories/drafts/editors удалены из scope.
- .35–.42 — tests/hosts/real E2E/candidate/приёмка текущей версии, без имён и
  без .50/.51 prerequisites. .39/.40/.42 остаются blocked по настоящим внешним
  условиям, category A, не из-за отсутствующего names API.
- .47 — только будущая связь Speaker↔contact; полезный самостоятельный contact CRUD
  уже остаётся .13. .45 не блокирует .44 или таймкоды .29.

## Аудит каждой задачи

«Текущий API» здесь означает source-backed контракт/локальную работу, а не live
стенд. Необходимость, mock/временная логика, сокращение scope и влияние на уже
написанное зафиксированы для всех ID. Details/criteria — в карточках.

| ID | Этап / backend опора | Решение по scope и сохранности |
|---|---|---|
| [TASK-FE-001.01](../tasks/TASK-FE-001.01.md) | current / текущий API или локальная работа | Принята. Toolchain сохраняется без повторной реализации/проверок. |
| [TASK-FE-001.02](../tasks/TASK-FE-001.02.md) | current / текущий API или локальная работа | Принята. Секреты/история не переоткрываются; прежний внешний revoke gate сохраняется. |
| [TASK-FE-001.03](../tasks/TASK-FE-001.03.md) | current / текущий API или локальная работа | Сохранить реализацию безопасных логов; запрет sensitive data не требует реализации назначений. |
| [TASK-FE-001.04](../tasks/TASK-FE-001.04.md) | current / текущий API или локальная работа | Сохранить OS storage/migration и проверки; native runtime smoke ещё не завершён. |
| [TASK-FE-001.05](../tasks/TASK-FE-001.05.md) | current / текущий API или локальная работа | Сохранить gateway/TLS/origin/timeouts; только существующие backend API. |
| [TASK-FE-001.06](../tasks/TASK-FE-001.06.md) | current / текущий API или локальная работа | Сохранить unit/widget test fakes существующих API/оборудования; это не runtime mock будущей бизнес-функции. |
| [TASK-FE-001.07](../tasks/TASK-FE-001.07.md) | current / текущий API или локальная работа | Сохранить error mapper; не добавлять ошибки несуществующего assignments API. |
| [TASK-FE-001.08](../tasks/TASK-FE-001.08.md) | current / текущий API или локальная работа | Нужна: существующие A01–A05, без нового account settings экрана. |
| [TASK-FE-001.09](../tasks/TASK-FE-001.09.md) | current / текущий API или локальная работа | Нужна: JWT/session/navigation; убрать обязательства editor/draft guards текущего этапа. |
| [TASK-FE-001.10](../tasks/TASK-FE-001.10.md) | current / текущий API или локальная работа | Сохранить reviewed W01–W09; local voiceProfileId compatibility удалится в .11, именование не добавлять. |
| [TASK-FE-001.11](../tasks/TASK-FE-001.11.md) | current / текущий API или локальная работа | Нужна: удалить voice coupling, сохранить реальные contacts; не добавлять assignment UI. |
| [TASK-FE-001.12](../tasks/TASK-FE-001.12.md) | current / текущий API или локальная работа | Нужна: workspace CRUD и Новая запись; P1, без speaker naming. |
| [TASK-FE-001.13](../tasks/TASK-FE-001.13.md) | current / текущий API или локальная работа | Нужна: W06–W09 name/email CRUD; P1, без привязки к Speaker. |
| [TASK-FE-001.14](../tasks/TASK-FE-001.14.md) | current / текущий API или локальная работа | Нужна: удалить retired voice API после consumers, не заменять заглушкой. |
| [TASK-FE-001.15](../tasks/TASK-FE-001.15.md) | current / текущий API или локальная работа | Нужна: реальный WAV capture/lifecycle; узкий hardware seam оправдан тестированием. |
| [TASK-FE-001.16](../tasks/TASK-FE-001.16.md) | current / текущий API или локальная работа | Нужна: bounded macOS capture; native/память проверять на настоящем host. |
| [TASK-FE-001.17](../tasks/TASK-FE-001.17.md) | current / текущий API или локальная работа | Нужна: Linux capture/process lifecycle; отсутствие Linux host не заменять fake smoke. |
| [TASK-FE-001.18](../tasks/TASK-FE-001.18.md) | current / текущий API или локальная работа | Нужна: WAV preflight и immutable options по U01/U02; сохранены два непроверенных начатых файла. |
| [TASK-FE-001.19](../tasks/TASK-FE-001.19.md) | current / текущий API или локальная работа | Нужна: действующие V2 multipart/202/idempotency; без автоматического reprocess. |
| [TASK-FE-001.20](../tasks/TASK-FE-001.20.md) | current / текущий API или локальная работа | Нужна: durable upload recovery; убрать assignment drafts и обязательство нового пакета. |
| [TASK-FE-001.21](../tasks/TASK-FE-001.21.md) | current / текущий API или локальная работа | Нужна: действующие R03/U03; сохранены три непроверенных начатых файла. |
| [TASK-FE-001.22](../tasks/TASK-FE-001.22.md) | current / текущий API или локальная работа | Нужна: R04 200/202 и canonical IDs/labels; убрать requirement модели назначений. |
| [TASK-FE-001.23](../tasks/TASK-FE-001.23.md) | current / текущий API или локальная работа | Нужна: ordinary WAV/V2 pipeline, без preview/editor/profiles. |
| [TASK-FE-001.24](../tasks/TASK-FE-001.24.md) | current / текущий API или локальная работа | Нужна: owner-only anonymous V2, сразу к результату без confirm/назначений. |
| [TASK-FE-001.25](../tasks/TASK-FE-001.25.md) | current / текущий API или локальная работа | Нужна: реальное polling/restart, canonical и summary независимо; без editor intent. |
| [TASK-FE-001.26](../tasks/TASK-FE-001.26.md) | current / текущий API или локальная работа | Нужна: серверный Results/pagination, без нового workspace filter API. |
| [TASK-FE-001.27](../tasks/TASK-FE-001.27.md) | current / текущий API или локальная работа | Нужна: библиотека/пагинация/незавершённые отправки; нет Назначить участников. |
| [TASK-FE-001.28](../tasks/TASK-FE-001.28.md) | current / текущий API или локальная работа | Нужна: единый detail с canonical/summary/docs; нет формы или unavailable заглушки назначения. |
| [TASK-FE-001.29](../tasks/TASK-FE-001.29.md) | current / текущий API или локальная работа | Нужна: исходные Speaker ID/labels, UNKNOWN/timings; убрать .43 и имя-overlay. |
| [TASK-FE-001.30](../tasks/TASK-FE-001.30.md) | current / текущий API или локальная работа | Нужна: авторизованные реальные документы/original; нет локальной замены имён. |
| [TASK-FE-001.31](../tasks/TASK-FE-001.31.md) | current / текущий API или локальная работа | Нужна: все существующие TXT/PDF/WAV, сохранить server bytes; future named export в .51. |
| [TASK-FE-001.32](../tasks/TASK-FE-001.32.md) | current / текущий API или локальная работа | Нужна: R02→Results и cleanup реального player/cache/polls; не создавать cleanup несуществующих drafts. |
| [TASK-FE-001.33](../tasks/TASK-FE-001.33.md) | current / текущий API или локальная работа | Нужна: удалить legacy/profile/confirm consumers; будущие assignments не создавать. |
| [TASK-FE-001.34](../tasks/TASK-FE-001.34.md) | current / текущий API или локальная работа | Нужна: isolation существующих session/jobs/audio; убрать repository/mock/drafts будущих имён. |
| [TASK-FE-001.35](../tasks/TASK-FE-001.35.md) | current / текущий API или локальная работа | Нужна: regression текущих сценариев с test fixtures действующих API; без demo naming suite. |
| [TASK-FE-001.36](../tasks/TASK-FE-001.36.md) | current / текущий API или локальная работа | Нужна: реальные macOS Debug/Release/capture/player; naming smoke не обязательство текущего этапа. |
| [TASK-FE-001.37](../tasks/TASK-FE-001.37.md) | current / текущий API или локальная работа | Нужна: реальные Linux audio/storage/export; host gate не относится к будущему naming. |
| [TASK-FE-001.38](../tasks/TASK-FE-001.38.md) | current / текущий API или локальная работа | Нужна: opt-in harness существующих HTTP; не добавлять будущие wire probes/новый test framework. |
| [TASK-FE-001.39](../tasks/TASK-FE-001.39.md) | current / внешний evidence gate | Текущий внешний gate: test-origin/accounts/PKI/runtime/access, а не отсутствие будущего names API. |
| [TASK-FE-001.40](../tasks/TASK-FE-001.40.md) | current / внешний evidence gate | Нужна: real E2E текущего сценария; убрать .50/.51 prerequisites и проверки назначений. |
| [TASK-FE-001.41](../tasks/TASK-FE-001.41.md) | current / текущий API или локальная работа | Нужна: candidate/checklist полноценной текущей версии, без mock-only release. |
| [TASK-FE-001.42](../tasks/TASK-FE-001.42.md) | current / внешний evidence gate | Нужна: приёмка текущей версии по real E2E/security/hosts; future naming не release gate. |
| [TASK-FE-001.43](../tasks/TASK-FE-001.43.md) | future / ждёт backend | Будущее: модель только после утверждённого реализованного backend. Обязательный mock/repository prototype исключён. |
| [TASK-FE-001.44](../tasks/TASK-FE-001.44.md) | current / текущий API или локальная работа | Нужна сейчас: полноценный Play/Pause/seek/cache по U04; не строить sample/editor seams заранее. |
| [TASK-FE-001.45](../tasks/TASK-FE-001.45.md) | future / ждёт backend | Будущее: отдельный выбор характерной реплики обслуживает редактор .46. Полный player и таймкоды остаются .44/.29. |
| [TASK-FE-001.46](../tasks/TASK-FE-001.46.md) | future / ждёт backend | Будущее: реальный editor/Skip только с backend. Сейчас нет формы, локальных имён или mock save. |
| [TASK-FE-001.47](../tasks/TASK-FE-001.47.md) | future / ждёт backend | Будущее: Speaker↔contact требует нового контракта; самостоятельный contact CRUD остаётся текущей .13. |
| [TASK-FE-001.48](../tasks/TASK-FE-001.48.md) | current / текущий API или локальная работа | Смешанная: сейчас готовность→транскрипт/notice/Results; переход к editor перенесён в .50. Не блокируется целиком. |
| [TASK-FE-001.49](../tasks/TASK-FE-001.49.md) | current / текущий API или локальная работа | Нужна сейчас: Stop/leave confirmation и один WAV/upload, без preview/редактора. |
| [TASK-FE-001.50](../tasks/TASK-FE-001.50.md) | future / ждёт backend | Будущее: реальный read/save/reset/contact snapshot и подключение editor entry после backend. |
| [TASK-FE-001.51](../tasks/TASK-FE-001.51.md) | future / ждёт backend | Будущее: именованные TXT/PDF после backend; существующий raw export остаётся .31. |

## Task graph

`<-` означает prerequisite. Переход внутри выбранного current плана после checks/
независимого review разрешён поручением пользователя; formal accepted ставит
владелец. У future дополнительно обязательны backend approval/implementation и
новый выбор — готовый predecessor не разрешает future implementation автоматически.

```text
TASK-FE-001.01 <- none
TASK-FE-001.02 <- none
TASK-FE-001.03 <- TASK-FE-001.01
TASK-FE-001.04 <- TASK-FE-001.01
TASK-FE-001.05 <- TASK-FE-001.01, TASK-FE-001.02, TASK-FE-001.03
TASK-FE-001.06 <- TASK-FE-001.01
TASK-FE-001.07 <- TASK-FE-001.03, TASK-FE-001.05, TASK-FE-001.06
TASK-FE-001.08 <- TASK-FE-001.04, TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.09 <- TASK-FE-001.08
TASK-FE-001.10 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.11 <- TASK-FE-001.09, TASK-FE-001.10
TASK-FE-001.12 <- TASK-FE-001.11
TASK-FE-001.13 <- TASK-FE-001.12
TASK-FE-001.14 <- TASK-FE-001.11
TASK-FE-001.15 <- TASK-FE-001.04, TASK-FE-001.06, TASK-FE-001.07, TASK-FE-001.18
TASK-FE-001.16 <- TASK-FE-001.15
TASK-FE-001.17 <- TASK-FE-001.15
TASK-FE-001.18 <- TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.19 <- TASK-FE-001.05, TASK-FE-001.07, TASK-FE-001.18
TASK-FE-001.20 <- TASK-FE-001.04, TASK-FE-001.19
TASK-FE-001.21 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.22 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07, TASK-FE-001.21
TASK-FE-001.23 <- TASK-FE-001.11, TASK-FE-001.13, TASK-FE-001.14, TASK-FE-001.15, TASK-FE-001.16, TASK-FE-001.17, TASK-FE-001.18, TASK-FE-001.19, TASK-FE-001.20, TASK-FE-001.25
TASK-FE-001.24 <- TASK-FE-001.23
TASK-FE-001.25 <- TASK-FE-001.09, TASK-FE-001.14, TASK-FE-001.20, TASK-FE-001.21, TASK-FE-001.22
TASK-FE-001.26 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.27 <- TASK-FE-001.25, TASK-FE-001.26
TASK-FE-001.28 <- TASK-FE-001.09, TASK-FE-001.22, TASK-FE-001.24, TASK-FE-001.25, TASK-FE-001.27, TASK-FE-001.30, TASK-FE-001.49
TASK-FE-001.29 <- TASK-FE-001.22, TASK-FE-001.28
TASK-FE-001.30 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07, TASK-FE-001.18
TASK-FE-001.31 <- TASK-FE-001.29, TASK-FE-001.30, TASK-FE-001.48
TASK-FE-001.32 <- TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.31, TASK-FE-001.48
TASK-FE-001.33 <- TASK-FE-001.14, TASK-FE-001.23, TASK-FE-001.24, TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.31, TASK-FE-001.32
TASK-FE-001.34 <- TASK-FE-001.09, TASK-FE-001.20, TASK-FE-001.25, TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.32, TASK-FE-001.33
TASK-FE-001.35 <- TASK-FE-001.12, TASK-FE-001.13, TASK-FE-001.23, TASK-FE-001.24, TASK-FE-001.29, TASK-FE-001.31, TASK-FE-001.32, TASK-FE-001.34, TASK-FE-001.48, TASK-FE-001.49
TASK-FE-001.36 <- TASK-FE-001.16, TASK-FE-001.33, TASK-FE-001.35
TASK-FE-001.37 <- TASK-FE-001.17, TASK-FE-001.33, TASK-FE-001.35
TASK-FE-001.38 <- TASK-FE-001.19, TASK-FE-001.21, TASK-FE-001.22, TASK-FE-001.26, TASK-FE-001.30, TASK-FE-001.34, TASK-FE-001.35
TASK-FE-001.39 <- TASK-FE-001.38
TASK-FE-001.40 <- TASK-FE-001.36, TASK-FE-001.37, TASK-FE-001.39
TASK-FE-001.41 <- TASK-FE-001.33, TASK-FE-001.35, TASK-FE-001.36, TASK-FE-001.37, TASK-FE-001.38
TASK-FE-001.42 <- TASK-FE-001.40, TASK-FE-001.41
TASK-FE-001.43 <- TASK-FE-001.06, TASK-FE-001.07, TASK-FE-001.22
TASK-FE-001.44 <- TASK-FE-001.29, TASK-FE-001.30
TASK-FE-001.45 <- TASK-FE-001.22, TASK-FE-001.44
TASK-FE-001.46 <- TASK-FE-001.43, TASK-FE-001.45, TASK-FE-001.29, TASK-FE-001.34
TASK-FE-001.47 <- TASK-FE-001.46, TASK-FE-001.13
TASK-FE-001.48 <- TASK-FE-001.25, TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.44
TASK-FE-001.49 <- TASK-FE-001.24, TASK-FE-001.12
TASK-FE-001.50 <- TASK-FE-001.43, TASK-FE-001.47, TASK-FE-001.48, TASK-FE-001.34
TASK-FE-001.51 <- TASK-FE-001.31, TASK-FE-001.50
```

## Tasks

Точные пути и planned_paths — в YAML карточек, не directory glob. Status сохранён;
только будущие draft .43/.45/.46/.47 переведены в blocked по прямому решению продукта.

| ID | Задача | Категория | Приоритет | Статус | Зависимости | Owner | Scope |
|---|---|---|---|---|---|---|---|
| [TASK-FE-001.01](../tasks/TASK-FE-001.01.md) | Согласовать и воспроизвести Flutter/Dart toolchain | A | P0 | accepted | none | primary-agent | Точные пути в карточке |
| [TASK-FE-001.02](../tasks/TASK-FE-001.02.md) | Удалить значения секретов из tracked-конфигурации | A | P0 | accepted | none | primary-agent | Точные пути в карточке |
| [TASK-FE-001.03](../tasks/TASK-FE-001.03.md) | Ограничить HTTP-логирование и редактировать чувствительные данные | A | P0 | review | 01 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.04](../tasks/TASK-FE-001.04.md) | Перевести session storage на защищённое хранилище | A | P0 | review | 01 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.05](../tasks/TASK-FE-001.05.md) | Настроить явную конфигурацию gateway и сетевых политик | A | P0 | review | 01, 02, 03 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.06](../tasks/TASK-FE-001.06.md) | Подготовить тестовую основу без сети и аппаратуры | A | P1 | review | 01 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.07](../tasks/TASK-FE-001.07.md) | Унифицировать безопасную обработку HTTP и транспортных ошибок | A | P1 | review | 03, 05, 06 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.08](../tasks/TASK-FE-001.08.md) | Сверить auth API с действующим wire contract | A | P1 | review | 04, 05, 06, 07 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.09](../tasks/TASK-FE-001.09.md) | Согласовать auth UI, JWT lifecycle и навигацию | B | P1 | review | 08 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.10](../tasks/TASK-FE-001.10.md) | Закрепить workspace/contact DTO и CRUD-контракты | A | P1 | review | 05, 06, 07 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.11](../tasks/TASK-FE-001.11.md) | Убрать voice-profile coupling из workspace и старта записи | B | P1 | review | 09, 10 | /root/results_contracts | Точные пути в карточке |
| [TASK-FE-001.12](../tasks/TASK-FE-001.12.md) | Завершить workspace UX создания и переименования | B | P1 | review | 11 | /root/workspace12_resume | Точные пути в карточке |
| [TASK-FE-001.13](../tasks/TASK-FE-001.13.md) | Завершить contact CRUD и пояснить email recipients | B | P1 | review | 12 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.14](../tasks/TASK-FE-001.14.md) | Удалить неиспользуемый voice-profile API и wiring | A | P1 | review | 11 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.15](../tasks/TASK-FE-001.15.md) | Выделить общий lifecycle микрофонной WAV-записи | A | P1 | review | 04, 06, 07, 18 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.16](../tasks/TASK-FE-001.16.md) | Сделать macOS system+microphone capture совместимым и ограниченным по памяти | A | P1 | review | 15 | /root/finish_native_teardown | Точные пути в карточке |
| [TASK-FE-001.17](../tasks/TASK-FE-001.17.md) | Сделать Linux system+microphone capture предсказуемым | A | P1 | review | 15 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.18](../tasks/TASK-FE-001.18.md) | Проверять WAV/лимиты и формировать upload options | A | P1 | review | 06, 07 | /root/record_data | Точные пути в карточке |
| [TASK-FE-001.19](../tasks/TASK-FE-001.19.md) | Добавить V2 multipart upload client и accepted DTO | A | P1 | review | 05, 07, 18 | /root/record_data | Точные пути в карточке |
| [TASK-FE-001.20](../tasks/TASK-FE-001.20.md) | Сохранить upload identity и job references для восстановления | B | P1 | review | 04, 19 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.21](../tasks/TASK-FE-001.21.md) | Добавить job status и anonymous session V2 контракты | A | P1 | review | 05, 06, 07 | /root/results_contracts | Точные пути в карточке |
| [TASK-FE-001.22](../tasks/TASK-FE-001.22.md) | Добавить canonical transcript DTO и 200/202 result API | A | P1 | review | 05, 06, 07, 21 | /root/results_contracts | Точные пути в карточке |
| [TASK-FE-001.23](../tasks/TASK-FE-001.23.md) | Перевести ordinary record/upload UX на V2 | B | P1 | review | 11, 13, 14, 15, 16, 17, 18, 19, 20, 25 | /root/ordinary_v2 | Точные пути в карточке |
| [TASK-FE-001.24](../tasks/TASK-FE-001.24.md) | Заменить anonymous confirm на owner-only V2 batch UX | B | P1 | draft | 23 | unassigned | Точные пути в карточке |
| [TASK-FE-001.25](../tasks/TASK-FE-001.25.md) | Организовать lifecycle polling и восстановление accepted jobs | B | P1 | review | 09, 14, 20, 21, 22 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.26](../tasks/TASK-FE-001.26.md) | Закрепить V2 results list и pagination data | A | P1 | review | 05, 06, 07 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.27](../tasks/TASK-FE-001.27.md) | Адаптировать библиотеку результатов и фильтры | B | P1 | draft | 25, 26 | unassigned | Точные пути в карточке |
| [TASK-FE-001.28](../tasks/TASK-FE-001.28.md) | Добавить result detail route с независимыми состояниями | B | P1 | draft | 09, 22, 24, 25, 27, 30, 49 | unassigned | Точные пути в карточке |
| [TASK-FE-001.29](../tasks/TASK-FE-001.29.md) | Показать canonical transcript с исходными Speaker ID/labels | B | P1 | draft | 22, 28 | unassigned | Точные пути в карточке |
| [TASK-FE-001.30](../tasks/TASK-FE-001.30.md) | Добавить авторизованный document/original download client | A | P1 | review | 05, 06, 07, 18 | primary-agent | Точные пути в карточке |
| [TASK-FE-001.31](../tasks/TASK-FE-001.31.md) | Сделать экспорт TXT/PDF/WAV и локальное открытие кроссплатформенными | B | P1 | draft | 29, 30, 48 | unassigned | Точные пути в карточке |
| [TASK-FE-001.32](../tasks/TASK-FE-001.32.md) | Согласовать delete/tombstone и очистку локального состояния | B | P1 | draft | 27, 28, 31, 48 | unassigned | Точные пути в карточке |
| [TASK-FE-001.33](../tasks/TASK-FE-001.33.md) | Удалить остатки legacy speech flow после переключения consumers | A | P1 | draft | 14, 23, 24, 27, 28, 31, 32 | unassigned | Точные пути в карточке |
| [TASK-FE-001.34](../tasks/TASK-FE-001.34.md) | Проверить и завершить account isolation и cleanup всего batch flow | B | P0 | draft | 09, 20, 25, 27, 28, 32, 33 | unassigned | Точные пути в карточке |
| [TASK-FE-001.35](../tasks/TASK-FE-001.35.md) | Покрыть batch-пути unit/widget regression suite | B | P1 | draft | 12, 13, 23, 24, 29, 31, 32, 34, 48, 49 | unassigned | Точные пути в карточке |
| [TASK-FE-001.36](../tasks/TASK-FE-001.36.md) | Проверить macOS Debug/Release, permissions, capture и файлы | A | P1 | draft | 16, 33, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.37](../tasks/TASK-FE-001.37.md) | Проверить Linux build, аудио prerequisites и export | A | P1 | draft | 17, 33, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.38](../tasks/TASK-FE-001.38.md) | Подготовить opt-in интеграционный harness и требования к стенду | B | P1 | draft | 19, 21, 22, 26, 30, 34, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.39](../tasks/TASK-FE-001.39.md) | Подтвердить тестовый backend и закрыть контрактные вопросы доступа | A | P0 | blocked | 38 | unassigned | Точные пути в карточке |
| [TASK-FE-001.40](../tasks/TASK-FE-001.40.md) | Выполнить реальную batch-интеграцию на подготовленном стенде | A | P1 | blocked | 36, 37, 39 | unassigned | Точные пути в карточке |
| [TASK-FE-001.41](../tasks/TASK-FE-001.41.md) | Подготовить локальный batch release candidate и инструкцию выпуска | A | P1 | draft | 33, 35, 36, 37, 38 | unassigned | Точные пути в карточке |
| [TASK-FE-001.42](../tasks/TASK-FE-001.42.md) | Зафиксировать готовность frontend-интеграции к batch-релизу | A | P0 | blocked | 40, 41 | unassigned | Точные пути в карточке |
| [TASK-FE-001.43](../tasks/TASK-FE-001.43.md) | Добавить модель назначений после готовности backend-контракта | C | P1 | blocked | 06, 07, 22 | unassigned | Точные пути в карточке |
| [TASK-FE-001.44](../tasks/TASK-FE-001.44.md) | Добавить встроенный аудиоплеер и owned cache original WAV | A | P1 | draft | 29, 30 | unassigned | Точные пути в карточке |
| [TASK-FE-001.45](../tasks/TASK-FE-001.45.md) | Воспроизводить первый подходящий фрагмент Speaker из canonical | C | P1 | blocked | 22, 44 | unassigned | Точные пути в карточке |
| [TASK-FE-001.46](../tasks/TASK-FE-001.46.md) | Создать редактор назначений после готовности backend | C | P1 | blocked | 43, 45, 29, 34 | unassigned | Точные пути в карточке |
| [TASK-FE-001.47](../tasks/TASK-FE-001.47.md) | Добавить выбор и создание workspace-контакта при назначении | C | P1 | blocked | 46, 13 | unassigned | Точные пути в карточке |
| [TASK-FE-001.48](../tasks/TASK-FE-001.48.md) | Связать готовность транскрипта с уведомлениями и навигацией | B | P1 | draft | 25, 27, 28, 44 | unassigned | Точные пути в карточке |
| [TASK-FE-001.49](../tasks/TASK-FE-001.49.md) | Подтвердить Stop и защитить уход с активной записи | B | P1 | draft | 24, 12 | unassigned | Точные пути в карточке |
| [TASK-FE-001.50](../tasks/TASK-FE-001.50.md) | Подключить будущий backend API назначений имён | C | P1 | blocked | 43, 47, 48, 34 | unassigned | Точные пути в карточке |
| [TASK-FE-001.51](../tasks/TASK-FE-001.51.md) | Интегрировать экспорт TXT/PDF с сохранёнными именами | C | P1 | blocked | 31, 50 | unassigned | Точные пути в карточке |

## Порядок выполнения и координация

Сначала завершить .04 по реальному OS evidence. Независимо доступны завершение
.18/.21/.22 и .26/.30; .10 уже reviewed. После .04 — .08→.09, затем .11→.12→.13,
.14, capture .15→.16/.17. .18→.19→.20, затем .25→.23→.24→.49→.28→.29→.44→.48
→.31→.32→.33→.34, затем .35–.38. Порядок определяется DAG, не номером.
.39 требует разрешённого стенда/оператора; .40 — .36/.37/.39; .42 — .40/.41.

Подготовка плана не повторяет проверку .01/.02 и не закрывает current blockers.
На время коррекции implementation-агенты остановлены. После независимого review
документации пользователь разрешил сразу продолжить current задачи без нового
запроса. Передача writer явно отражается в active-plan и карточке.

- Coordinator один пишет active-plan/decisions/таблицу, резервирует review ID.
- Record: .11→.12→.23→.24→.49→.28. Router: .09→.12→.49→.28→.48→.34.
- Providers: .05→.09→.14→.25→.23→.24→.28→.48→.33→.34.
- Detail: .27→.28→.29→.44→.48→.31→.32→.33→.34.
- Native entitlements .04→.15→.16; RunnerTests .16→.36, shared harness .38→.40.
- Future shared writes идут после current .34: .46→.47→.50→.51. Это порядок
  предотвращения конфликтов, а не разрешение строить будущие функции сейчас.
- Параллельны только независимые exact paths. Reviewer — другой агент, source
  не исправляет, пишет только assigned report. При конфликте scopes запись стоп.

## API, блокировки и границы тестов

Current опирается на A01–A05, W01–W09, U01–U04, R01–R05. U05 grant issuance
необходимости для обычного batch нет, discovery/reprocess/cancel не добавляются.
Не все маршруты доступны без V2 gate/workers/MinIO/versioning/models/LLM/Typst/SMTP/
TLS/БД/NATS и разрешённого окружения. Frontend не чинит backend и не принимает
model quality по визуальному впечатлению. Workspace W03/W06 access/security caveats
сохраняются; они не решаются client-side contacts или будущими именами.

Current blockers: .04 native runtime, .39 isolated test-origin/accounts/PKI/runtime/
access decision, .40 real E2E/platform/quality/staging, .42 итоговые evidence/security/
cutover и приёмка. Отсутствие Linux host отдельно фиксируется в .17/.37/.36 matrix;
будущие backend модели/слои не используются как обход host ограничения.

Backend TASK-002.17/.24/.31 quality/staging/production evidence и .29 numerical gates
сохраняются как реальные release-bound ограничения, не новые API. GPU/live/cleanup
расширения не становятся обязательными пользовательскими функциями. Future BR-02/03
нужны read/save/reset, owner/job/Speaker/contact checks, historical snapshot,
concurrency/unknown outcome; BR-04 — names/freshness применимых TXT/PDF. Новых task ID/
endpoints/JSON frontend не назначает. Эти requests не gate current .39/.40/.42.

Разрешены isolated unit/widget fakes **существующих** контрактов, timers/process/
recorder и synthetic fixtures. Они проверяют текущую логику, не являются runtime
business repositories и не заменяют реальные host/model/E2E checks. Production
получает настоящие данные. Нет обязательного будущего assignments mock/fixture/
demo editor или отключённой формы «пока сервер не готов».

## Проверка коррекции документации

Baseline до коррекции: /tmp/dictai-plan-current-backend-20261102/baseline.json,
198 frontend и 589 backend-файлов; все созданные implementation drafts включены.
Код, test sources, platform/config/dependencies, .01/.02, HEAD/index и BACKEND_* должны
остаться побайтово прежними. Меняются только этот plan, затронутые карточки,
UX/BR, decisions/active-plan и новый независимый report. Новых task IDs нет.

Нужны checks YAML/51 IDs, stage/category/status/table/card/DAG, отсутствие циклов/
shared unordered writers/current→future prerequisite, paths/links/source anchors,
полный tracked/untracked diff, secrets/conflict patterns и hash baseline.
Flutter/backend/native tests в коррекции NOT RUN, поскольку implementation запрещена;
исторические successful builds/tests не переносятся на новые непроверенные drafts.
Новый [REVIEW-FE-001.01-06](../reviews/REVIEW-FE-001.01-06.md) — назначенный независимый
review этой редакции завершён: reviewed/complete, F01/F02 fixed with evidence,
открытых actionable findings нет. Checker PASS: 51 IDs/45current/6future, 726 links,
5 anchors, 14 source refs, cycles/current→future/unordered writers=0. SHA-256 к
baseline: 54 docs изменены + report добавлен, остальные 144 FE/589 BE неизменны.
`git diff --check` PASS; .01/.02/source/drafts/deps/HEAD/index/BACKEND_* сохранены.
Exact commands/cwd/environment и ограничения — в active-plan. Review не означает accepted и не разрешает Git публикацию.

## Сохранённая история

[REVIEW-FE-001.01-05](../reviews/REVIEW-FE-001.01-05.md) проверял прежний target/mock
план от 2026-10-26. Его выводы не подменяют новый review. Implementation reports
.03/.04/.05/.06/.07/.10 относятся к своим diff, .04-03 ещё partial. Accepted .01/.02
и их evidence сохранены. ADR-FE-008 заменяет текущую стратегию ADR-FE-007, сохраняя
согласованные будущие requirements и backend/source snapshots.

## Продолжение реализации — 2026-11-03

.04 native gate пройден: Debug/Release 24/24 фаз OS Keychain и подписи PASS,
14 unit tests/analyze/format/plist PASS; передана на независимый review .04-04.
.18 и .21 завершают checks/review, .22 продолжится после review .21.
Это продолжение разрешённого current scope, не изменение принятой очереди.
Нет automatic accepted, публикация запрещена.


## Выполнение текущей очереди — 2026-11-04

.04 прошла независимый Debug/Release Keychain smoke. .09 исправлена и повторно
проверена, полный .34 cleanup остаётся отдельным. .15 прошла повторный review:
macOS bounded Stop и независимый dispose, Linux mic-only/combined обслуживает .17.
.19 прошла delta review. Журнал .20 реализован, ожидает отдельного review.
.11 в работе. .30 fixes повторно проверены, .16 может начинаться после .15.
Точные статусы и доказательства находятся в карточках и active-plan.
