---
id: TASK-FE-001.07
plan: PLAN-FE-001
title: "Унифицировать безопасную обработку HTTP и транспортных ошибок"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.03", "TASK-FE-001.05", "TASK-FE-001.06"]
backend_tasks: []
api_contracts: ["§2", "U01", "U05", "R03", "R05"]
blocked_by: []
scope:
  - "lib/core/error/app_exception.dart"
  - "lib/core/network/api_error_mapper.dart"
  - "test/core/network/api_error_mapper_test.dart"
  - "docs/ai/tasks/TASK-FE-001.07.md"
planned_paths:
  - "lib/core/network/api_error_mapper.dart"
  - "test/core/network/api_error_mapper_test.dart"
delivery_stage: current
---

# TASK-FE-001.07: Унифицировать безопасную обработку HTTP и транспортных ошибок

## Goal

Общая классификация сети/status без угадывания единого backend error enum.

Реализация явно выбрана пользователем 2026-10-26 в наборе .03–.07.
Переход внутри набора разрешён после checks/review; вне набора работы не выбираются.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Feature-клиенты делают небезопасные as Map casts; пустой/text/bytes error способен вызвать TypeError вместо AppException.

**Целевое:** Общая классификация сети/status без угадывания единого backend error enum.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.03](TASK-FE-001.03.md), [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: §2, U01, U05, R03, R05.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Реализация выбрана 2026-10-26.

Будущие assignment/export ошибки не добавлять в действующий wire enum до согласования. Маппер не реализует саму retry-команду.

## Этап и решение — 2026-11-02

Сохранить error mapper; не добавлять ошибки несуществующего assignments API.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Готовая реализация/review и отмеченные AC сохраняются без повторной реализации; изменение только планирования.

## Acceptance criteria

- [x] Каждое сообщение объясняет подтверждённую причину и предлагает только доступное действие: безопасный GET retry, тот же upload replay либо login. Кнопок server reprocess/cancel/summary regeneration без API нет.
- [x] Нормализуются пустой body, JSON error, text/html и byte error; raw technical messages не показываются пользователю.
- [x] Отдельно различаются 400/401/403/404/409/429/500/502/503, timeout, offline и incomplete transfer; Retry-After не предполагается обязательным.
- [x] Unknown summary_error не ломает parsing; 202 status, document 404 и artifact 503 не сводятся к одинаковому «не найдено».
- [x] Классификация не выполняет automatic reprocess/cancel/reissue и не меняет API wire.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и ожидаемая приёмка владельца зафиксированы.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64; Flutter 3.41.3/Dart 3.11.1,
SDK `/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`, PUB_CACHE
`/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`. Зависимости неизменны.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter test --no-pub test/core/network/api_error_mapper_test.dart` до TLS delta | 30 tests passed | PASS, исторический | После F01 актуальный evidence — полный batch ниже |
| `flutter test --no-pub --reporter expanded` после TLS delta | 72 tests passed во всём suite, включая 31 mapper test | PASS | Synthetic/error fixtures; loopback runner с разрешённым доступом |
| `dart analyze lib/core/error/app_exception.dart lib/core/network/api_error_mapper.dart test/core/network/api_error_mapper_test.dart` | No issues found | PASS | Существующие exception constructors совместимы |
| `dart format --output=none --set-exit-if-changed lib/core/error/app_exception.dart lib/core/network/api_error_mapper.dart test/core/network/api_error_mapper_test.dart` | Формат применён; итоговая проверка в batch evidence | PASS | Только выбранные файлы |
| Контракты R03/R04/R05/U01/U05 и gateway rate limit | Сверены снимок и текущие speech_handler.go, upload_v2_handler.go, ratelimit.go backend | PASS source review | Не runtime test; backend не менялся |
| Независимый review и F01 delta | [REVIEW-FE-001.07-01](../reviews/REVIEW-FE-001.07-01.md), независимые 31 tests/analyze/format PASS | PASS | F01 подтверждён reviewer как fixed; приёмка владельца ожидается |
| Live gateway/model/export, native/Linux | Не запускались | NOT RUN | Не scope общего классификатора |

## Result

Добавлены локальные ApiFailureKind/ApiRecoveryAction/ApiFailure без изменения wire
или прежних constructors; ApiErrorMapper.fromDio возвращает безопасную классификацию
HTTP/transport с immutable набором доступных действий. Никаких команд/retries/storage
или навигации он не выполняет. POST replay возможен только когда caller явно
подтвердил существующую durable V2 отправку с теми же bytes/metadata/idempotency key;
обычные mutations, 400/403/404/409 и TLS/policy нарушения такой возможности не получают.

Пустые/JSON/text/html/bytes ошибки не cast-ятся к Map без проверки; сырые сообщения,
URL/headers/exception details в UI не копируются. Различаются HTTP коды, локальный
cancel, timeout, network, TLS и подтверждённая caller-ом неполная передача.
Document 404 узнаётся только по документированному marker и context, artifact 503
отдельно от result 404. Retry-After необязателен, принимает seconds/date, неверные
значения игнорируются. Complete 2xx/202 не ошибка: DTO/job status обрабатывает будущий
consumer, failed/cancelled 202 не превращается в бесконечное ожидание.

summaryFailureMessage принимает open/unknown code без закрытого backend enum и
показывает фиксированный безопасный fallback. Новых assignment/export wire errors
не добавлено. Дополнены app_exception, добавлены mapper и 31 test; fixtures читаются
из уже проверенной .06. После review F01 добавлен 31-й mapper test: стандартные
IO TlsException/HandshakeException (Dio unknown) и badCertificate имеют приоритет
над incompleteTransfer и не предлагают retry/replay даже с recovery context.
Полный suite после исправления — 72 PASS, targeted analyze — PASS.
Независимый reviewer повторил 31 mapper test/analyze/format, F01 подтверждён как
fixed; новых/open code findings нет. Это не снимает отдельный B01 native smoke .04.
Клиенты/DTO/экраны не переключены на mapper: это scope .08+
и соответствующих API-задач. Нынешние feature error casts пока остаются известным
долгом до этих задач. Code review завершён, не accepted. Commit/push/merge не выполнялись.
