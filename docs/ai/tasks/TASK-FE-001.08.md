---
id: TASK-FE-001.08
plan: PLAN-FE-001
title: "Сверить auth API с действующим wire contract"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "1"
depends_on: ["TASK-FE-001.04", "TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07"]
backend_tasks: ["TASK-002.37"]
api_contracts: ["A01–A05"]
blocked_by: []
scope:
  - "lib/features/auth/data/auth_api.dart"
  - "lib/features/auth/data/dto/login_request.dart"
  - "lib/features/auth/data/dto/login_response.dart"
  - "lib/features/auth/data/dto/register_request.dart"
  - "test/features/auth/auth_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.08.md"
planned_paths:
  - "test/features/auth/auth_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.08: Сверить auth API с действующим wire contract

## Goal

Login/register и существующие account client methods точно соответствуют backend.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** token уже читается правильно; refresh не посылает {}, changePassword/changeEmail используют неверные keys.

**Целевое:** Login/register и существующие account client methods точно соответствуют backend.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.04](TASK-FE-001.04.md), [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.37
API: A01–A05.

## Этап и решение — 2026-11-02

Нужна: существующие A01–A05, без нового account settings экрана.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Сохранено token; register 200 message без user_id/автологина; refresh POST отправляет {} с действующим JWT.
- [x] Change fields — new_password/new_email; не добавляются old_password, refresh_token, logout или /me API.
- [x] Fixtures проверяют validation/conflict/unauthorized/non-JSON; frontend length checks не подменяют серверные byte limits.
- [x] Новый account settings экран не входит в эту задачу: адаптируются существующие методы, не создаётся дополнительный product scope.
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
`.dart_tool/codex-tools/flutter` Flutter 3.41.3 / Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Команда / сценарий | Actual | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/auth/auth_api_test.dart` | 20 tests passed | PASS, ScriptedAdapter + настоящие gateway/auth interceptors с plugin storage fakes |
| `dart analyze lib/features/auth/data test/features/auth/auth_api_test.dart` | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed lib/features/auth/data test/features/auth/auth_api_test.dart` | 5 files, 0 changed | PASS |
| Global analyze | Последний общий run: 13 прежних info prefer_const_constructors вне .08 | FAIL baseline, не clean global PASS |
| Live auth / account mutation | Не запускались | NOT RUN, backend/staging не изменяется, последующий .38/.40 |
| Независимый review .08-01 | [REVIEW-FE-001.08-01](../reviews/REVIEW-FE-001.08-01.md) reviewed/complete: independent 20tests/analyze/format PASS, findings нет | PASS |

Прочитаны реальные router, handlers login/register/refresh/change-email/change-password/
error_handling и service в `services/auth-service/internal/` backend SHA из Context.
Login/register передают исходные strings; backend byte validation не подменяется
Dart character length. UI и lifecycle остаются отдельной .09.

## Result

AuthApi соответствует пяти действующим операциям: token в login/refresh; register
200 message без auto-login/user_id; refresh JSON `{}`; account POST используют
new_password/new_email и 201. Никаких /me/logout/refresh_token/old_password или
нового account screen. LoginResponse отклоняет пустой/отсутствующий token;
malformed/non-JSON responses и HTTP ошибки преобразуются .07 mapper-ом без raw body.
Безопасные локальные AppException сохраняются. Wire fixtures охватывают все пять
методов, JWT/public routes, 400/401/403/404/409/429/500 и malformed success.

Изменены auth_api.dart/login_response.dart, добавлен auth_api_test.dart и обновлена
эта карточка. LoginRequest/RegisterRequest уже соответствовали wire и не менялись.
.04/05/06/07 prerequisites checked/reviewed; .01/.02 не переделывались.
Status review, independent review complete без findings, не accepted. Commit/push/merge нет.
