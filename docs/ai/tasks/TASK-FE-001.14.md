---
id: TASK-FE-001.14
plan: PLAN-FE-001
title: "Удалить неиспользуемый voice-profile API и wiring"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "1"
depends_on: ["TASK-FE-001.11"]
backend_tasks: ["TASK-002.20", "TASK-002.25"]
api_contracts: ["§10"]
blocked_by: []
scope:
  - "lib/features/voice_profile/data/voice_profile_api.dart"
  - "lib/features/voice_profile/data/dto/voice_profile_dto.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/workspace/retired_voice_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.14.md"
planned_paths:
  - "test/features/workspace/retired_voice_api_test.dart"
retired_paths:
  - "lib/features/voice_profile/data/voice_profile_api.dart"
  - "lib/features/voice_profile/data/dto/voice_profile_dto.dart"
delivery_stage: current
---

# TASK-FE-001.14: Удалить неиспользуемый voice-profile API и wiring

## Goal

Удалить код/регистрацию retired API без compatibility adapter.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** После .11 voice-profile classes/provider становятся неиспользуемыми.

**Целевое:** Удалить код/регистрацию retired API без compatibility adapter.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.11](TASK-FE-001.11.md).
Backend traceability: TASK-002.20, TASK-002.25
API: §10.

## Этап и решение — 2026-11-02

Нужна: удалить retired voice API после consumers, не заменять заглушкой.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Удалены voice-profile client/DTO/provider после миграции всех ссылок, а не только спрятаны кнопки.
- [x] Regression check runtime source не находит /voice-profiles запросов и неиспользуемых imports; bootstrap историческая документация не считается runtime caller.
- [x] Shared providers меняет один writer после .11; нет автоматического dependency cleanup unrelated packages.
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

2026-11-06, cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter
3.41.3 / Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`, `--no-pub`.

| Command / scenario | Actual | Status / limitation |
|---|---|---|
| `flutter test --no-pub test/features/workspace/retired_voice_api_test.dart test/features/workspace/profile_free_flow_test.dart test/features/workspace/workspace_api_test.dart --reporter expanded` | 27 tests, exit 0 | PASS, includes current W01–W09 and profile-free paths |
| `flutter analyze --no-pub lib/shared/providers/providers.dart test/features/workspace/retired_voice_api_test.dart` | No issues found | PASS, scoped |
| `dart format --output=none --set-exit-if-changed` по двум оставшимся Dart paths | 2 files, 0 changed | PASS, deleted files исключены |
| `rg` по runtime `lib` для client/provider/import/retired route | Только удаляемые client/DTO и provider были callers до изменения, после их нет | PASS, test fixtures/historical docs не runtime callers |
| Diff/scope/whitespace | Удалены два retired файла, provider/import, добавлен regression test | PASS, dependencies/API соседних features не изменены |
| Independent REVIEW-FE-001.14-01 | Передаётся reviewer | PASS, reviewed/complete, accepted не выставлен |

## Result

Удалены `lib/features/voice_profile/data/voice_profile_api.dart`, его DTO и
регистрация `voiceProfileApiProvider` в shared providers. Все consumers уже удалены
и независимо проверены в .11. Compatibility adapter, заглушка или новый repository
не созданы. Действующие workspace контакты остаются отдельной функцией.

Новый regression test проверяет отсутствие retired URL/client/DTO/provider/import
во всём runtime Dart-коде. Проверки существующих workspace API и profile-free UI
тоже прошли. Историческая документация и fixtures о неподдерживаемых полях сохранены.
Pubspec/lock не менялись. Требуемый независимый review ожидается.

Первый analyze выявил braces lint в новом тесте. Исправлено, повтор scoped analyze
No issues found. `retired_paths` явно указывает удалённые, а не будущие файлы.

Независимый [REVIEW-FE-001.14-01](../reviews/REVIEW-FE-001.14-01.md) завершён 2026-11-06.
Открытых findings нет, приёмка пользователя не присваивается автоматически.
