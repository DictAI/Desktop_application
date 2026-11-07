---
id: TASK-FE-001.49
plan: PLAN-FE-001
title: "Подтвердить Stop и защитить уход с активной записи"
status: draft
owner: unassigned
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

- [ ] Stop открывает «Завершить запись?» с точными кнопками «Продолжить запись» и «Завершить и отправить». До ответа capture остаётся recording/paused; continue/Escape/закрытие не вызывают stop/upload.
- [ ] Подтверждение выполняет один finalized WAV/preflight/journal/upload по .23/.24. Нет preview/предварительного прослушивания, double tap/два диалога не дают два stop/upload; invalid WAV не отправляется.
- [ ] Перед Start выбраны режим/workspace, mic, system при необходимости и language/mixed; активные параметры не меняются. Guard не стирает переданный из workspace контекст.
- [ ] Уход через sidebar/Back/внутренний route с active/paused записью показывает аналогичное предупреждение с этими двумя действиями. Continue отменяет переход; finish запускает общую отправку и accepted waiting flow, а не случайный discard/фоновую запись.
- [ ] Pending uploads сохраняются .20 и восстанавливаются из Results. Navigation во время upload не заявляет server cancel; неизвестный исход не теряется. Обработку и поздние readiness callbacks текущего транскрипта подключают .28/.48.
- [ ] Forced logout/401 следует безопасному cleanup, не блокируется обычным dialog; native OS window-close interception/новые permissions не входят без отдельного решения.
- [ ] Записаны команды/cwd/среда/actual results; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый review выполнен другим агентом; findings и ограничения сохранены, accepted требует пользователя.

## Implementation notes

V2 seam дают .23/.24, финальный dialog/route policy только здесь. .28 зависит от .49, что упорядочивает record_screen/router; .48 позже дополняет shell/router. Не вызывать stop в dispose при обычной попытке навигации до подтверждения.

Все scope paths относительны frontend; отсутствующие файлы обозначены planned_paths.
Общий файл меняет один writer в порядке DAG. Не менять Flutter dependencies,
backend, immutable snapshots или соседние задачи автоматически. Никаких
commit/push/merge/release; чтение backend не даёт права его изменять.

## Verification

План будущих проверок, не evidence реализации. Cwd — корень frontend. SDK после
.01; тесты изолируются через существующие Riverpod overrides/fakes. Для Dart
изменений: формат только затронутых файлов, flutter analyze и targeted tests;
baseline unrelated failures фиксируются отдельно.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/features/record/record_confirmation_test.dart` | Frontend / router/capture/upload fakes для обоих режимов | Указанные acceptance criteria подтверждены | Не запускалось | NOT RUN | Точные подписи, cancel/Escape/paused, sidebar/back, double confirm, invalid WAV, один upload |
| macOS/Linux record guard smoke | Frontend / hosts .36/.37; synthetic audio | Указанные acceptance criteria подтверждены | Не запускалось | NOT RUN | Случайная навигация не останавливает запись; не native window API implementation |
| `flutter analyze`; формат изменённых Dart-файлов; полный diff и независимый review | Frontend / совместимый SDK | Нет новых ошибок/посторонних изменений | Не запускалось | NOT RUN | Сейчас только planning; не исправлять весь baseline вне scope |

## Result

Не реализовано. Создана только карточка планирования; функциональный код,
API-клиенты, DTO, платформы и зависимости не менялись. Mock evidence не означает
серверного сохранения, multi-device readiness или именованного server export.
Implemented ≠ verified ≠ accepted; приёмки и разрешения публикации нет.
