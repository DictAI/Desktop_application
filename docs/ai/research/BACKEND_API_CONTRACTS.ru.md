---
title: "DictAI: фактические HTTP-контракты для отдельного frontend"
date: "2026-10-24"
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
status: researched
scope: frontend-http-api
---

# DictAI: контракты backend для Flutter/Dart

## 1. Область исследования и правила чтения

Исследован backend `/Users/verliiar/phiziks_pr` на указанном commit. Документ
самодостаточен для проектирования клиента: формы данных и ограничения изложены
здесь; ссылки нужны для аудита исходников. Пути источников относительны корню
backend; на другом компьютере абсолютный checkout может отличаться.

Приоритет: зарегистрированный маршрут → handler → application/repository →
тесты и runtime wiring. OpenAPI и старые планы использованы как вторичные
источники. Код не менялся, серверы и production API не вызывались. Наличие
маршрута не доказывает готовность развёрнутой системы или качество моделей.
Это прямо выбранное пользователем исследование с одним результатом; существующие
product tasks и их acceptance не изменяются.

Все UUID, email, текст и версии в примерах синтетические. Строки в угловых
скобках — placeholders, не реальные credentials. Токены и пароли не приведены.
Параметры/тело, не названные у операции, не требуются контрактом. `—` означает
отсутствие тела/параметров; HTTP-файлы нельзя декодировать как JSON.

### Статусы реализации

- **R** — обработчик зарегистрирован, реализован в текущем коде. Нужны обычные
  настройки gateway/сервиса/БД; доступность сети не проверена.
- **D** — реализован, но дополнительно зависит от V2 gate, условного подключения
  handler, workers/artifacts/TLS или других перечисленных prerequisites.
- **I** — в разработке: отдельного нового frontend HTTP API с таким подтверждённым
  статусом не найдено. Незавершённая приёмка pipeline не делает кодовый маршрут отсутствующим.
- **P** — описан только в спецификации/будущей задаче; готового маршрута нет.
- **U** — удалённый legacy API, не основа нового клиента.

## 2. Входная точка, авторизация и общие ошибки

Клиент обращается к **gateway**, задавая свой `base_url`. В Compose опубликован
порт `8000`; OpenAPI указывает localhost:8080 и потому не является достоверным
источником внешнего адреса. Реальный hostname, TLS termination и доступность
должен подтвердить оператор. Не подключать frontend напрямую к БД/NATS/gRPC,
MinIO или внутренним HTTP сервисам.

Источники: [gateway routes](../../../services/gateway/internal/presentation/router.go#L13),
[proxy](../../../services/gateway/internal/application/proxy.go#L15),
[Compose gateway](../../../infra/docker-compose.yml#L77).

- Публичны только `POST /auth/register` и `POST /auth/login`.
- Для остальных операций таблицы передавать `Authorization: Bearer <JWT_FROM_SERVER>`.
  `X-User-Id` не является клиентским параметром: gateway устанавливает его из JWT.
- JWT HS256 содержит `user_id`, `iss=dictai-auth-v2`, `aud=dictai-user`, `exp` через
  7 дней. Login/refresh возвращают только `token`, без refresh_token/expires_in.
- Gateway проверяет HS256 и user_id; auth credential endpoints и весь `/ingest/v2`
  дополнительно проверяют issuer/audience/обязательный exp. Старый JWT без новых
  claims может пройти gateway и затем получить 401 от auth/ingest. Нужен новый login.
- Refresh требует ещё действующий JWT и JSON `{}`; не восстанавливает истёкшую
  сессию. Серверного logout/revocation пользовательского JWT и списка сессий нет.
  Смена email/password не отзывает уже выданный JWT; клиентский logout — удаление
  локального токена. Это фактическое отсутствие endpoint, не обещание будущего API.
- `X-Request-ID` можно передать для корреляции; при отсутствии gateway создаёт UUID
  и возвращает этот header. Это не идентификатор job и не idempotency key.

Источники: [JWT gateway](../../../services/gateway/internal/presentation/middleware/jwt.go#L12),
[auth token/validation](../../../services/auth-service/internal/service/auth_service.go#L132),
[auth protected routes](../../../services/auth-service/internal/presentation/router.go#L25),
[ingest JWT](../../../services/audio-ingest-service/internal/presentation/middleware/jwt.go#L11),
[request ID](../../../services/gateway/internal/presentation/middleware/request_id.go#L8).

### Общий транспортный слой ошибок (применим ко всем операциям)

| Ответ | Фактический формат / реакция клиента |
|---|---|
| 401 gateway/JWT middleware | Часто пустое тело. Не предполагать JSON; предложить login при недействующей сессии |
| 403 auth/ingest middleware | Пустое тело при несовпадении asserted identity; frontend не задаёт X-User-Id |
| 429 gateway | Пустое тело, общий process-wide token bucket, не отдельный лимит пользователя; Retry-After не задан |
| 502 proxy | При недоступном upstream обычно пустое тело; ошибки разрешения target могут быть `{ "error": "..." }` |
| 500 recovery | Может быть пустое тело; service handlers часто используют `{ "error": "..." }` |
| 404 неизвестного/удалённого пути | Может быть обычный текст Gin, не JSON; неверный метод не гарантирует 405 |

Gateway регистрирует `Any`/wildcard, но допустимые методы определяет downstream
router. Значения `error` неоднородны: есть стабильные коды, тексты и технические
ошибки. Не показывать непроверенный raw error пользователю и не строить единый
enum из всех текстов. Парсить JSON только когда оно действительно возвращено.
Источники: [proxy errors](../../../services/gateway/internal/application/proxy.go#L20),
[rate limit](../../../services/gateway/internal/presentation/middleware/ratelimit.go#L10),
[recovery](../../../services/gateway/internal/presentation/middleware/logging.go#L49).

## 3. Сводная таблица клиентских API

`JWT` — авторизация по правилам §2. W = workspace_id, P = participant_id,
A = audio_id, S = session_id, G = grant_id; реальные URL используют сами значения.

| ID | Метод и URL после base_url | Назначение | Auth | Состояние |
|---|---|---|---|---|
| A01 | POST /auth/register | Регистрация | — | R |
| A02 | POST /auth/login | Получить JWT | — | R |
| A03 | POST /auth/refresh | Перевыпустить JWT | JWT | R |
| A04 | POST /auth/change-password | Изменить пароль | JWT | R |
| A05 | POST /auth/change-email | Изменить email | JWT | R |
| W01 | GET /workspaces/ | Свои workspace | JWT | R |
| W02 | POST /workspaces/ | Создать workspace | JWT | R |
| W03 | GET /workspaces/{W} | Детали workspace | JWT | R, ограничения доступа ниже |
| W04 | PUT /workspaces/{W} | Переименовать | JWT | R |
| W05 | DELETE /workspaces/{W} | Удалить workspace | JWT | R |
| W06 | GET /workspaces/{W}/participants | Контакты | JWT | R |
| W07 | POST /workspaces/{W}/participants | Добавить контакт | JWT | R |
| W08 | PUT /workspaces/{W}/participants/{P} | Изменить контакт | JWT | R |
| W09 | DELETE /workspaces/{W}/participants/{P} | Удалить контакт | JWT | R |
| U01 | POST /ingest/v2/audio/upload | Загрузка в workspace | JWT | D |
| U02 | POST /ingest/v2/audio/upload/anonymous | Загрузка без workspace | JWT | D |
| U03 | GET /ingest/v2/audio/anonymous/{S} | Статус anonymous session | JWT | D |
| U04 | GET /ingest/v2/audio/{A}/original | Исходный WAV | JWT | D |
| U05 | POST /ingest/v2/audio/{A}/processing-grants | Owner reauthorization, специальный resume | JWT | D, discovery не завершён |
| U06 | POST /ingest/v2/audio/{A}/processing-grants/{G}/revoke | Отозвать processing grant | JWT | D, это не cancel job |
| R01 | GET /meetings/results | Свои последние V2 results | JWT | R, нужны V2 таблицы |
| R02 | DELETE /meetings/results/{A} | Скрыть все версии результата | JWT | R |
| R03 | GET /meetings/results/{A}/speech-status | Статусы трёх процессов | JWT | D |
| R04 | GET /meetings/results/{A}/structured | Canonical transcript JSON | JWT | D |
| R05 | GET /meetings/results/{A}/documents/{kind} | TXT/PDF | JWT | D |

Итого **25 реализованных клиентских операций**; R05 имеет четыре допустимых kind.
Для каждой указан источник в подробном разделе. Условная регистрация и внешние
зависимости описаны в §9; категории P/U и внутренние API — в §10.

## 4. Авторизация и учётная запись

Общие DTO запроса register/login: `{ "email": "string", "password": "string" }`.
Email валидируется через Go mail.ParseAddress; backend не обещает trim/lowercase.
Для register/change-password минимальная длина — 8 **байт**, не символов.
Ошибки bcrypt, в том числе слишком длинный пароль, могут стать 500; иной верхний
лимит frontend-контрактом не установлен. Client не отправляет UserId в body:
в защищённых handler он заменяется verified identity.

### A01 — POST /auth/register

Auth: нет; path/query: —. JSON request:

```json
{"email":"owner@example.invalid","password":"<PASSWORD_MIN_8_BYTES>"}
```

**200**, не 201; JSON response:

```json
{"message":"user registered successfully"}
```

Ошибки: 400 `invalid request`, `invalid password`, `invalid email`;
409 `email already exists`; 500 `internal server error`. user_id и JWT не
возвращаются; после регистрации требуется login. DTO: RegisterRequest.
Источники: [handler](../../../services/auth-service/internal/presentation/handlers/register_handler.go#L10),
[service](../../../services/auth-service/internal/service/auth_service.go#L23),
[error mapping](../../../services/auth-service/internal/presentation/handlers/error_handling.go#L12).

### A02 — POST /auth/login

Auth: нет; path/query: —. Request такой же JSON с email/password. **200**:

```json
{"token":"<JWT_FROM_SERVER>"}
```

Ошибки: 400 `invalid request`/`invalid email`; 401 `wrong password`;
404 `user not found`; 500 `internal server error`. Поле называется `token`,
не `access_token`. DTO: LoginRequest, LoginResponse.
Источники: [handler](../../../services/auth-service/internal/presentation/handlers/login_handler.go#L10),
[login service](../../../services/auth-service/internal/service/auth_service.go#L55).

### A03 — POST /auth/refresh

Auth: действующий JWT нового issuer; path/query: —. Обязательно отправить JSON:

```json
{}
```

**200** с тем же форматом `{ "token": "<NEW_JWT_FROM_SERVER>" }`.
Пустое HTTP body не эквивалентно `{}`: ShouldBindJSON вернёт 400 `invalid request`.
401/403 по §2; 500 `internal server error`. Старый JWT не отзывается.
DTO: RefreshRequest (UserId серверный), RefreshResponse.
Источник: [handler](../../../services/auth-service/internal/presentation/handlers/refresh_handler.go#L10),
[RefreshToken](../../../services/auth-service/internal/service/auth_service.go#L87).

### A04 — POST /auth/change-password

Auth: JWT; path/query: —. **JSON request** использует new_password, без old_password:

```json
{"new_password":"<NEW_PASSWORD_MIN_8_BYTES>"}
```

**201** `{ "message": "password changed successfully" }`.
400 `invalid request`/`invalid password`; 401/403 middleware; 500 `internal server error`.
DTO: ChangePasswordRequest. Источник:
[handler](../../../services/auth-service/internal/presentation/handlers/change_password_handler.go#L10),
[service](../../../services/auth-service/internal/service/auth_service.go#L113).

### A05 — POST /auth/change-email

Auth: JWT; path/query: —. JSON request:

```json
{"new_email":"new-owner@example.invalid"}
```

**201** `{ "message": "email changed successfully" }`.
400 `invalid request`/`invalid email`; 409 `email already exists`; 401/403 middleware;
500 `internal server error`. DTO: ChangeEmailRequest.
Источники: [handler](../../../services/auth-service/internal/presentation/handlers/change_email_handler.go#L10),
[service](../../../services/auth-service/internal/service/auth_service.go#L91).

## 5. Рабочие пространства и контакты

Для W01–W09 обязателен JWT; внутренний workspace-service использует доверенный
header от gateway. Прямой доступ к нему не является frontend-сценарием.
Path IDs передаются строками UUID из ответов; handlers проверяют непустоту,
но не везде валидируют UUID до PostgreSQL: неверный ID может дать 500 вместо 400.
Для W02/W04 непустое name; для W07 непустые name/email. Whitespace-only имена
явно не запрещены. Пустая строка в W08 означает «не менять», не «очистить».

### Общие схемы и ошибки

**WorkspaceListItem/WorkspaceCreated** (W01/W02):

```json
{"workspace_id":"11111111-1111-4111-8111-111111111111","owner_user_id":"22222222-2222-4222-8222-222222222222","name":"Demo workspace","created_at":"2026-10-24T09:00:00Z"}
```

**WorkspaceDetails/WorkspaceUpdated** (W03/W04) возвращает `owner_id` вместо
`owner_user_id`; остальные поля такие же. Дата у W01 форматируется строкой
секунд с суффиксом Z, у W02/W03/W04 сериализуется time.Time, возможны дробные секунды.

**Participant** (W06/W07/W08):

```json
{"participant_id":"33333333-3333-4333-8333-333333333333","workspace_id":"11111111-1111-4111-8111-111111111111","name":"Demo contact","email":"contact@example.invalid"}
```

Ни один ответ не содержит voice_profile_id. Email контакта не создаёт пользователя,
приглашение или установленное членство учётной записи.

Workspace error JSON: `{ "error": "<message>" }`. Возможны 400 `invalid request`,
`invalid workspace name`, `invalid user name`, `invalid email`; 401 `user unauthorized`;
403 — отдельные owner/view сообщения; 404 `workspace not found`/`participant not found in workspace`;
409 `email already exists in this workspace`; 500 `internal server error`.
Важное расхождение: FindWorkspace возвращает sql.ErrNoRows, а service обычно
проверяет workspace==nil только после проверки err. Поэтому отсутствующий workspace
в реальной PostgreSQL-ветке может стать **500**, хотя mapping предусматривает 404.
Это наблюдение, не исправление и не обещание устойчивого not-found поведения.

Источники общих правил: [workspace service](../../../services/workspace-service/internal/service/workspace_service.go#L18),
[error mapping](../../../services/workspace-service/internal/presentation/handlers/error_handling.go#L12),
[workspace persistence](../../../services/workspace-service/internal/persistence/postgres_workspace_repository.go#L24),
[participant persistence](../../../services/workspace-service/internal/persistence/postgres_participant_repository.go#L17).

### W01 — GET /workspaces/

Path/body: —. Query: page и limit — положительные целые, defaults 1 и 20.
Service при limit>100 использует 20, но handler возвращает в pagination исходный
запрошенный limit; держать запрос в диапазоне 1–100. Список **только owner-owned**,
порядок created_at DESC. **200**:

```json
{"data":[],"pagination":{"page":1,"limit":20,"total":0,"total_pages":0}}
```

Непустое data — массив WorkspaceListItem выше. Ошибки: 400
`page must be a positive integer`/`limit must be a positive integer`; 401; 500.
DTO: локальный workspaceItem в handler, domain.Workspace.
Источники: [handler](../../../services/workspace-service/internal/presentation/handlers/get_user_workspaces_handler.go#L11),
[pagination service](../../../services/workspace-service/internal/service/workspace_service.go#L122).

### W02 — POST /workspaces/

Path/query: —. JSON `{ "name": "Demo workspace" }`.
**200**, не 201, WorkspaceCreated выше. Ошибки: 400, 401, 500 из общих правил.
CreateWorkspaceResponse в исходнике неполон: фактический gin.H содержит четыре поля.
Источник: [handler](../../../services/workspace-service/internal/presentation/handlers/create_workspaces_handler.go#L10).

### W03 — GET /workspaces/{workspace_id}

Path: workspace_id; query/body: —. **200** WorkspaceDetails с owner_id.
Ошибки: 400 непустота пути, 401, 404 mapping/500 persistence caveat выше.
**Handler не проверяет принадлежность workspace текущему user:** GetWorkspace
получает только workspaceID. Нельзя считать этот endpoint проверкой прав доступа.
Источники: [handler](../../../services/workspace-service/internal/presentation/handlers/get_workspace_handler.go#L10),
[service](../../../services/workspace-service/internal/service/workspace_service.go#L208).

### W04 — PUT /workspaces/{workspace_id}

Path: workspace_id; query: —; JSON `{ "name": "Updated workspace" }`.
Только owner; **200** WorkspaceUpdated с owner_id. Ошибки: 400 `name is required`
и общая validation; 401; 403 `only workspace owner can update workspace`;
404 mapping/500 missing-workspace caveat; 500 зависимости.
DTO: UpdateWorkspaceRequest. Источник:
[handler](../../../services/workspace-service/internal/presentation/handlers/update_workspace_handler.go#L10).

### W05 — DELETE /workspaces/{workspace_id}

Path: workspace_id; query/body: —. Только owner; **200**, не 204:

```json
{"message":"workspace deleted successfully"}
```

Ошибки: 400 `workspace_id is required`; 401;
403 `only workspace owner can delete workspace`; 404 mapping/500 caveat.
SQL удаляет workspace и связанные contacts через cascade; HTTP не гарантирует
каскадное удаление исходного аудио/всех V2 результатов. Источники:
[handler](../../../services/workspace-service/internal/presentation/handlers/delete_workspace_handler.go#L10),
[initial SQL](../../../infra/migrate-container/migrations/1_initial.up.sql#L12).

### W06 — GET /workspaces/{workspace_id}/participants

Path: workspace_id; query/body: —. **200** — массив Participant; для пустого списка
фактический handler сериализует nil slice как JSON **null**, не обязательно `[]`.
Доступ: owner либо сравнение `ParticipantID == userID` в service; проверки по
email пользователя нет. Автоматически рассчитывать на доступ контактного лица нельзя.
Ошибки: 400 `workspace_id missing`; 401; 403 `no rights to view participants`;
404 mapping/500 caveat. DTO: GetParticipantsResponse.
Источники: [handler](../../../services/workspace-service/internal/presentation/handlers/get_participants_handler.go#L10),
[access service](../../../services/workspace-service/internal/service/workspace_service.go#L219).

### W07 — POST /workspaces/{workspace_id}/participants

Path: workspace_id; query: —. JSON `{ "name": "Demo contact", "email": "contact@example.invalid" }`.
Только owner; **200** Participant (все четыре поля, не только participant_id).
Ошибки: 400 `workspace_id missing`, `invalid request`, `invalid user name`, `invalid email`;
401; 403 `user not owner of workspace`; 404 mapping/500 caveat;
409 `email already exists in this workspace`; 500.
DTO: AddParticipantRequest; AddParticipantResponse не описывает весь gin.H.
Источник: [handler](../../../services/workspace-service/internal/presentation/handlers/add_participant_handler.go#L10).

### W08 — PUT /workspaces/{workspace_id}/participants/{participant_id}

Path: оба ID; query: —. Частичное обновление через PUT: непустое name и/или email.

```json
{"name":"Updated contact"}
```

Только owner; **200** полный Participant с прежним email. Нельзя очищать поля
пустыми строками. Ошибки: 400 `at least one of name or email must be provided`,
`workspace_id and participant_id are required`, invalid name/email; 401;
403 `only workspace owner can update participants`; 404 participant/mapping;
409 duplicate email; 500 missing-workspace/dependency caveat.
DTO: UpdateParticipantRequest. Источник:
[handler](../../../services/workspace-service/internal/presentation/handlers/update_participant_handler.go#L10).

### W09 — DELETE /workspaces/{workspace_id}/participants/{participant_id}

Path: оба ID; query/body: —. Только owner; **200**:

```json
{"message":"participant removed successfully"}
```

Ошибки: 400 `workspace_id and participant_id are required`; 401;
403 `only workspace owner can remove participants`; 404 participant/mapping;
500 missing-workspace/dependency caveat. Источник:
[handler](../../../services/workspace-service/internal/presentation/handlers/delete_participant_handler.go#L10).

## 6. Запись, загрузка и исходное аудио

Backend не начинает захват микрофона/системного звука: frontend записывает локально,
завершает корректный WAV и загружает его. Потоковой live-загрузки нет.

### U01/U02 — POST /ingest/v2/audio/upload и /ingest/v2/audio/upload/anonymous

Auth: JWT нового issuer; path/query: —. Content-Type multipart/form-data с boundary.
**Idempotency-Key обязателен:** 1–128 байт, без surrounding whitespace, NUL/CR/LF.
Для нового аудио новый ключ, при сетевой ошибке повтор с тем же ключом и всеми
исходными inputs. Идемпотентность owner-scoped. Сравнение включает байты файла,
workspace/anonymous, language/mixed и серверные processing/engine/config revisions;
смена deployment revisions может сделать повтор конфликтующим.

| Multipart field | U01 workspace | U02 anonymous | Формат |
|---|---|---|---|
| audio | Обязателен | Обязателен | Binary PCM/IEEE-float RIFF WAVE |
| workspace_id | Обязателен | Должен отсутствовать/быть пустым | UUID; U01 проверяет workspace access |
| language | Необязателен | Необязателен | Пустая строка (auto), ru или en |
| mixed | Необязателен | Необязателен | Строка true/false, default false; true требует пустой language |

JSON ниже показывает **поля формы**, это не JSON request вместо multipart:

```json
{"workspace_id":"11111111-1111-4111-8111-111111111111","language":"ru","mixed":"false"}
```

Файл передаётся отдельной audio part; для U02 workspace_id исключается.
Workspace upload не требует голосовых профилей, записанных образцов или
непустого списка участников у owner. Проверка доступа обращается к participants API
по проверяемому HTTPS; сам по себе GET workspace не используется как permission.

Оба endpoint возвращают **202** при принятии и при идентичном replay:

```json
{"audio_id":"44444444-4444-4444-8444-444444444444","session_id":null,"job_id":"55555555-5555-4555-8555-555555555555","processing_version":"example-processing-v1","status_url":"/meetings/results/44444444-4444-4444-8444-444444444444/speech-status"}
```

Для U02 session_id — UUID, не null. Остальные поля одинаковы; нет status,
grant_id, transcript или URL storage. Сохранить audio_id/job_id/version/status_url.
202 означает транзакционно созданный durable job/outbox, не готовый transcript.

| Код | Body / причина |
|---|---|
| 400 | error=audio_required, audio_unavailable, invalid_mixed; ошибки application включают `invalid input: ...`, WAV errors могут содержать перенос строки из errors.Join |
| 401/403 | JWT middleware; 403 `{ "error": "forbidden" }` при отказе workspace access |
| 409 | `{ "error": "idempotency_conflict" }` — ключ с другими inputs |
| 429 | `{ "error": "upload_busy" }`, `Retry-After: 5`; один одновременный upload на handler instance |
| 503 | `{ "error": "v2_upload_disabled" }` при nil handler/service; `{ "error": "upload_unavailable" }` при прочих зависимостях/ошибках |

**Ограничения файлов:** не по расширению/MIME, а по фактическим bytes. Не MP3,
M4A/AAC, OGG, RF64 или WAVE_FORMAT_EXTENSIBLE. RIFF format=1: PCM 8/16/24/32 bit;
format=3: float 32/64 bit; 8–192 kHz, 1–8 channels; положительная длительность,
не более 7200 секунд; файл до 1 GiB (1,073,741,824 bytes). Проверяются размеры
RIFF/chunks, byteRate/blockAlign, один fmt и один data chunk. Общий multipart body
ограничен 1 GiB + 1 MiB; превышение при FormFile может дать 400 audio_required,
специальный стабильный **413 не реализован**. Request context upload — 15 минут,
но таймаут внешнего proxy может быть короче; численного SLA для клиента нет.
Невалидный файл не создаёт job. Внутреннее object key может иметь суффикс .mp3,
но bytes и внешний original endpoint остаются WAV; storage key не часть API.

DTO: V2UploadInput (internal), V2UploadResult (wire); OpenAPI V2UploadAccepted.
Источники: [router](../../../services/audio-ingest-service/internal/presentation/router.go#L22),
[handler](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go#L24),
[validation/DTO](../../../services/audio-ingest-service/internal/application/upload_v2.go#L16),
[idempotency/transaction](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go#L48),
[WAV validator](../../../services/audio-ingest-service/internal/infrastructure/db/upload_wav.go#L11),
[workspace authorization](../../../services/audio-ingest-service/internal/infrastructure/workspace/http_access_checker.go#L65).

### U03 — GET /ingest/v2/audio/anonymous/{session_id}

Auth: JWT owner. Path session_id — UUID; query/body: —. **200**:

```json
{"session_id":"66666666-6666-4666-8666-666666666666","audio_id":"44444444-4444-4444-8444-444444444444","job_id":"55555555-5555-4555-8555-555555555555","processing_version":"example-processing-v1","status":"queued","status_url":"/meetings/results/44444444-4444-4444-8444-444444444444/speech-status","confirm_required":false}
```

status: queued/running/ready/failed/cancelled/expired. Job completed преобразуется
в ready; истёкшая session всегда expired. Нет speakers/fragments/name-confirmation.
404 `{ "error": "session_not_found" }` для неверного UUID/чужой/отсутствующей session;
503 disabled либо `{ "error": "status_unavailable" }`; 401/403 общие.
Anonymous source/session TTL по schema — 7 дней, не гарантия вечного хранения
результатов. Session query не учитывает result-deletion tombstone: после удаления
результата она может всё ещё вернуть 200/ready, хотя result/original вернут 404.
DTO фактически map[string]any, OpenAPI V2SessionStatus.
Источники: [handler](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go#L130),
[repository](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go#L247),
[session TTL](../../../infra/migrate-container/migrations/4_anonymous_sessions.up.sql#L1).

### U04 — GET /ingest/v2/audio/{audio_id}/original

Auth: JWT owner. Path audio_id — UUID; query/body: —, выбора job_id нет.
**200 audio/wav**, `Content-Disposition: attachment; filename="original.wav"`;
body — исходный binary WAV, не JSON и не signed storage URL. Проверяются owner,
source grant/revocation, anonymous expiry, deletion и текущий workspace access.
404 `{ "error": "audio_not_found" }` также скрывает чужую запись и невалидный UUID;
503 disabled/`audio_unavailable`; 401/403 общие.
Нет Range/resume-контракта или обещанного Content-Length. При поздней ошибке
stream соединение прерывается: клиент должен считать частичный файл неуспехом,
даже если уже увидел 200. Processing grant U06 и source grant здесь — разные записи.
Источники: [handler](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go#L81),
[repository](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go#L205),
[transfer tests](../../../services/audio-ingest-service/internal/presentation/handler/upload_v2_handler_test.go#L57).

### U05 — POST /ingest/v2/audio/{audio_id}/processing-grants

Auth: текущий JWT owner + повторная workspace/session policy. Path audio_id;
query: —; header Idempotency-Key по тем же ограничениям длины/whitespace.
JSON, максимум 2048 bytes, неизвестные поля/второй JSON object запрещены:

```json
{"job_id":"55555555-5555-4555-8555-555555555555","previous_grant_id":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}
```

В примере previous_grant_id — синтетическая строка длиной 43; заменить на
действительный ранее выданный ID, который не является пользовательским JWT.
**202**, в том числе идемпотентный replay:

```json
{"subject":"speech.job.resume.v1","event_id":"0000000000000000000000000000000000000000000000000000000000000000","job_id":"55555555-5555-4555-8555-555555555555","grant_id":"BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB","grant_generation":1}
```

400 пустое тело при malformed/unknown JSON, пустом job_id/previous ID не 43 chars;
409 `{ "error": "processing_reauthorization_denied" }`, в том числе неверный key;
503 пустое тело при nil registry либо `{ "error": "processing_reauthorization_unavailable" }`;
401/403 middleware. Регистрация зависит от непустого GrantHandler; иначе 404.

Это **не общий retry**: допустим failed job с authorization_failure, без cancel,
deletion/tombstone, с истёкшим или исчерпавшим 20 reads предыдущим grant, при
текущих правах. Возобновляется тот же job с checkpoints и budgets; completed,
cancelled и произвольная model failure не принимаются для **нового** resume.
Сохранённый идемпотентный replay после повторной policy-проверки возвращает прежний
202 до проверки текущего state/tombstone: job уже может быть завершён или удалён;
это не новый restart. После replay снова проверять актуальный result/status.
Новый grant TTL — 24h.
Критический пробел frontend: initial grant_id и authorization_failure отсутствуют
в upload/status/structured ответах; клиентский discovery старого grant не реализован.
UI action нельзя проектировать как готовый без согласования источника ID.
DTO: delegation.Reissue/Resume. Источники:
[handler](../../../services/audio-ingest-service/internal/presentation/handler/grants.go#L45),
[registry/DTO](../../../contracts/speech/delegation/resume.go#L13),
[grant TTL](../../../contracts/speech/delegation/grants.go#L67).

### U06 — POST /ingest/v2/audio/{audio_id}/processing-grants/{grant_id}/revoke

Auth: JWT owner. Path: audio_id и grant_id; query/body: —. **204**, пустое тело.
404 при чужом/неизвестном grant; 503 registry/DB; 401/403 middleware. Ошибки
handler здесь пустые. Установленное revoked_at не отменяется при повторе,
повтор существующего owner-grant остаётся 204. Route условно регистрируется.
Отзыв препятствует processing reads, но не задаёт job state cancelled, не удаляет
результат и не является logout/source-download revoke. Discovery grant_id — тот
же открытый вопрос, что у U05. Источники:
[handler](../../../services/audio-ingest-service/internal/presentation/handler/grants.go#L73),
[registry](../../../contracts/speech/delegation/grants.go#L163).

## 7. Результаты и документы

Все операции требуют JWT через gateway. Results-service доверяет X-User-Id от
gateway и ограничивает результаты **owner записи**, а не всеми contacts workspace.
Для R03–R05 query `job_id` необязателен: непустой выбирает точную версию этой
записи; без него выбирается latest accepted_at DESC, job_id DESC.
Не передавать processing_version вместо job_id. Общего endpoint списка версий нет.

### R01 — GET /meetings/results

Path/body: —. Query page/limit: положительные integers; defaults 1/20,
limit>100 сбрасывается к 20. start_date/end_date: RFC3339 или YYYY-MM-DD;
date-only end_date превращается в 23:59:59, а не до конца дробной секунды.
Фильтр start>end отдельно не запрещён. Нет server-side workspace_id фильтра.
Возвращается latest V2 job каждого audio текущего owner, включая anonymous,
без deleted и historical legacy rows; сортировка accepted_at DESC, job_id DESC.
**200**:

```json
{"data":[{"result_id":"55555555-5555-4555-8555-555555555555","audio_id":"44444444-4444-4444-8444-444444444444","workspace_id":"","workspace_name":"","upload_user_id":"22222222-2222-4222-8222-222222222222","summary_url":"","transcript_url":"","status":"pending","created_at":"2026-10-24T09:00:00Z"}],"pagination":{"page":1,"limit":20,"total":1,"total_pages":1}}
```

`result_id` — job ID, не новый независимый meeting ID. workspace_id/name для
anonymous — пустые строки, не null. status: pending; failed при failed/cancelled
job; done при наличии canonical results projection. done не означает готовую summary.
transcript_url появляется при непустом transcript_text и ведёт на
`/meetings/results/{A}/documents/transcript.txt?job_id={job_id}`; summary_url —
на summary.pdf только при наличии bytes PDF. Значения относительны gateway;
скачивать с JWT, а не открывать как публичный URL. Пустой data — `[]`.
Ошибки: 400 invalid start_date/end_date format и page/limit messages; 401;
500 `{ "error": "<wrapped repository error>" }`; общие §2.
DTO: ResultItem/ListOutput/ListFilters; OpenAPI inline result schema.
Источники: [handler](../../../services/results-service/internal/presentation/handlers/result_handler.go#L22),
[wire DTO/defaults](../../../services/results-service/internal/service/result_service.go#L22),
[query/projection/URLs](../../../services/results-service/internal/infrastructure/persistence/postgres_result_repository.go#L25).

### R02 — DELETE /meetings/results/{audio_id}

Path audio_id; query/body: —. **204**, пустое тело; повтор владельцем существующего
job также может вернуть 204. 401; 404 `{ "error": "result not found" }` для
отсутствующего/чужого job; 500 технический error. Не трактовать 204 как удаление
всех физических данных: ставится owner/audio tombstone для всех версий, очищаются
derived DB documents/chunk output; historical data, shared canonical/checkpoint
artifacts и original bytes физически этим endpoint не уничтожаются. Canonical API
и original скрываются. Это не публичный cancel job, worker может ещё работать.
Источники: [handler](../../../services/results-service/internal/presentation/handlers/result_handler.go#L91),
[service](../../../services/results-service/internal/service/result_service.go#L97),
[transaction](../../../services/results-service/internal/infrastructure/persistence/speech_delete.go#L10).

### R03 — GET /meetings/results/{audio_id}/speech-status

Path audio_id; optional query job_id; body: —. **200**, Cache-Control private,no-store:

```json
{"job_id":"55555555-5555-4555-8555-555555555555","processing_version":"example-processing-v1","workspace_id":null,"job_status":"running","transcript_status":"pending","summary_status":"pending","summary_error":null}
```

Все семь полей возвращаются. job_status: queued/running/completed/failed/cancelled.
transcript_status: ready при наличии projection; иначе failed/cancelled для
terminal failure/cancel, иначе pending. summary_status: pending/ready/failed,
независим от job/transcript; пока summary row не создан, pending даже при failed job.
summary_error: null или строка; это не ошибка ASR. Стандартные worker-коды:
not_configured, input_limit, output_limit, retry_exhausted, document_failure;
модельный адаптер может вернуть собственный Failure.Code. Не делать закрытый enum
в Dart и не ожидать failure_stage/percent/progress/grant_id: этих полей нет.
401 `{ "error": "authentication required" }` при отсутствии trusted header;
404 `{ "error": "result unavailable" }` при чужом/удалённом/отсутствующем audio/job;
503 с тем же error при DB failure. Без подключённого SpeechHandler — 404 маршрута.
DTO: speechResult; OpenAPI SpeechStatus. Источник:
[load/status](../../../services/results-service/internal/presentation/handlers/speech_handler.go#L30),
[summary failure lifecycle](../../../services/summarization-service/internal/v2/worker.go#L98).

### R04 — GET /meetings/results/{audio_id}/structured

Path audio_id; optional query job_id; body: —. **200 application/json** — canonical
Transcript по §8. **202** — тот же семиполевой SpeechStatus, если transcript_status
не ready, в том числе при failed/cancelled job: 202 **не всегда «продолжать ждать»**.
Cache-Control private,no-store. Ошибки: 401/404/503 load как R03; 503
`{ "error": "artifact unavailable" }` при missing/corrupt/unmatched artifact.
Состояние projection ready не гарантирует возможность прочитать artifact сейчас.
DTO: speech.Transcript; OpenAPI CanonicalTranscript; schema §8.
Источник: [handler](../../../services/results-service/internal/presentation/handlers/speech_handler.go#L72).

### R05 — GET /meetings/results/{audio_id}/documents/{kind}

Path audio_id, kind; optional query job_id; body: —. kind строго один из:

| kind | Успешный ответ |
|---|---|
| transcript.txt | 200 text/plain; charset=utf-8, полный текст с таймкодами/Speaker N |
| transcript.pdf | 200 application/pdf, bytes |
| summary.txt | 200 text/plain; charset=utf-8, summary text |
| summary.pdf | 200 application/pdf, bytes |

Cache-Control private,no-store. Content-Disposition/filename handler не задаёт:
frontend выбирает имя сам. Нет JSON envelope или storage URL. Пример TXT body:

```text
[00:00:00.000000 — 00:00:01.000000] Speaker 1
Пример.

```

Точный renderer — источник ниже; это иллюстрация, не JSON. HTTP 404
`{ "error": "document not found" }` для неверного kind;
404 `{ "error": "document unavailable", "summary_status": "pending" }` при
отсутствующих/пустых bytes (summary_status может быть failed/ready);
503 `{ "error": "document unavailable" }` при DB failure. Ошибки load как R03.
404 документа не доказывает отсутствие audio: отдельно смотреть статусы.
Transcript TXT может быть доступен до PDF и даже при ошибке summary; JSON и TXT
проецируются разными consumers. Для no_speech документ может содержать
`No speech detected.`. JSON canonical остаётся независимым от генерации PDF/LLM.
Источники: [handler](../../../services/results-service/internal/presentation/handlers/speech_handler.go#L97),
[render](../../../services/summarization-service/internal/v2/render.go#L15),
[worker](../../../services/summarization-service/internal/v2/worker.go#L35).

## 8. Canonical Transcript: полная wire-модель

Авторитетная JSON Schema — [transcript.schema.json](../../../contracts/speech/transcript.schema.json),
Go-типы/инварианты — [transcript.go](../../../contracts/speech/transcript.go#L13),
строгое декодирование — [decode.go](../../../contracts/speech/decode.go).
Все перечисленные ключи обязательны; nullable не означает отсутствие ключа.
Объекты schema запрещают дополнительные поля. В HTTP возвращается сам artifact,
не `{data: ...}`. Canonical artifact ограничен 50 MiB; это отдельный лимит,
не upload limit. Источник: [artifact bounds](../../../contracts/speech/ready.go#L10).

| Объект | Поля |
|---|---|
| Transcript | schema_version:string (=dictai-transcript/v1), recording_id:string (=audio_id), job_id:string, processing_version:string, access:AccessContext, duration_us:int64, speech_state:speech/no_speech, language:string/null, engines:EngineVersion[], speakers:Speaker[], segments:Segment[] |
| AccessContext | owner_user_id:string, workspace_id:string/null; это права, не speaker identity |
| EngineVersion | role:asr/diarization/combined, name:string, model:string, revision:string |
| Speaker | speaker_id:string (speaker_1, speaker_2…), label:string (Speaker 1, Speaker 2…) |
| Segment | start_us:int64, end_us:int64, speaker_id:string (speaker_N или UNKNOWN), text:string, confidence:number/null, language:string/null, word_timing:available/unavailable, words:Word[] |
| Word | start_us:int64, end_us:int64, text:string, confidence:number/null, language:string/null; speaker наследуется от segment |

Микросекунды отсчитываются от исходной записи, не от epoch/chunk. Интервал
полуоткрытый [start_us,end_us); числа <= 2^53-1. confidence при наличии в [0,1].
language — код/тег по schema/validator, а не произвольное имя языка. Engines:
один combined либо по одному asr+diarization с immutable revisions.
speakers упорядочены по первому появлению и имеют непрерывные ordinals.
Разные speakers могут говорить одновременно; известный speaker не перекрывает
себя. Сегменты сортируются детерминированно. Не объединять speakers между записями.
word_timing=unavailable требует `words: []`; available — непустые word intervals.
Не конструировать вымышленные word times из текста.

Пример успешного transcript (синтетический engine, не production-выбор модели):

```json
{
  "schema_version":"dictai-transcript/v1",
  "recording_id":"44444444-4444-4444-8444-444444444444",
  "job_id":"55555555-5555-4555-8555-555555555555",
  "processing_version":"example-processing-v1",
  "access":{"owner_user_id":"22222222-2222-4222-8222-222222222222","workspace_id":null},
  "duration_us":2000000,
  "speech_state":"speech",
  "language":"ru",
  "engines":[{"role":"combined","name":"example-engine","model":"example-model","revision":"example-revision-1"}],
  "speakers":[{"speaker_id":"speaker_1","label":"Speaker 1"}],
  "segments":[{"start_us":0,"end_us":1000000,"speaker_id":"speaker_1","text":"Пример.","confidence":null,"language":"ru","word_timing":"unavailable","words":[]}]
}
```

При no_speech все остальные top-level ключи сохраняются, speech_state=no_speech,
speakers=[] и segments=[]; это успешная обработка, не failed.
UNKNOWN используется только как segment speaker_id при недостаточной атрибуции,
не как persisted человек/голосовой профиль. Полного endpoint редактирования текста,
rename/merge speakers или присвоения participant_id в текущем API нет.

## 9. Асинхронный сценарий и prerequisites

### Рекомендуемая последовательность для клиента (вывод из контрактов)

1. Register при необходимости → login → сохранить token. Выбрать workspace либо
   anonymous; контакты нужны для уведомлений, не для голосовой идентификации.
2. Закончить запись локально в поддерживаемый WAV; создать idempotency key.
   Отправить multipart U01/U02. При потере ответа повторить тот же файл/options/key;
   409 требует разбора inputs, а не бесконечного retry.
3. После 202 сохранить audio_id/job_id/version. Опросить status_url с `?job_id=...`.
   Частота polling/клиентский deadline — решение frontend, server Retry-After для
   status не задаёт. Backoff с jitter — рекомендация клиента, не обязательство API.
4. queued/running — ожидание. completed — model job завершён, но projection может
   ещё быть pending. При transcript_status=ready запросить structured.
5. failed/cancelled при отсутствии ready transcript — закончить ожидание model
   result с ошибкой. Публичного failure_stage/message нет; подробности оператору
   по job_id/X-Request-ID. Не ждать summary_status, оставшегося pending у failed job.
6. Summary отслеживать отдельно: ready — запросить нужный document; failed —
   сохранить доступный transcript и сообщить, что summary недоступна.
   Готовый JSON не гарантирует готовый TXT/PDF. 404 документа + pending может быть
   временной задержкой, но нет server timeout, когда документ обязан появиться.
7. 503/502/429 — транспорт/зависимости, не доказательство потери durable job.
   404 result при известном owner/job может означать deletion/неверную версию;
   expired session не чинится confirm. Неполный download не сохранять как готовый.

Внутри backend upload транзакционно сохраняет source/grants/job/outbox;
JetStream/dispatcher запускает bounded CPU worker; canonical artifact и ready
event читают **независимые** results и summarization consumers. Summary worker
сохраняет transcript TXT, компилирует PDF через Typst, вызывает модель для summary
и публикует completion. Notifications отправляются email owner и workspace contacts,
для anonymous только owner. Уведомления не заменяют client status endpoint.
Внешний клиент не подписывается на NATS. SMTP uncertain не повторяется автоматически.

Источники: [upload transaction](../../../services/audio-ingest-service/internal/infrastructure/db/upload_v2.go#L134),
[job states/schema](../../../infra/migrate-container/migrations/7_speech_jobs.up.sql#L1),
[result consumer](../../../services/results-service/internal/presentation/handlers/speech_handler.go#L21),
[summary worker](../../../services/summarization-service/internal/v2/worker.go#L35),
[notifications](../../../services/notification-service/internal/durable/worker.go).

### Что нужно настроить до проверки живого flow

- Gateway origins/secret/rate limits и достижимость upstream; внешняя TLS termination.
- PostgreSQL и актуальные migrations (включая V2 jobs/delivery/downstream/upload/delegation),
  storage/MinIO с versioning/TLS, проверенные grants/source access и operator certificates.
- `AUDIO_INGEST_V2_ENABLED=true`, processing/engine/config revisions, разрешённый
  processing principal. Workspace access checker требует проверяемый HTTPS endpoint.
  Workspace server включает RunTLS только при настройке обоих WORKSPACE_TLS_CERT
  и WORKSPACE_TLS_KEY; без них работает HTTP. Для загрузки в workspace требуется
  согласованная HTTPS-конфигурация, а не предположение о защищённом транспорте.
- CPU worker, offline модели, ресурсы, JetStream TLS/ACL и shared artifact directory.
- Results router умеет работать без SpeechHandler: в такой тестовой/альтернативной
  композиции R03–R05 дают route 404, а R01/R02 зарегистрированы отдельно. Однако
  штатный config.Load требует **непустой SPEECH_ARTIFACT_DIR** и panic-ит без него:
  production binary не доходит до HTTP startup. При непустом dir main также
  требует успешное NATS TLS подключение. Не обещать работающий R01/R02 deployment
  без artifact/broker prerequisites; при недоступном процессе gateway может дать 502.
- Typst для PDF. Для summary на speech нужен настроенный model API key; без него
  summary_status=failed/summary_error=not_configured после transcript PDF шага.
  Ошибка PDF не должна интерпретироваться как ошибка уже доступного canonical JSON.
- Настройки SMTP/получателей нужны для email; отдельного frontend API notifications нет.

**Отдельное обнаруженное расхождение запуска:** router с nil V2UploadHandler даёт
503 v2_upload_disabled (подтверждено тестом), но production main при выключенном V2
оставляет delegatedServer=nil и завершает процесс до HTTP ListenAndServeTLS.
Поэтому фактический выключенный deployment может отвечать gateway 502, а не 503.
Нельзя обещать, что штатный binary всегда обслуживает disabled API.

Источники: [ingest startup](../../../services/audio-ingest-service/cmd/main.go#L43),
[ingest fatal guard](../../../services/audio-ingest-service/cmd/main.go#L157),
[results conditional wiring](../../../services/results-service/cmd/main.go#L49),
[results required configuration](../../../services/results-service/internal/config/config.go#L20),
[workspace HTTPS policy](../../../services/audio-ingest-service/internal/infrastructure/workspace/http_access_checker.go#L20),
[workspace TLS startup](../../../services/workspace-service/cmd/main.go#L70),
[CPU overlay](../../../infra/docker-compose.cpu.yml#L1),
[summary configuration](../../../services/summarization-service/cmd/main.go#L16).

## 10. Отсутствующие, удалённые и внутренние API

| Состояние | API / функция | Подтверждение и правило для frontend |
|---|---|---|
| U | /voice-profiles/*: list/create/library/assign/embedding | Маршрутов и сервиса в текущем runtime нет; не создавать голосовые профили |
| U | POST /ingest/audio/upload и /anonymous | Заменены V2; fallback отсутствует |
| U | GET /ingest/audio/anonymous/{S}, speakers/{speaker}/fragment, POST …/confirm | Старые session/fragments/confirm удалены; новый session — U03 без speakers/confirm |
| U | GET /meetings/results/{A}/summary, /transcript, /audio | Старые downloads удалены; использовать R05/U04 |
| U | POST /meetings/results, POST /meetings/results/pending, PATCH /meetings/results/{A}/status | Внутренние legacy result writes удалены; frontend не создаёт/не меняет результаты |
| P, spec-only | GET /workspaces/{W}/meetings | Есть OpenAPI, нет регистрации/handler; обещанный body не подтверждён |
| P, spec-only | GET /meetings/{meeting_id} | Есть OpenAPI/Meeting schema, нет регистрации/handler; не использовать как готовое API |
| P | Live/SSE/WebSocket/progress stream | TASK-002.21 draft, выбора транспорта/endpoint ещё нет |
| Не найдено | Chat HTTP, chat history, пользовательский AI prompt endpoint | Backend использует LLM только для async summary; отдельного chat API не обнаружено |
| Не найдено | Public cancel/reprocess job, rename speakers, profile matching, server logout | Не придумывать методы и поля; U05/U06 не универсальная замена |

Удалённые пути обычно дают 404; через защищённый wildcard gateway запрос без JWT
может сначала получить 401. Наличие старых таблиц/примеров в истории не означает API.
Источники: [gateway profile retirement test](../../../services/gateway/internal/presentation/retired_profiles_test.go#L13),
[ingest retirement test](../../../services/audio-ingest-service/internal/presentation/router_test.go#L13),
[result retirement test](../../../services/results-service/internal/presentation/retired_results_test.go#L11),
[retirement task](../tasks/TASK-002.25.md), [runtime retirement](../tasks/TASK-002.20.md),
[live task](../tasks/TASK-002.21.md).

В auth-service существует **внутренний** `GET /auth/users/{id}`: 200
`{ "user_id": "...", "email": "..." }`; body/query отсутствуют, errors идут через
auth mapping (непустой id иначе 400). Он зарегистрирован до auth middleware,
но **gateway его не публикует**: это зависимость notification-service для lookup
owner email, не frontend `/me`. Источники:
[router](../../../services/auth-service/internal/presentation/router.go#L24),
[handler](../../../services/auth-service/internal/presentation/handlers/get_user_handler.go#L10),
[consumer](../../../services/notification-service/internal/infrastructure/auth/http_client.go).
Служебные /healthz, /readyz, /metrics worker не опубликованы через gateway.
Внутренние gRPC, NATS и model adapters также не являются клиентским HTTP API.

## 11. OpenAPI/Swagger: подтверждённые расхождения

Есть [contracts/api/openai.yml](../../../contracts/api/openai.yml), OpenAPI **3.0.3**,
18 операций. Swagger UI/HTTP endpoint выдачи spec в routers не найден.
Спецификация частично обновлена, но не может напрямую генерировать корректный
Flutter client без согласованного исправления. В этом исследовании spec не меняется.

| Область | OpenAPI | Реальный код |
|---|---|---|
| Server | localhost:8080 | Compose публикует gateway :8000; production origin неизвестен |
| Login | access_token | token |
| Register | 201 + user_id | 200 + message; user_id не возвращается |
| Refresh/change credentials | Не описаны | A03–A05 реализованы; new_password/new_email, refresh body {} |
| Workspace create | /workspaces, 201 | /workspaces/, 200; использовать канонический trailing slash |
| Workspace list/detail/update/delete | Не описаны | W01/W03/W04/W05 реализованы |
| Workspace owner field | Одна Workspace schema owner_user_id | Detail/update используют owner_id |
| Participants GET | Всегда array | Пустой ответ может быть null |
| Meeting list/detail | Описаны готовыми | Два spec-only endpoint без handler |
| Processing grants | Не описаны | U05/U06 зарегистрированы условно |
| SpeechStatus summary_error | Описан ограниченный список кодов | Worker может сохранять Failure.Code; handler передаёт строку без enum |
| Disabled V2 | 503 | Router так умеет, но main может выйти до HTTP startup |
| Results без artifact dir | Условное wiring не отражено | Router без handler умеет 404, но штатный config требует dir и останавливает процесс без него |
| Общее auth/error schema | Неполно/местами нет security | Gateway защищает все W/U/R; ошибки не всегда JSON |

После нормализации только trailing slash: 25 реализаций, 18 spec operations,
16 совпадающих операций; **9 реализованных операций отсутствуют в spec**,
**2 spec-only операции не реализованы**. Совпадение пути не означает совпадение
body/status. Canonical/V2 schemas полезны, но нужны source-driven проверки.
Тест [test_speech_api.py](../../../contracts/api/test_speech_api.py) проверяет
subset V2/canonical/retirement, не все auth/workspace контракты.

## 12. Незавершённые задачи и вопросы перед frontend

Текущие task frontmatter важнее исторических абзацев active-plan:

| Задачи | Текущий статус | Значение для контракта |
|---|---|---|
| .14/.15/.16/.20/.25/.30/.37 | accepted | Код документов/results/upload/retirement/notifications/delegation существует; это не live deployment receipt |
| .39/.41/.42 | accepted | Dataset/tooling этапы приняты; не следует копировать старое утверждение «.39 ещё draft» |
| .26 | accepted | Принят harness/provisional scope, не доказан итоговый model baseline |
| .29 | draft | Численные quality gates ещё требуют решения |
| .17 | draft | Полная CPU E2E quality/recovery приёмка не завершена |
| .24/.31 | blocked | Реальный cutover/production evidence не подтверждены |
| .18 | review | GPU реализация имеет отдельные hardware/acceptance ограничения; новых клиентских HTTP routes не даёт |
| .19/.21 | draft | Выбор будущего runtime и live-дизайн не готовые новые API |

Источники: [main plan](../plans/PLAN-002-speech-pipeline-rework.md),
[active-plan](../active-plan.md), [quality gates](../tasks/TASK-002.29.md),
[E2E](../tasks/TASK-002.17.md), [cutover](../tasks/TASK-002.24.md),
[production evidence](../tasks/TASK-002.31.md), [dataset](../tasks/TASK-002.39.md),
[GPU](../tasks/TASK-002.18.md), [future runtime](../tasks/TASK-002.19.md).

Перед реализацией frontend согласовать:

1. Реальный base_url/TLS, работоспособный тестовый deployment и новые issuer JWT;
   кто готовит нужные TLS/MinIO/workspace policy зависимости.
2. Используется ли исключительно перечисленный V2 flow; старый Flutter profile/
   speaker-confirm UX необходимо перепроектировать, но новый API не изобретать.
3. Какие операции account/workspace должны входить в клиент и как трактовать
   фактические пробелы проверки доступа W03, ошибку missing-workspace и контактное
   членство W06. Исправлять backend этим исследованием не разрешено.
4. Нужно ли согласованное отдельное обновление OpenAPI до генерации клиента.
   Два spec-only meeting endpoint исключить либо отдельно поставить задачу реализации.
5. Какие terminal UI states и клиентские deadlines/backoff допустимы, если
   projection/summary pending длительно; публичного model error detail/progress нет.
6. Нужны ли processing-grant actions в UI и откуда получить previous_grant_id;
   discovery/authorization_failure сейчас не опубликованы. Не отправлять догадки.
7. Политика хранения original/canonical/documents, удаления, повторной обработки
   и download filenames; 7-дневная session TTL не отвечает на все эти вопросы.
8. Нужен ли чат: backend chat API не существует. Выбор отдельной интеграции требует
   нового scope и решения о credentials; server summary не является chat API.

## 13. Verification и Result исследования

Source review: сопоставлены все HTTP routers gateway/auth/workspace/ingest/results,
handlers, wire DTO, storage/job projections, schemas, route/retirement/security
tests, runtime constructors и Compose. Имена endpoints и точные source citations
проверяются по этому snapshot. CodeGraph CLI/MCP/index в текущем окружении нет;
использованы rg и прямое чтение, установка/настройки не выполнялись.

### Выполненные проверки, 2026-10-24

| Проверка | Результат |
|---|---|
| Python 3 stdlib: существование 105 source links и диапазон каждого #L | PASS |
| Python 3 json: все 20 JSON-блоков документа | PASS; password/token примеры только placeholders |
| Ruby YAML.safe_load OpenAPI и разрешение 12 внутренних $ref | PASS; это синтаксическая/ref-проверка, не сертификация всей OpenAPI semantics |
| Source route inventory против таблицы документа и OpenAPI | PASS: 25/25 фактических операций описаны; spec 18, совпадают 16, отсутствуют в spec 9, spec-only 2 |
| `go test -mod=readonly . -count=1`, cwd contracts/speech | PASS, 0.411s; стандартный package suite, без DB/deployment |
| Одноразовый внешний Go verifier: JSON пример документа через backend speech.DecodeTranscript | PASS: 20 JSON blocks и 1 canonical example; постоянный тест/код в backend не добавлялся |
| Targeted gateway presentation/middleware tests | FAIL на setup до запуска test cases: нужных версий зависимостей нет в локальном module cache, запись download locks запрещена средой |
| Targeted auth presentation tests | FAIL на setup по той же причине; проверка поведения тестами в этой среде NOT RUN |
| Python `contracts/api/test_speech_api.py` | NOT RUN: в системном Python нет PyYAML/jsonschema; зависимости не устанавливались |
| DB/JetStream/MinIO/TLS/model/full E2E и живой HTTP API | NOT RUN; статические источники и package tests не заменяют такие проверки |
| `git diff --check`, полный no-index diff нового Markdown | PASS: изменяется только разрешённая документация |
| SHA-256 исходных tracked-файлов до/после | PASS: все 586 исходных файлов совпали, функциональный код и спецификация не изменены |

Go environment: go1.26.0 darwin/arm64; GOTOOLCHAIN=local, GOPROXY=off,
GOSUMDB=off, GOCACHE направлен во временный внешний каталог. Для успешного
contracts/speech также использован временный GOMODCACHE. Никакие зависимости
не скачивались/не обновлялись. Точные targeted команды, завершившиеся на setup,
выполнялись из соответствующих services/gateway и services/auth-service:

```sh
go test -mod=readonly ./internal/presentation/... -run 'Test(RouterJWTMiddleware|SpeechRoutesRequireJWTAndOverwriteSpoofedOwner|VoiceProfileRoutesAreRemoved|RequestID|RateLimit)' -count=1
go test -mod=readonly ./internal/presentation/... -run 'Test(Register_|Login_|Refresh_|Change|IssuerRejectsHeaderAndOldRefreshCredentials|LoginAndRefreshPreserveVerifiedIdentity)' -count=1
```

Код завершения этих двух команд — 1, причина относится к setup окружения, а не
подтверждённому падению HTTP assertions. Не обозначать их PASS или выполненными
integration tests. Загрузка зависимостей/изменение пользовательского окружения
для обхода ограничений не выполнялись.

### Независимый read-only review

- `/root/review_api_auth_workspace` не участвовал в написании документа;
  сверил §1–5, внутренний auth lookup, соответствующие spec расхождения и
  подсчёт операций. Findings не обнаружены. Проверка исходников/документа,
  без запуска runtime/DB/тестов и без записи файлов.
- `/root/review_api_async_results` независимо сверил §6–10 и связанные §11–12.
  Нашёл P2 в TXT-примере, P2 в описании обязательного results startup config
  и P3 в исключении idempotent replay U05. Автор исправил только документ.
  Повторная независимая сверка закрыла все три замечания; дополнительно
  подтверждены workspace TLS wiring и лимит artifact 50 MiB. Открытых findings
  в проверенном scope нет. Результаты тестов автора не выдаются за запуск reviewer.

Reviewer identities выше — идентификаторы агентов, не filesystem paths.
Review оценивает соответствие документа исходникам этого snapshot, не безопасность
или production readiness всего backend и не приёмку результата пользователем.

Результат — только этот документ; frontend и backend implementation/OpenAPI
не изменяются. Исходный untracked output/ сохраняется. Commit/push не выполняются.
