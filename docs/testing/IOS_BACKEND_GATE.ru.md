# Backend gate для iPhone E2E

Подготовка TASK-FE-002.18, 2026-11-18. В этом проходе backend изучен read-only;
HTTP/audio операции, deployment, provisioning и новые backend задачи не выполнялись.
Фактический device/backend E2E **NOT RUN**.

## Проверенный source baseline

Backend checkout `/Users/mxdnght/dictai`, HEAD
`92ad6e4572a3b12a601ba3ab7e5cc385a21694ae`; `git status --short` показывает
посторонние untracked API-client docs, которые не менялись этим аудитом.
В репозитории есть `.codegraph`, но `codegraph explore` недоступен (exit127),
поэтому текущие contracts/routes прочитаны через fallback source search.
Исторические BACKEND_* snapshots frontend не заменяют этот source baseline.

Сверены `docs/api-client-flow.ru.md`, gateway/auth/ingest/results routers,
`infra/speech-cpu.md`, `infra/staging/README.md`, Compose overlays и runtime README.
Это source evidence, не подтверждение развёрнутого origin или его SHA.

## До разрешённого runtime прогона

| Gate | Что обязан подтвердить оператор | Текущее состояние |
|---|---|---|
| Origin/access | Разрешённый HTTPS test-origin, проверяемая CA/hostname chain, оператор и тестовые A/B credentials вне Git | Для нового полного iPhone E2E не подтверждено |
| Deployment | Фактический deployed SHA/image digests/configuration version, V2 upload gate enabled, worker readiness и model revisions/digests | Не проверено runtime |
| Data/storage | PostgreSQL migration version/clean schema, NATS, MinIO versioned source, protected grants, durable speech artifacts и retention/backup | Не проверено runtime |
| TLS/services | Verified DB/auth/workspace/MinIO, source mTLS, client principals и grants, readable files для runtime UID | Не проверено runtime |
| Models/resources | Offline pinned ASR+Community-1 weights, лицензии/access terms, CPU/GPU profile и согласованный resource envelope | Не проверено runtime |
| Summary | Разрешённый provider/config или ожидаемый explicit not_configured; transcript остаётся доступным независимо | Не проверено runtime |
| Test policy | Два аккаунта, workspace A, fixtures и cleanup plan; без production data/SMTP реальным третьим лицам | Не подтверждено для нового прогона |

CPU guide задаёт default upload gate503 и migrations through10; STG guide
описывает forward validation through11. Использовать фактический актуальный
schema/application compatibility evidence оператора; не применять миграции
по этому frontend harness и не считать строку10 достаточной без сверки.
STG small-host profile5GiB/scratch2GiB не подтверждает Linux8GiB/2h envelope.
Исторический synthetic STG smoke и готовый API-client helper не доказывают
текущую readiness, hardware E2E или качество распознавания.

## Контракт существующего flow

Все API через общий gateway с Bearer JWT; клиент не задаёт `X-User-Id`.
Anonymous означает owner-only без workspace, JWT остаётся обязательным.

| Шаг | Существующий route / результат |
|---|---|
| Auth | `POST /auth/register`, `/auth/login`, `/auth/refresh`; login200/token |
| Workspace | `/workspaces/` и participants; contacts не идентифицируют speakers |
| Upload | `POST /ingest/v2/audio/upload` с workspace_id либо `/upload/anonymous` без workspace_id; multipart audio + language/mixed; Idempotency-Key |
| Accepted | HTTP202 с audio_id/job_id/processing_version/status_url; session_id UUID для owner-only, null для workspace |
| Status | `GET /meetings/results/{audio_id}/speech-status?job_id=...`; transcript/summary независимы |
| Canonical | `GET /meetings/results/{audio_id}/structured?job_id=...`; 200 canonical, 202 ещё не готов; no_speech успешен |
| Export | `GET /meetings/results/{audio_id}/documents/{transcript.txt,transcript.pdf,summary.txt,summary.pdf}?job_id=...` |
| Original | `GET /ingest/v2/audio/{audio_id}/original`; 404 также для недоступного/чужого/expired ресурса |
| Library/delete | `GET /meetings/results`, `DELETE /meetings/results/{audio_id}`; удаление скрывает V2 versions, не обещает физическую очистку всех backend objects/checkpoints |

Полный upload path owner-only: `/ingest/v2/audio/upload/anonymous`.
Один retry сохраняет bytes/options/key; новый файл/опции с прежним key409.
400/401/403/429(+Retry-After)/503 не переводят на legacy endpoints. 202 не равен
готовому transcript. RIFF PCM/float WAV <=1GiB/2h, runtime8–192kHz/1–8channels;
конкретный resource envelope требует реального measurement, не только validator.
После неизвестного исхода upload server side work может продолжаться, даже когда
клиент отменил запрос; не выдавать local cancellation за server deletion.

## Сохранённые границы безопасности и выпуска

`services/workspace-service/internal/presentation/handlers/get_workspace_handler.go`
читает непустой trusted `X-User-Id`, затем вызывает `GetWorkspace(workspaceID)`
без caller ID. Frontend cleanup или скрытая кнопка не исправляют этот server-side
access gap; реальный A/B denial требует отдельного evidence. Не создавать здесь
backend fix/task и не считать UI isolation доказательством workspace security.

Auth router и gateway source не содержат удаления аккаунта HTTP. `DeleteUser`
существует только в repository/DB helper, без HTTP capability. Result deletion,
logout и local Keychain cleanup не удаляют аккаунт. Это release gap для
[Store подготовки](IOS_RELEASE.ru.md), не основание придумать endpoint.

Runtime evidence фиксировать по [device harness](IOS_DEVICE_E2E.ru.md), включая
origin approval, backend SHA и реальные PASS/FAIL/NOT RUN. Операторские секреты,
audio/transcript и full response bodies не коммитить.
