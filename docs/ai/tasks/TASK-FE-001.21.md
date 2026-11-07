---
id: TASK-FE-001.21
plan: PLAN-FE-001
title: "Добавить job status и anonymous session V2 контракты"
status: review
owner: /root/results_contracts
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07"]
backend_tasks: ["TASK-002.13", "TASK-002.15", "TASK-002.16"]
api_contracts: ["U03", "R03"]
blocked_by: []
scope:
  - "lib/features/results/data/speech_status_api.dart"
  - "lib/features/results/data/dto/speech_status_dto.dart"
  - "lib/features/record/data/dto/v2_session_dto.dart"
  - "test/features/results/speech_status_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.21.md"
planned_paths:
  - "lib/features/results/data/speech_status_api.dart"
  - "lib/features/results/data/dto/speech_status_dto.dart"
  - "lib/features/record/data/dto/v2_session_dto.dart"
  - "test/features/results/speech_status_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.21: Добавить job status и anonymous session V2 контракты

## Goal

Раздельные wire models для job/transcript/summary и session, query job_id.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Нет public speech status DTO; anonymous processing/confirmed enum старый.

**Целевое:** Раздельные wire models для job/transcript/summary и session, query job_id.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.13, TASK-002.15, TASK-002.16
API: U03, R03.

## Этап и решение — 2026-11-02

Нужна: действующие R03/U03; сохранены три непроверенных начатых файла.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

После review коррекции плана реализация продолжена в текущем API scope. DTO и клиент завершены, targeted tests/analyze/format PASS; независимый review и delta завершены, приёмка не заявляется.

## Acceptance criteria

- [x] R03 парсит все7 полей; job queued/running/completed/failed/cancelled, transcript pending/ready/failed/cancelled, summary pending/ready/failed не смешиваются.
- [x] U03 использует /ingest/v2/audio/anonymous/{session_id}, queued/running/ready/failed/cancelled/expired, confirm_required=false без fragments/speakers.
- [x] При pinned job_id query сохраняется; latest без query не выдаётся за историю версий.
- [x] Нет synthetic progress/stage/ETA/failure_stage/initial grant в DTO; неизвестные future значения дают безопасный diagnostic state, не ложный completed.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; finding F01 исправлен, review завершён, решение о приёмке остаётся владельцу.

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

Все команды из `/Users/verliiar/Desktop_application`, macOS 26.2, Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`; готовый pub-cache, `--no-pub`.
Flutter tests/analyze выполнялись с доступом к локальному кэшу/тестовому порту.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/results/speech_status_api_test.dart` | 13 tests passed: все состояния, независимая summary, open codes, unknown diagnostics, required/null keys, identity mismatch, HTTP/transport/storage errors, paths/query и отсутствие retries | PASS | ScriptedAdapter существующего API; не live backend |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/results/data/speech_status_api.dart lib/features/results/data/dto/speech_status_dto.dart lib/features/record/data/dto/v2_session_dto.dart test/features/results/speech_status_api_test.dart` | No issues found | PASS | Targeted analysis; не полный repo baseline |
| `.dart_tool/codex-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib/features/results/data/speech_status_api.dart lib/features/results/data/dto/speech_status_dto.dart lib/features/record/data/dto/v2_session_dto.dart test/features/results/speech_status_api_test.dart` | 4 files, 0 changes | PASS | Только scope |
| Backend source review: HEAD, speech_handler.go load/status, upload_v2_handler.go Session, db/upload_v2.go Session; OpenAPI и backend tests | SHA `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` совпадает снимку; wire fields/states/query подтверждены | PASS source review | Чтение не runtime test; backend не менялся |
| Полный diff scoped new files и карточки; whitespace | Проверен до передачи reviewer | PASS | Посторонний diff сохранён |
| Отдельная справочная `flutter --version` без доступа к кэшу | Ошибка записи telemetry session вне workspace; test/analyze выше прошли с доступом | FAIL | Не продуктовая проверка; SDK указан по установленному pinned toolchain |
| Live JWT/gateway/server persistence и macOS/Linux build/smoke | Не запускались | NOT RUN | Нет UI/platform изменений; real E2E относится к последующим задачам |
| Независимый review и F01 delta | [REVIEW-FE-001.21-01](../reviews/REVIEW-FE-001.21-01.md): reviewer независимо подтвердил 13 tests/analyze/format; F01 fixed, open findings нет | PASS | Review не подтверждает live backend и не является приёмкой |

## Result

Созданы `speech_status_api.dart`, `speech_status_dto.dart`, `v2_session_dto.dart` и
13 контрактных tests в `speech_status_api_test.dart`; обновлена только эта карточка.
SpeechStatusApi получает injected общий Dio и использует R03/U03, common error mapper,
сохраняет local auth/storage errors. Query job_id передаётся точно, null означает
latest; пустой/окружённый пробелами ID отклоняется. Path IDs кодируются, ответ другого
pinned job/session не принимается. Нет polling, retries, новых providers или UI wiring.

Семь полей R03 обязательны, nullable workspace_id/summary_error требуют наличия ключа.
Job/transcript/summary независимы; summary_error остаётся открытой строкой для safe
message mapper. Неизвестные состояния сохраняют raw value и дают unknown diagnostic,
не completed/ready. Terminal failure/cancel останавливают ожидание transcript;
completed с pending projection разрешает дальнейшее чтение. U03 строго требует
confirm_required=false; states queued/running/ready/failed/cancelled/expired отделены
от legacy, нет speakers/fragments/confirm API. Session ready не доказывает canonical.

Tests/analyze/format повторно PASS после исправления замечания независимого
reviewer: unknown summary не останавливает polling известного job/transcript.
Добавлен regression running/pending/future-summary → poll=true, без ready.
`hasUnknownStatus` сохраняется для diagnostics; guard ожидания касается только
job/transcript unknown и terminal failure. Независимый [delta review](../reviews/REVIEW-FE-001.21-01.md) подтвердил F01 fixed, других/open findings нет. Status review сохранён, accepted не выставлен.
Live доступность backend, auth runtime и платформы этим diff не подтверждены.
Backend, snapshots, dependencies, consumers, providers и router не менялись.
Commit/push/merge не выполнялись.
