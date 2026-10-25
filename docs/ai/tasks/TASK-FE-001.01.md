---
id: TASK-FE-001.01
plan: PLAN-FE-001
title: "Согласовать и воспроизвести Flutter/Dart toolchain"
status: review
owner: primary-agent
priority: P0
readiness_category: A
phase: "0"
depends_on: []
backend_tasks: []
api_contracts: []
blocked_by: []
scope:
  - "pubspec.yaml"
  - "pubspec.lock"
  - "docs/development/TOOLCHAIN.ru.md"
  - "docs/ai/tasks/TASK-FE-001.01.md"
planned_paths:
  - "docs/development/TOOLCHAIN.ru.md"
---

# TASK-FE-001.01: Согласовать и воспроизвести Flutter/Dart toolchain

## Goal

Один проверенный совместимый SDK и согласованные ограничения без случайного обновления dependency graph.

Пользователь явно выбрал реализацию .01 и .02 2026-10-25. Эта карточка выполняется
в ветке `codex/TASK-FE-001.01-toolchain` от `fdd95eb`; другие implementation-задачи
не выбраны. Commit/push/merge новых результатов этим поручением не разрешены.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** pubspec допускает Dart 3.3/Flutter 3.19, lock требует Dart >=3.11/Flutter >=3.35.6; установлен Flutter 3.38.1 с Dart 3.10.0.

**Целевое:** Один проверенный совместимый SDK и согласованные ограничения без случайного обновления dependency graph.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: нет.
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: нет новых API.

## Acceptance criteria

- [x] Зафиксированы точная версия Flutter с bundled Dart >=3.11, способ получения и требования macOS/Linux; конкретная версия выбрана по реально доступному SDK, не выдумана планом.
- [x] pubspec/lock согласованы; предпочтён совместимый SDK с существующим lock, изменения packages только при доказанной необходимости и явном scope.
- [x] Сняты исходные analyze/test/format результаты с разделением старых проблем и новых; пустой widget_test не считается покрытием.
- [x] Изменения host SDK/установка инструментов выполняются только при разрешённой среде; отсутствие SDK остаётся явным blocker.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
SDK/lock changes ограничены воспроизводимостью, не общим обновлением libraries.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd: `/Users/verliiar/.codex/worktrees/fe-001-01-toolchain/Desktop_application`.
2026-10-25, macOS 26.2 arm64. Временный SDK:
`/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter` (Flutter 3.41.3,
Dart 3.11.1); отдельный PUB_CACHE:
`/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`.
Flutter-команды выполнялись с `FLUTTER_SUPPRESS_ANALYTICS=true CI=true` и этим
PUB_CACHE; ниже `flutter`/`dart` — binaries именно этого SDK.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| Официальные release manifests, SHA-256 macOS arm64 ZIP; `flutter --version --machine`, `dart --version` | Среда выше | Проверенный Flutter с Dart >=3.11 | Flutter 3.41.3 / Dart 3.11.1; revision `48c32af0345e9ad5747f78ddce828c7f795f7159`, SHA совпал | PASS | Системный Flutter 3.38.1 не изменён; временный SDK не входит в Git |
| `flutter pub get --enforce-lockfile`; SHA-256 и package graph comparison lock с базой fdd95eb | Среда выше, отдельный cache; 128 cached packages скопированы, 5 недостающих получены из pub.dev | Те же dependency pins | Exit 0; 137 packages, lock побайтово неизменен | PASS | Сообщения о 90 newer versions не являются обновлением; lock SDK minima производятся resolved packages, требования root дополнительно заданы pubspec |
| `flutter analyze --no-pub` | Среда выше, исходный lib/test не менялся | Снять честный baseline | Exit 1: 13 prefer_const_constructors info; 0 errors, 0 warnings | FAIL baseline | Замечания исходного кода не исправлялись; это не зелёный analyze |
| `flutter test --no-pub` | Среда выше, исходный test/widget_test.dart — 0 bytes | Снять честный baseline | Exit 1: Undefined name main в generated test listener | FAIL baseline | Исходный пустой тест не является покрытием; тестовая основа — отдельная .06 |
| `dart format --output=none --set-exit-if-changed lib test` | Dart 3.11.1 | Проверить формат без записи | Exit 1: 42 файла проверены, 32 отличия | FAIL baseline | --output=none ничего не записал, несмотря на Changed в stdout |
| `git diff --check`, полный tracked/new-file diff; SHA-256 source/platform/test и lock относительно fdd95eb | Этот worktree, Python/Git | Только разрешённый scope | Код приложения, тесты, platform files и lock не менялись | PASS self-check | Повторная финальная проверка и независимый review отдельно; не runtime smoke |
| macOS/Linux build, devices/capture, Keychain, backend E2E | Требуют своего host/стенда и выбранного scope | Не заявлять лишнюю проверку | Не запускались | NOT RUN | Вне выбора toolchain; .36/.37 и другие соответствующие задачи |

## Result

Реализация .01 подготовлена в отдельной ветке `codex/TASK-FE-001.01-toolchain`
от `fdd95eb`. Изменены только root SDK constraints в `pubspec.yaml`, эта карточка
и coordinator records; добавлен [TOOLCHAIN.ru.md](../../development/TOOLCHAIN.ru.md).
`pubspec.lock` разрешён scope, но менять его не потребовалось. SHA-256 lock:
`d1e569ba3b1d2b319ee34fbc8cfb87f2db21cc10f85b6c791c5468759985def0`.

Подтверждены SDK 3.41.3/Dart 3.11.1 и восстановление зависимостей без upgrade.
Analyze/test/format baseline остаётся FAIL с указанными причинами; реализация
не объявляет приложение verified. Функциональный код/DTO/API/платформы/исходный
test не исправлялись. Логи команд сохранены временно в
`/private/tmp/dictai-fe-foundation-hdqe2j5k/checks/`, результаты изложены выше
и в toolchain-документе, поэтому потеря временного каталога не удаляет evidence.

Status review допускается из implemented при явном перечне failed checks.
Независимый [REVIEW-FE-001.01-03](../reviews/REVIEW-FE-001.01-03.md) завершён
агентом /root/review_fe_foundation_01_02: actionable findings нет. Reviewer
повторил version/offline enforce-lockfile и все три baseline FAIL, подтвердил
checksum, dependency graph, source immutability и согласованность records.
Отчёт reviewed/complete не объявляет приложение verified.
Accepted не выставлен; решение о приёмке baseline-ограничений — за пользователем.
Другие задачи не выполняются. Commit/push/merge новых результатов не выполнены.
