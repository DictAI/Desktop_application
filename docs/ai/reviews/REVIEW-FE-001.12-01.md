---
id: REVIEW-FE-001.12-01
task_ids: ["TASK-FE-001.12"]
reviewer: /root/review20_resume
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.12-01

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не автор .12.
База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, текущий diff шести
production Dart-файлов и двух новых test files из карточки .12, сама карточка.
Прочитаны workspace list/detail/notifier, изменения Record notifier/screen,
реальный GoRouter, оба новых test files. Сверены реальные W01–W05, текущий UX,
связанные auth/anonymous state и источник отличий от предыдущего .11.
Backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, read-only.
Reviewer пишет только этот отчёт.

## Findings

| ID / priority | Файл и строка первого прохода | Описание и влияние | Evidence | Рекомендация | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `lib/features/workspace/presentation/workspace_notifier.dart:320–323` первого прохода | Canonical rename из списка может навсегда оставить существующий detail в loading. Пользователь не сможет снова открыть детали или кнопку новой записи. | Прежде `acceptWorkspace` повышал `_loadEpoch`, но не менял `DetailStatus.loading`. Если detail reload уже выполнялся, callback rename отменял публикацию его ответа через epoch, а другого завершения loading не было. Достижимо после detail Refresh → переход к list → rename до окончания reload. Исходный finding получен по source, без отдельного reviewer probe. | Сохранить возможность завершения загрузки contacts/detail при canonical name update. Не публиковать прежнее имя и не оставлять loading без активного запроса. Добавить deferred reload + rename regression. | fixed with independent delta evidence |
| F02 / P2 | `lib/features/workspace/presentation/workspace_notifier.dart:52`, `:77–84`, `:99–111` первого прохода | Create/rename во время первой загрузки W01 теряет остальные workspace из локального списка до ручного Refresh. | New Workspace доступна во время initial loading. При deferred W01 page `[A,B]` и успешном create `C` состояние прежде менялось с пустого cache на `[C]`, `_epoch` повышался, затем весь ответ `[A,B]` игнорировался. Аналогично rename A сохранял только A, теряя B. Имеющийся late-load test содержал только A и не выявлял потерю остальных. | Завершать согласованное получение полного списка после mutation либо объединять его с подтверждёнными локальными изменениями так, чтобы старое имя/удалённый workspace не возвращались. Добавить deferred W01 с несколькими workspace, create и rename. | fixed with independent delta evidence |

Оба findings исправлены implementer в выбранном scope и перепроверены независимо.
Открытых actionable findings P0–P3 не осталось. Прежний code review .11 не
заменял этот проход. Независимый review .12 завершён.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, закреплённые Flutter
3.41.3 / Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true`. Собственные проверки reviewer.

| Команда или сценарий | Actual | Статус и граница |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/workspace test/features/auth/session_navigation_test.dart --reporter expanded` | 65/65 tests, exit 0 первого прохода | PASS. Workspace CRUD/record start, profile-free, wire и auth/session. F01/F02 не покрыты первым набором. |
| `flutter analyze --no-pub` по presentation workspace, Record notifier/screen, router и двум новым .12 tests через закреплённый SDK | No issues found, exit 0 | PASS scoped analyze. |
| `dart format --output=none --set-exit-if-changed` по шести production и двум test paths | 8 files, 0 changed | PASS. |
| Source review create/rename/delete, маршрутов, guards и API | Подтверждены реальные W01–W05, canonical server names, одноразовая mutation, explicit retry, typed workspace handoff и повторный busy guard в Record | PASS сверки исходников. Выявлены F01/F02 async cache races. |
| Real backend/owner access, platform capture, V2 integration .23/.24, Stop/leave .49 и полная session isolation .34 | Не запускались | NOT RUN. Отчёт не выдаёт прежнюю legacy capture реализацию за завершённую V2 интеграцию. |
| Повтор той же suite после F01/F02 fix | 68/68 tests, exit 0 | PASS, собственный независимый повтор. Проверены несколько workspace при позднем W01, create/rename/delete overlays, завершение detail reload с canonical name и contact response. |
| Повтор scoped analyze и format после fix | No issues found, exit 0; 8 files, 0 changed | PASS. |
| `git diff --check` для tracked scope и no-index whitespace checks двух новых tests | Diagnostics отсутствуют | PASS. Exit 1 для no-index означает новые файлы. |

SHA-256 первого прохода.

- `workspace_notifier.dart` — `f9765e4b36d5022ff4de62b277b8efd4f5bacb696214cfcdc63bc77498a2c85c`
- `app_router.dart` — `7872660b27d576d0c10eb82eaa0f1873fd32392c1b4eb7a8949458e1b068d9bd`
- `workspace_crud_widget_test.dart` — `4c79e98d86a8697cdf56415db11eb8d862644a116b2b786779f28cbb967c0013`
- `workspace_record_start_test.dart` — `5f0a3966100edbf5f8a7f9ab3bc5241845f8503da0bde457926e0cd1d49fd9b0`

Финальный delta ограничен согласованием кеша и regression tests. Epoch меняется
для нового чтения, а committed updates/delete tombstones во время текущего W01
накладываются на полный ответ. Посторонние workspace сохраняются, старое имя и
удалённый workspace не возвращаются. Detail canonical overlay не отменяет загрузку
contacts и не оставляет loading без завершения. Эти ветки прочитаны независимо
и подтверждены тестами выше.

SHA-256 финального delta.

- `workspace_notifier.dart` — `fcea3b0079ef5ab0d6928171acef59a6e5c0b349f3671800b0d9e11aa63387ab`
- `workspace_crud_widget_test.dart` — `2925dfd60e1fad28f65736dd8fcbbabb0d3f749f542922f0ea42cdf8413438ef`
- Router и workspace_record_start_test совпадают с первым проходом.

## Strengths and residual risk

CRUD использует действующие API и общий диалог с сохранением ввода/ошибкой/retry.
Удаление требует подтверждения и не обещает удаления всех audio/results.
«Новая запись» передаёт query ID и loaded WorkspaceDto через настоящий router.
Record повторно проверяет идентичность контекста и busy state, включая pending
start и anonymous операции. Empty contacts не блокируют переход, contact/role
не выдаются за серверную проверку owner access. Неподтверждённый direct URL
сохраняет текущую selection и объясняет дальнейшее действие.

Новые endpoints, names UI, зависимости и OS permissions не добавлены. Snapshot
W03/W06 содержит серверные ограничения доступа, которые эти клиентские guards
не устраняют. Full capture/Stop UX/session cleanup остаются отдельными задачами.
F01/F02 исправлены с независимым evidence, `accepted` не устанавливается.
