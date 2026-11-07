---
id: TASK-FE-001.10
plan: PLAN-FE-001
title: "Закрепить workspace/contact DTO и CRUD-контракты"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "1"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07"]
backend_tasks: ["TASK-002.25", "TASK-002.30"]
api_contracts: ["W01–W09"]
blocked_by: []
scope:
  - "lib/features/workspace/data/workspace_api.dart"
  - "lib/features/workspace/data/dto/workspace_dto.dart"
  - "lib/features/workspace/data/dto/participant_dto.dart"
  - "test/features/workspace/workspace_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.10.md"
planned_paths:
  - "test/features/workspace/workspace_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.10: Закрепить workspace/contact DTO и CRUD-контракты

## Goal

Сохранить совместимые части и покрыть весь существующий CRUD без ложной membership модели.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** WorkspaceDto уже принимает owner_user_id/owner_id; nullable participants уже превращаются в []; ParticipantDto ещё содержит optional voiceProfileId.

**Целевое:** Сохранить совместимые части и покрыть весь существующий CRUD без ложной membership модели.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.25, TASK-002.30
API: W01–W09.

## Этап и решение — 2026-11-02

Сохранить reviewed W01–W09; local voiceProfileId compatibility удалится в .11, именование не добавлять.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Готовая реализация/review и отмеченные AC сохраняются без повторной реализации; изменение только планирования.

## Acceptance criteria

- [x] Fixtures подтверждают owner field variants, created_at, pagination и null/[] participants; уже корректные branches не переписываются ради стиля.
- [x] API использует канонический /workspaces/ и name/email; profile field удаляется согласованно с consumers в .11, не ломая промежуточный build.
- [x] 403/404/500 и missing workspace не маскируются догадками; контакт не объявляется authenticated user/role.
- [x] Никаких /workspaces/{id}/meetings и invitations endpoints: они не подтверждены реализацией.
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

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, Flutter 3.41.3/Dart 3.11.1
из `.dart_tool/codex-tools/flutter`, PUB_CACHE `/Users/verliiar/.pub-cache`.
Зависимости/lock не обновлялись; backend только read-only source verification.

| Проверка | Actual | Статус/граница |
|---|---|---|
| `flutter test --no-pub test/features/workspace/workspace_api_test.dart --reporter expanded` | 23 tests passed | PASS, synthetic HTTP fixtures без backend/storage |
| `dart analyze lib/features/workspace/data test/features/workspace/workspace_api_test.dart` | No issues found после устранения 2 style info | PASS, предыдущий INFO сохранён как история |
| `dart format --output=none --set-exit-if-changed lib/features/workspace/data test/features/workspace/workspace_api_test.dart` | 4 files, 0 changed | PASS |
| W01–W09 handlers/service/DTO/backend snapshot | canonical paths, owner variants, fractional dates, null contacts и 200 CRUD сверены | PASS source review, не runtime |
| Native/Linux/live API smoke | Не запускались | NOT RUN; data-only scope |
| Независимый review | [REVIEW-FE-001.10-01](../reviews/REVIEW-FE-001.10-01.md) reviewed/complete | PASS, независимые 23 tests/analyze/format |

## Result

Реализованы безопасные W01–W09 wrappers через общий error mapper; HTTP 500 missing
workspace не переименовывается в 404, raw body не показывается. Не-JSON/неполные
ответы становятся AppException вместо TypeError. Существующий list API сохранён;
getWorkspacesPage и типизированная pagination используют только действующие wire
поля. Запросы ограничены page>=1, limit=1..100 из-за известного backend mismatch.
Path IDs экранируются; auth остаётся в общем Dio, retries/новых API нет.

Прежние owner field variants/date parsing сохранены. Контакт — name/email, не user
или роль. voice_profile_id не читается/не пишется в wire; optional локальный getter
и copyWith сохранены только для промежуточной совместимости до удаления consumers
в .11. Invitations/workspace meetings/voice API не добавлялись. Изменены только
scope пути .10, плюс учёт coordinator. Независимый review завершён, open findings нет; приёмка владельца ожидается.
