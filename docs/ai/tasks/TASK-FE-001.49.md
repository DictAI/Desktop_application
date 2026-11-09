---
id: TASK-FE-001.49
plan: PLAN-FE-001
title: "Подтвердить Stop и защитить уход с активной записи"
status: review
owner: primary-agent
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.24", "TASK-FE-001.12"]
backend_tasks: []
backend_requests: []
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "lib/features/record/presentation/finish_recording_dialog.dart"
  - "lib/features/record/presentation/record_exit_guard.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/features/record/presentation/record_notifier.dart"
  - "lib/features/record/presentation/anonymous_record_notifier.dart"
  - "lib/core/router/app_router.dart"
  - "lib/core/shell/main_shell.dart"
  - "test/features/record/record_confirmation_test.dart"
  - "docs/ai/tasks/TASK-FE-001.49.md"
planned_paths:
  - "lib/features/record/presentation/finish_recording_dialog.dart"
  - "lib/features/record/presentation/record_exit_guard.dart"
  - "test/features/record/record_confirmation_test.dart"
delivery_stage: current
---

# TASK-FE-001.49: Подтвердить Stop и защитить уход с активной записи

## Goal

Одинаковый Stop/leave confirmation для обоих режимов без preview и случайного завершения capture.

Текущий этап выбран пользователем; исполнение начинается после независимого
review коррекции плана, в порядке prerequisites, без automatic accepted.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.24](TASK-FE-001.24.md), [TASK-FE-001.12](TASK-FE-001.12.md).
Категория B: текущий UI/state по реальному API; test fakes проверяют действующий wire/оборудование и не являются runtime бизнес-реализацией.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Нужна сейчас: Stop/leave confirmation и один WAV/upload, без preview/редактора.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Stop открывает «Завершить запись?» с точными кнопками «Продолжить запись» и «Завершить и отправить». До ответа capture остаётся recording/paused; continue/Escape/закрытие не вызывают stop/upload.
- [x] Подтверждение выполняет один finalized WAV/preflight/journal/upload по .23/.24. Нет preview/предварительного прослушивания, double tap/два диалога не дают два stop/upload; invalid WAV не отправляется.
- [x] Перед Start выбраны режим/workspace, mic, system при необходимости и language/mixed; активные параметры не меняются. Guard сохраняет переданный из workspace контекст.
- [x] Уход через sidebar/Back/внутренний route с active/paused записью показывает то же предупреждение. Continue отменяет переход; finish запускает общую отправку и сохраняет Record для видимого прогресса и ошибок. Обработка после 202 подключается в .28.
- [x] Pending uploads сохраняются .20 и восстанавливаются из Results. Навигация во время upload оставляет отправку активной; неизвестный исход сохраняется в журнале. Обработку и поздние readiness callbacks текущего транскрипта подключают .28/.48.
- [x] Forced logout/401 выполняет cleanup и закрывает устаревший диалог. Перехват закрытия окна ОС и новые разрешения вне scope.
- [x] Записаны команды, cwd, среда и результаты, включая ограничения.
- [x] Независимый review выполнен другим агентом. Результат и ограничения записаны. Приёмка остаётся за владельцем.

## Implementation notes

Общий сценарий .23/.24 используется в обоих режимах. `GoRoute.onExit` для Record
и кнопка Stop используют один диалог. Попытка ухода во время запуска удерживает
Record, чтобы запись не началась в фоне. Подтверждение удерживает Record для
прогресса и ошибок WAV; дальнейший переход во время отправки доступен. `.28`
подключает экран обработки после 202, `.48` дополняет готовность в других разделах.

Все scope paths относительны frontend; отсутствующие файлы обозначены planned_paths.
Общий файл меняет один writer в порядке DAG. Не менять Flutter dependencies,
backend, snapshots или соседние задачи. Владелец разрешил отдельный commit и
push проверенной .49 в main. Приёмка выполняется отдельно.

## Verification

2026-11-09. Cwd `/Users/verliiar/Desktop_application`, macOS arm64, Flutter
3.41.3 и Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`.
Widget tests используют настоящий GoRouter и контролируемые capture/HTTP fixtures.

| Command / scenario | Expected | Actual / status / граница |
|---|---|---|
| `flutter test --no-pub --reporter expanded`, cwd `/tmp/dictai-task-publish-20261107/snapshot-49-candidate` | Полная регрессия на `5ca5fbb` с diff .49 | PASS, 552 теста. 8 новых покрывают оба режима, отмену/Escape/barrier, sidebar/Back/route, старт и паузу, повторное подтверждение, invalid WAV и logout/401 |
| `flutter analyze --no-pub` и `dart format --output=none --set-exit-if-changed` для пяти изменённых Dart-файлов | Нет замечаний анализа и формата | PASS |
| `git diff --check` и проверка разрешённого scope | Нет whitespace и посторонних файлов | PASS |
| [REVIEW-FE-001.49-01](../reviews/REVIEW-FE-001.49-01.md) | Независимый review замороженных пяти Dart-файлов | PASS, 36 целевых тестов, открытых замечаний нет |
| Реальный macOS/Linux capture и live gateway | Ручные сценарии .36/.37/.40 | NOT RUN, текущие проверки используют синтетический WAV и ответы API |

## Result

`finish_recording_dialog.dart` содержит общее подтверждение. `record_exit_guard.dart`
управляет одним диалогом на активную запись, закрывает его при потере сессии и
вызывает прежний WAV/journal/upload. `app_router.dart` защищает уход с Record,
`record_screen.dart` переиспользует то же подтверждение для Stop. Новый
`record_confirmation_test.dart` проверяет сценарии на реальном роутере.

Независимый проход [REVIEW-FE-001.49-01](../reviews/REVIEW-FE-001.49-01.md)
завершён без замечаний. Приёмка владельцем ожидается.
