---
id: TASK-FE-001.06
plan: PLAN-FE-001
title: "Подготовить тестовую основу без сети и аппаратуры"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "0"
depends_on: ["TASK-FE-001.01"]
backend_tasks: []
api_contracts: []
blocked_by: []
scope:
  - "test/widget_test.dart"
  - "test/support/test_app.dart"
  - "test/support/fakes.dart"
  - "docs/testing/README.ru.md"
  - "docs/ai/tasks/TASK-FE-001.06.md"
planned_paths:
  - "test/support/test_app.dart"
  - "test/support/fakes.dart"
  - "docs/testing/README.ru.md"
delivery_stage: current
---

# TASK-FE-001.06: Подготовить тестовую основу без сети и аппаратуры

## Goal

Повторяемые unit/widget проверки через Riverpod overrides, fake Dio/capture/storage и управляемое время.

Реализация явно выбрана пользователем 2026-10-26 в наборе .03–.07.
Переход внутри набора разрешён после checks/review; вне набора работы не выбираются.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** widget_test.dart пустой; unit/widget fixtures и overrides отсутствуют.

**Целевое:** Повторяемые unit/widget проверки через Riverpod overrides, fake Dio/capture/storage и управляемое время.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.01](TASK-FE-001.01.md).
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: нет новых API.

## Этап и решение — 2026-11-02

Сохранить unit/widget test fakes существующих API/оборудования; это не runtime mock будущей бизнес-функции.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

Готовая реализация/review и отмеченные AC сохраняются без повторной реализации; изменение только планирования.

## Acceptance criteria

- [x] Пустой тест заменён содержательным app/router smoke без реального API, Keychain, микрофона и subprocess.
- [x] Документированы команды и override boundaries; тесты не используют реальные ключи, аудио и домашние пути.
- [x] Fakes позволяют задержанные ответы, 401, non-JSON/bytes, late completion/dispose и контролируемый polling без flaky sleep.
- [x] Новые test packages не добавляются без необходимости; сначала используются flutter_test и существующие dependencies.
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
`/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`. Новые packages не добавлены.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter test --no-pub test/widget_test.dart --timeout 20s` | 6 tests passed | PASS | App/router/auth реальные, HTTP/storage/capture только fakes |
| Первые widget attempts | Одиночный pump проверял запрос слишком рано; ожидание события из другой clock zone зависало и было остановлено | FAIL → PASS | Исправлена только test orchestration; bounded virtual pumps без sleep |
| `dart analyze test/widget_test.dart test/support` | No issues found | PASS | Итог после test orchestration дополнительно проверяется в batch |
| `dart format --output=none --set-exit-if-changed test/widget_test.dart test/support` | Формат применён; итоговый check в batch evidence | PASS | Три scoped Dart файла |
| `flutter analyze --no-pub` | 13 прежних prefer_const_constructors info, 0 errors/warnings | FAIL | Baseline, не устраняется тестовой задачей |
| Независимый review | [REVIEW-FE-001.06-01](../reviews/REVIEW-FE-001.06-01.md) reviewed/complete, findings P0–P3 нет | PASS | Независимо повторены 6 tests/analyze/format |
| Native/capture/backend smoke | Не запускались | NOT RUN | Mock isolation не platform evidence |

## Result

Пустой widget_test заменён шестью содержательными проверками: настоящий app/router
unauth guard и переход к защищённому Results, валидация формы без HTTP, задержанный
401 до реального AuthState/error UI, text error и binary response через Dio,
виртуальный polling/dispose/late response, fake capture stop после dispose.
Test-only polling probe не является реализацией product polling.

Добавлены [test_app](../../../test/support/test_app.dart),
[fakes](../../../test/support/fakes.dart) и [инструкция](../../testing/README.ru.md).
ProviderScope заменяет IO boundaries; официальные storage mock APIs работают
в памяти и сбрасываются между тестами. Это не зависит от новых внутренних storage
interfaces .04: используются совместимые публичные методы. Native blocker .04
не блокирует эту тестовую основу. Adapter никогда не открывает сокет вместо fixture.
Capture fake задаёт test-only boundary; его подключение к RecordNotifier остаётся
будущей .15. Аппаратный Record экран в smoke не открывается. Router/container/Dio
освобождаются, реальные ключи/аудио/домашние пути не используются.

Новых production source/API/dependencies нет. Код тестовой основы и независимый review завершены, не accepted. Commit/push/merge не выполнялись.
