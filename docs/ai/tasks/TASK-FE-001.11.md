---
id: TASK-FE-001.11
plan: PLAN-FE-001
title: "Убрать voice-profile coupling из workspace и старта записи"
status: review
owner: /root/results_contracts
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.09", "TASK-FE-001.10"]
backend_tasks: ["TASK-002.16", "TASK-002.25", "TASK-002.30"]
api_contracts: ["W03", "W06–W09", "U01"]
blocked_by: []
scope:
  - "lib/features/workspace/data/dto/participant_dto.dart"
  - "lib/features/workspace/presentation/workspace_notifier.dart"
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "test/features/workspace/profile_free_flow_test.dart"
  - "test/features/workspace/workspace_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.11.md"
planned_paths:
  - "test/features/workspace/profile_free_flow_test.dart"
delivery_stage: current
---

# TASK-FE-001.11: Убрать voice-profile coupling из workspace и старта записи

## Goal

Workspace detail и запись работают с одними контактами, без обязательного voice setup.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Detail load обращается к VoiceProfileApi; UI библиотеки/образцов и RecordScreen блокируют запись без участников/профилей.

**Целевое:** Workspace detail и запись работают с одними контактами, без обязательного voice setup.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.10](TASK-FE-001.10.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.30
API: W03, W06–W09, U01.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: удалить voice coupling, сохранить реальные contacts; не добавлять assignment UI.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Удалены voice state/lookup/dialogs/assignment и ParticipantDto.voiceProfileId во всех затронутых consumers; load не вызывает retired API.
- [x] Owner может начать запись/выбор WAV в пустом workspace; profiles и список контактов не gate, server решает доступ.
- [x] Сохранены name/email contact CRUD, detail layout и ошибки/retry. Контакты не связываются со Speaker ID и не удаляются вместе с voice UI.
- [x] Widget fixtures существующих W API с нулём contacts проходят; любой /voice-profiles request в тесте отвергается.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Уточнение scope — 2026-11-04

Добавлен test/features/workspace/workspace_api_test.dart. Тест .10 напрямую
обращался к удаляемому compatibility getter ParticipantDto.voiceProfileId.
Остаются проверка четырёх wire keys, игнорирование retired поля в ответе и
остальные W01–W09 regressions.

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

2026-11-04, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Flutter 3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter`.
Flutter использовал `PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true` и готовые зависимости.

| Команда / сценарий | Результат | Статус / граница |
|---|---|---|
| `flutter test --no-pub --timeout 45s test/features/workspace test/widget_test.dart --reporter expanded` | 32 теста прошли, из них 3 новых widget tests, 23 API tests W01–W09 и 6 app fixture regressions | PASS. HTTP и разрешение на микрофон подменены на границах. |
| `flutter analyze --no-pub` по шести Dart paths карточки | No issues found | PASS. Scoped analyze. |
| `dart format --output=none --set-exit-if-changed` по тем же шести путям | 6 files, 0 changed | PASS. |
| Первые widget/analyze passes | Первый widget run завис на ожидании notifier future и был остановлен. После добавления pump выявились layout overflows. На desktop theme и после ограничения ширины двух строк повтор прошёл. Четыре прежних const infos в RecordScreen исправлены в текущем scope. | FAIL → PASS. |
| `git diff --check` по tracked scope и `git diff --no-index --check -- /dev/null test/features/workspace/profile_free_flow_test.dart` | Whitespace diagnostics отсутствуют | PASS. |
| Source сверка W03/W06–W09/U01, backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` | Детали и контакты загружаются отдельно. Проверка доступа U01 принимает HTTP 200 workspace policy без требования непустого списка. | PASS сверки исходников. |
| Независимый review `REVIEW-FE-001.11-01` | `/root/record_data`, reviewed/complete | PASS, 32 tests/analyze/format, открытых findings нет. |
| Real gateway, фактический Start capture/WAV upload, native layout/build и Linux smoke | Не запускались | NOT RUN. Покрываются соответствующими platform/pipeline задачами. |

## Result

Workspace detail загружает W03 и W06. В состоянии и форме контакта остались имя
и email. Add и Delete продолжают работать через W07/W09, существующий notifier
update использует W08. Удалены загрузка voice library, привязка voice profile,
запись образца и соответствующие кнопки. `ParticipantDto` содержит четыре поля
W06–W08. Проверка .10 продолжает подтверждать игнорирование старого wire-поля и
проверяет точные исходящие поля контакта.

RecordScreen больше не загружает детали для проверки контактов. Start доступен
при выбранном workspace независимо от состава контактов. Widget fixture с
реальным форматом W06 `null` дошёл до проверки разрешения на микрофон и принял
выбранный WAV в действующем окне загрузки. При намеренном отказе тестового
микрофона экран показывает существующую ошибку. В тестах любая попытка запроса
`/voice-profiles` отвергается. Реальное разрешение U01 остаётся на backend.

Существующие детали, ошибки и Retry подтверждены widget tests. Две строки
ограничены шириной контейнера после overflow в тесте с квадратным Flutter-шрифтом.
Сетевой переход на U01/U02 относится к .23/.24. Удаление определений voice API и
provider относится к .14. Карточка в статусе `review`, приёмка остаётся владельцу.

Независимый [REVIEW-FE-001.11-01](../reviews/REVIEW-FE-001.11-01.md) завершён: 32 tests/analyze/format PASS, открытых findings нет.
