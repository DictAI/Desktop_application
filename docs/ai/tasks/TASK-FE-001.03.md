---
id: TASK-FE-001.03
plan: PLAN-FE-001
title: "Ограничить HTTP-логирование и редактировать чувствительные данные"
status: review
owner: primary-agent
priority: P0
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01"]
backend_tasks: []
api_contracts: ["§2"]
blocked_by: []
scope:
  - "lib/core/network/api_client.dart"
  - "test/core/network/logging_test.dart"
  - "docs/ai/tasks/TASK-FE-001.03.md"
planned_paths:
  - "test/core/network/logging_test.dart"
delivery_stage: current
---

# TASK-FE-001.03: Ограничить HTTP-логирование и редактировать чувствительные данные

## Goal

Безопасные диагностические метаданные с debug opt-in; секретные заголовки/тела не печатаются.

Реализация явно выбрана пользователем 2026-10-26 в наборе .03–.07.
Переход внутри набора разрешён после checks/review; вне набора работы не выбираются.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** LogInterceptor всегда печатает request/response bodies, включая auth и потенциальные transcripts.

**Целевое:** Безопасные диагностические метаданные с debug opt-in; секретные заголовки/тела не печатаются.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: §2.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Реализация выбрана 2026-10-26.

Политика относится и к будущим назначениям .43–.51; новый logger/API не добавляется.

## Этап и решение — 2026-11-02

Сохранить реализацию безопасных логов; запрет sensitive data не требует реализации назначений.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Готовая реализация/review и отмеченные AC сохраняются без повторной реализации; изменение только планирования.

## Acceptance criteria

- [x] Имена, contact IDs, assignment drafts и ответы будущего API не попадают в body/error logs; тесты используют только synthetic markers.
- [x] В release body/token/password/аудио/transcript logging отключён; debug не раскрывает Authorization/cookies/credentials.
- [x] Тест перехвата лога доказывает отсутствие синтетических secret markers при login, multipart, JSON/error/bytes и debug/release policy.
- [x] Сохраняется correlation по безопасному request ID/status без raw server errors и повторного логирования через catch.
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

2026-10-26, cwd `/Users/verliiar/Desktop_application`, macOS arm64;
Flutter 3.41.3/Dart 3.11.1 из уже принятой .01, отдельный прежний PUB_CACHE.
Повторного выбора/проверки toolchain .01 нет. Offline pub get --enforce-lockfile
только подготовил отсутствовавший .dart_tool, dependency pins не менялись.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter test --no-pub test/core/network/logging_test.dart` | 4 tests passed: debug opt-in/off, simulated release-deny, JSON/multipart/bytes/error/transport, request correlation и sink failure | PASS | Runner потребовал разрешение loopback; backend/сеть подменены adapter |
| Первые test attempts | Sandbox запретил runner socket; затем fixture с query внутри path вызвал storage binding error. Fixture исправлен на queryParameters, повтор выше PASS | FAIL → PASS | Ошибка fixture не скрыта; auth/router implementation вне .03 не менялся |
| `dart format --output=none --set-exit-if-changed lib/core/network/api_client.dart test/core/network/logging_test.dart`; targeted `dart analyze` тех же файлов | Проверка выбранных файлов | PASS | Global baseline отдельно |
| `flutter analyze --no-pub` | 13 прежних prefer_const_constructors info, 0 errors/warnings; новых diagnostics нет | FAIL baseline | Чужой code style не исправляется |
| Полный baseline diff/scope и независимый review | REVIEW-FE-001.03-01 reviewed/complete, 4 tests/analyze/format независимо повторены | PASS | Не пользовательская приёмка |

## Result

Изменены только `lib/core/network/api_client.dart`, новый
`test/core/network/logging_test.dart` и учёт этой карточки/coordinator.
LogInterceptor удалён. Debug diagnostics opt-in: только locally generated numeric
request ID, allowlisted method и bounded HTTP status. URL/path/query, headers,
body/bytes, raw exceptions, имена/контакты/credentials не читаются logger.
Release compile guard не позволяет включить diagnostics; sink error не меняет HTTP.
Общий auth interceptor и wire не менялись. Independent REVIEW-FE-001.03-01 завершён без actionable findings;
status review не означает accepted или разрешение commit/push.

## Integration test delta — 2026-11-06

Общий unit run выявил 3 FAIL logging fixture, поскольку защищённый request .03
после .04 обращался к неподменённому OS Keychain. В прежнем scope test setup
добавляет существующие storage fakes и синтетический token marker. Production
logger/storage не меняются, проверки чувствительных JSON/multipart/headers/error
остаются. Все 4 теста logging проходят, scoped analyze и format чисты. Независимый
[REVIEW-FE-001.03-02](../reviews/REVIEW-FE-001.03-02.md) завершён 2026-11-07.
Замечаний нет. Cwd `/Users/verliiar/Desktop_application`, pinned Flutter 3.41.3,
`flutter test --no-pub test/core/network/logging_test.dart --reporter expanded`.
