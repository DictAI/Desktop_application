---
id: TASK-FE-001.26
plan: PLAN-FE-001
title: "Закрепить V2 results list и pagination data"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07"]
backend_tasks: ["TASK-002.15", "TASK-002.20"]
api_contracts: ["R01", "R02"]
blocked_by: []
scope:
  - "lib/features/results/data/results_api.dart"
  - "lib/features/results/data/dto/result_dto.dart"
  - "lib/features/results/data/dto/results_page_dto.dart"
  - "test/features/results/results_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.26.md"
planned_paths:
  - "lib/features/results/data/dto/results_page_dto.dart"
  - "test/features/results/results_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.26: Закрепить V2 results list и pagination data

## Goal

Current list DTO с pagination/latest-job semantics без серверных придуманных filters.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** R01 и delete routes уже совпадают; pagination envelope теряется, legacy downloads ещё в ResultsApi.

**Целевое:** Current list DTO с pagination/latest-job semantics без серверных придуманных filters.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.15, TASK-002.20
API: R01, R02.

## Этап и решение — 2026-11-02

Нужна: серверный Results/pagination, без нового workspace filter API.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] result_id=job_id; anonymous workspace_id/name empty strings; list status pending/done/failed не равен summary state.
- [x] Сохраняются pagination metadata, date query UTC и empty data=[]; limit>100 resets20 учтён, workspace_id filter не добавляется.
- [x] Существующие consumers остаются собираемыми до .27; legacy download methods удаляются после переключения consumers в .33, без backend compatibility flow.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

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

2026-11-03, cwd `/Users/verliiar/Desktop_application`, macOS arm64,
SDK `.dart_tool/codex-tools/flutter` Flutter 3.41.3/Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.
Зависимости не менялись. HTTP tests используют изолированный ScriptedAdapter,
не реальную запись/публичный сервер. Real API/E2E остаются .38–.40.

| Команда / сценарий | Actual | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/results/results_api_test.dart` | 21 tests passed | PASS: pagination/job IDs/anonymous/dates/limit reset/204/errors/malformed/cancel |
| `dart analyze lib/features/results/data/results_api.dart lib/features/results/data/dto/result_dto.dart lib/features/results/data/dto/results_page_dto.dart test/features/results/results_api_test.dart` | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed` для тех же четырёх файлов | 4 files, 0 changed | PASS |
| Global `flutter analyze --no-pub` | Последний общий run .18: 13 прежних prefer_const_constructors info вне .26; отдельный .26 scope чист | FAIL baseline; не clean global PASS |
| Независимый review .26-01 | [REVIEW-FE-001.26-01](../reviews/REVIEW-FE-001.26-01.md) reviewed/complete | PASS, независимо 21 tests/analyze/format и сверка источников |

Источники сверены read-only на backend SHA из Context:
`services/results-service/internal/presentation/handlers/result_handler.go`,
`internal/service/result_service.go`, `internal/domain/result.go` и
`internal/infrastructure/persistence/postgres_result_repository.go` относительно
`services/results-service/` (для `internal/...`). R01 projection latest job/owner
остаётся серверной логикой, не повторяется клиентом. List done не summary ready.

## Result

Добавлен getResultsPage с immutable data и реальными pagination metadata;
getResults оставлен совместимым адаптером для существующего UI до .27.
DateTime bounds отправляются UTC RFC3339, limit>100 явно нормализуется к серверным
20; workspace filter не выдуман. ResultDto строго читает wire strings и дату,
сохраняет empty anonymous поля/документ URL и неизвестное будущее status без
выдуманной готовности. result_id сохраняет job identity, а audio_id — отдельное поле.

R02 использует encoded audio_id, подтверждает 204; cancellation и .07 safe mapper
сохраняют причину без технических body. Malformed 200 становится invalidResponse.
Legacy download методы сохраняются до переключения consumers/.33, новых retired
fallback routes не добавлено. Изменены только пять scope-файлов этой задачи.
Текущий UI не считается уже переведённым на pagination или новые downloads.

Status review. Независимый review завершён без замечаний. Приёмка владельцем ожидается. Commit/push/merge нет.
