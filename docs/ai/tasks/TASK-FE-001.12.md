---
id: TASK-FE-001.12
plan: PLAN-FE-001
title: "Завершить workspace UX создания и переименования"
status: review
owner: /root/workspace12_resume
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.11"]
backend_tasks: ["TASK-002.25"]
api_contracts: ["W01–W05"]
blocked_by: []
scope:
  - "lib/features/workspace/presentation/workspaces_screen.dart"
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "lib/features/workspace/presentation/workspace_notifier.dart"
  - "test/features/workspace/workspace_crud_widget_test.dart"
  - "docs/ai/tasks/TASK-FE-001.12.md"
  - "lib/features/record/presentation/record_notifier.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/core/router/app_router.dart"
  - "test/features/workspace/workspace_record_start_test.dart"
planned_paths:
  - "test/features/workspace/workspace_crud_widget_test.dart"
  - "test/features/workspace/workspace_record_start_test.dart"
delivery_stage: current
---

# TASK-FE-001.12: Завершить workspace UX создания и переименования

## Goal

Workspace CRUD через существующие API с сохранением сетки и маршрута detail.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Список/create/delete существуют, updateWorkspace в notifier не связан с полноценным edit UX.

**Целевое:** Workspace CRUD через существующие API с сохранением сетки и маршрута detail.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.11](TASK-FE-001.11.md).
Backend traceability: TASK-002.25
API: W01–W05.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Кнопка и передача контекста принадлежат .12. .23 зависит от .13 (транзитивно .12), поэтому writes Record/router не параллельны. Пока .49 не готова, активная операция не затирается и переход блокируется с объяснением.

## Этап и решение — 2026-11-02

Нужна: workspace CRUD и Новая запись; P1, без speaker naming.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] В detail есть «Новая запись»: Record открывается с выбранным workspace; неподтверждённый/невалидный контекст объясняется, существующая активная операция не перезаписывается.
- [x] Передача workspace не требует contacts/profiles; последующий .49 перехватывает уход с уже активной записи и не выполняет неожиданный stop.
- [x] Создание, открытие, rename и delete имеют loading/validation/failure/retry состояния без STUB обещаний.
- [x] Rename обновляет list/detail и выбранный workspace без stale name; отсутствие/недоступность workspace корректно объясняется.
- [x] Удаление не трактуется как deletion всех audio/results; соответствующую политику не выдумывать.
- [x] Контакт/роль не используются как подтверждение серверного owner access.
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
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true FLUTTER_SUPPRESS_ANALYTICS=true`. SDK/lock не менялись.

| Command / scenario | Actual / status | Граница |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/workspace test/features/auth/session_navigation_test.dart --reporter expanded` | PASS, exit 0, 68 tests, 2026-11-06. Лог `/tmp/dictai-workspace12-review-delta.log` | 24 новых .12 tests, 3 profile-free regressions, 23 workspace wire tests и 18 auth/session tests. Только существующие HTTP/OS boundaries заменены test fakes |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/workspace/presentation lib/features/record/presentation/record_notifier.dart lib/features/record/presentation/record_screen.dart lib/core/router/app_router.dart test/features/workspace/workspace_crud_widget_test.dart test/features/workspace/workspace_record_start_test.dart` | PASS, No issues found | Изменённые .12 Dart-файлы |
| `.dart_tool/codex-tools/flutter/bin/dart format --output=none --set-exit-if-changed` по шести изменённым production Dart и двум новым test paths из scope | PASS, 8 files, 0 changed | Проверяется весь изменённый Dart scope |
| `git diff --check --` по exact .12 scope, чтение новых test files, local links и scope | PASS | Изменения других writers не отменялись |
| Первый ограниченный запуск `profile_free_flow_test.dart` | FAIL запуска: local server socket denied | Сам тест не был выполнен. Повтор с разрешением запуска прошёл в suite выше |
| Один повтор suite | NOT RUN, automatic approval review timeout до запуска | Разрешённый инструментом повтор выполнился. Timeout не трактуется как unsafe или PASS тестов |
| Независимый review .12-01 | PARTIAL, F01/F02 обнаружены reviewer, исправления переданы на delta | Author не помечает findings закрытыми без независимого подтверждения |
| Полный analyze всего незавершённого плана, platform build/capture, real gateway/owner permissions | NOT RUN | Другие задачи реализуются параллельно. .12 не меняет capture/channel/platform config. Полные integration и runtime gates выполняются отдельными задачами |

## Result

2026-11-06. .12 реализована и проверена в выбранном scope, передана на независимый
review. `accepted` не выставляется.

- `workspaces_screen.dart`: реальная сетка W01, общий create/rename диалог, сохранение
  ввода при ошибке, явный повтор, single-flight/loading и подтверждение W05.
  Текст удаления относится к workspace/contacts и не обещает удаления audio/results.
  Старые STUB-обещания и ссылка на отсутствующий MISSING_ENDPOINTS удалены.
- `workspace_notifier.dart`: реальные W02/W04/W05, mutation guard, защита от
  запоздавшего list response после rename, canonical server-name sync. Уже
  созданные list/detail/Record caches обновляются, неинициализированный detail
  не создаётся при delete. W03/W06 и локальная роль не объявляются server access check.
- `workspace_detail_screen.dart`: Rename и «Новая запись» с query workspace ID и
  typed loaded WorkspaceDto. Контакты/profiles не являются prerequisite перехода.
- `record_screen.dart`, `record_notifier.dart`, `app_router.dart`: контекст проходит
  через настоящий защищённый route, повторно проверяется в Record. Некорректный,
  неподтверждённый или busy context объясняется, прежняя selection/operation
  сохраняется. Guard учитывает запись/паузу/upload и pending permission/start,
  включая anonymous start из текущего Record. Create из Record использует ту же
  проверенную форму с видимой причиной ошибки и retry.
- Новые `workspace_crud_widget_test.dart` и `workspace_record_start_test.dart`
  проверяют формы, HTTP/failure/retry, canonical sync, late load, active-operation
  guards, pending start, передачу workspace без контактов, прямой URL и реальный
  authenticated router. Auth/session regressions включают matched 401 и guards.

Новых endpoints, DTO, dependencies и OS permissions нет. Native Stop/leave dialog
остаётся .49, V2 capture/upload интеграция — .23/.24, contacts edit — .13. W01
использует существующую первую страницу; pagination UI не заявляется этим scope.
Живой backend и его ограничения W03/W06 этим тестовым проходом не проверены.
Backend, .01/.02 и coordinator records не изменялись implementer-агентом.
Commit/push/merge/release не выполнялись.

## Review delta — 2026-11-06

По независимым findings .12-01 исправлены две гонки. Список сохраняет committed
create/rename/delete, произошедшие после начала чтения, и объединяет их по ID с
полным полученным page. Поколение чтения больше не отменяется мутацией. Во время
pending detail reload новая canonical workspace сохраняется отдельно от старого
read snapshot; reload завершает загрузку контактов и выходит из loading.

В `workspace_crud_widget_test.dart` проверены deferred page с двумя существующими
workspace и параллельными create/rename/delete, а также loaded detail → deferred
reload → list rename → late old detail response. 68 связанных tests, scoped analyze
и format PASS. Закрытие F01/F02 ожидает независимого delta review. Изменены только
notifier, уже разрешённый тест и эта карточка; ранее проверенный scope сохранён.

2026-11-06. Независимый .12-01 reviewed/complete, F01/F02 fixed, 68 tests,
scoped analyze/format/whitespace PASS. Открытых findings нет, принятие — владельцу.
