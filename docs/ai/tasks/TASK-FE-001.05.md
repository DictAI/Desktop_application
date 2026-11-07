---
id: TASK-FE-001.05
plan: PLAN-FE-001
title: "Настроить явную конфигурацию gateway и сетевых политик"
status: review
owner: primary-agent
priority: P0
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01", "TASK-FE-001.02", "TASK-FE-001.03"]
backend_tasks: ["TASK-002.16", "TASK-002.28", "TASK-002.37"]
api_contracts: ["§2", "§9"]
blocked_by: []
scope:
  - "lib/core/network/api_client.dart"
  - "lib/core/config/app_config.dart"
  - "lib/shared/providers/providers.dart"
  - ".vscode/launch.json"
  - ".vscode/launch.example.json"
  - "docs/development/ENVIRONMENT.ru.md"
  - "test/core/config/app_config_test.dart"
  - "docs/ai/tasks/TASK-FE-001.05.md"
planned_paths:
  - "lib/core/config/app_config.dart"
  - "docs/development/ENVIRONMENT.ru.md"
  - "test/core/config/app_config_test.dart"
  - ".vscode/launch.example.json"
delivery_stage: current
---

# TASK-FE-001.05: Настроить явную конфигурацию gateway и сетевых политик

## Goal

Environment config без секретов в binary, корректный origin и отдельные upload/download/status timeouts.

Реализация явно выбрана пользователем 2026-10-26 в наборе .03–.07.
Переход внутри набора разрешён после checks/review; вне набора работы не выбираются.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Gateway URL захардкожен в providers; launch dart-define не читаются; единый receive timeout 30 s.

**Целевое:** Environment config без секретов в binary, корректный origin и отдельные upload/download/status timeouts.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md), [TASK-FE-001.02](TASK-FE-001.02.md), [TASK-FE-001.03](TASK-FE-001.03.md).
Backend traceability: TASK-002.16, TASK-002.28, TASK-002.37
API: §2, §9.

## Этап и решение — 2026-11-02

Сохранить gateway/TLS/origin/timeouts; только существующие backend API.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Готовая реализация/review и отмеченные AC сохраняются без повторной реализации; изменение только планирования.

## Acceptance criteria

- [x] API base URL читается из документированного dart-define; release не использует скрытый HTTP IP/default, HTTPS обязателен вне явно заданного local dev.
- [x] Проверяются origin/relative URLs: JWT не уходит на произвольные host из result URL; внешние ссылки не считаются signed public downloads.
- [x] Timeout и retry policy различают upload 15-min server context, polling и большие downloads; не обещается обход более короткого proxy timeout.
- [x] Взаимодействие идёт только через gateway; MinIO/NATS/gRPC/private metrics не становятся frontend dependencies.
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
из `/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`, PUB_CACHE
`/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`; существующие lock/pins сохранены.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter test --no-pub test/core/config/app_config_test.dart test/core/network/logging_test.dart` | 21 tests passed (17 config/policy + 4 logging regression) | PASS | Только synthetic/local fixtures, backend не вызывался |
| `dart analyze lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart lib/core/config/app_config.dart lib/core/network/api_client.dart lib/shared/providers/providers.dart test/core/storage test/core/config test/core/network` | No issues found | PASS | Изменённый scope .03–.05 |
| `dart format --output=none --set-exit-if-changed lib/core/config/app_config.dart lib/core/network/api_client.dart lib/shared/providers/providers.dart test/core/config/app_config_test.dart` | Формат применён; итоговый check в batch evidence | PASS | Только выбранные файлы |
| `flutter analyze --no-pub` | 13 прежних prefer_const_constructors info, 0 errors/warnings | FAIL | Неизменённые файлы вне scope, исходный долг не устранён |
| Redirect integration в app_config_test | Два ephemeral loopback HTTP servers: Bearer только первому, target requests=0 даже при caller followRedirects=true | PASS | Только локальный тест; не deployment/TLS проверка |
| Независимый review | [REVIEW-FE-001.05-01](../reviews/REVIEW-FE-001.05-01.md) reviewed/complete, включая delta fixture; findings P0–P3 нет | PASS | Не пользовательская приёмка |
| Live gateway, private CA и Linux/native build | Не запускались | NOT RUN | Нового API/CA/security bypass нет; native signing blocker .04 отдельно |

## Result

Реализованы AppConfig/API_BASE_URL, явный debug-only HTTP loopback opt-in,
HTTP_DIAGNOSTICS с release-deny, единый appConfigProvider. Удалён скрытый IP/default.
Gateway policy проверяет полный origin до чтения JWT, запрещает чужой host/port,
HTTP downgrade/userInfo/scheme-relative/backslash URLs и автоматические redirects.
Client имеет раздельные connect/ordinary/upload/download timeouts, не выполняет
автоматические retries и не обещает обход proxy timeouts.

Изменены api_client/shared providers, оба launch JSON только для явного local dev
opt-in; добавлены config, 17 tests и [инструкция окружения](../../development/ENVIRONMENT.ru.md).
Принятая .02 не переоткрыта: секреты не возвращены, исходный её scope не повторялся.
Параметры не содержат private CA, токены или credentials; TLS verification сохранён.
Без API_BASE_URL конфигурация явно отказывает при создании клиента, UI настроек не добавлен.
Feature clients/DTO/backend не менялись. Проверки кода и независимый review пройдены; не accepted, commit/push/merge не выполнялись.

Delta: test fixture использует официальные plugin mocks и прежний публичный storage API,
не зависит от новых migration interfaces .04. Повторные 21 tests/analyze/format PASS,
reviewer проверил delta отдельно. Подпись/OS blocker .04 не выдаётся за resolved.
