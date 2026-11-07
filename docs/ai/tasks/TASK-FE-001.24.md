---
id: TASK-FE-001.24
plan: PLAN-FE-001
title: "Заменить anonymous confirm на owner-only V2 batch UX"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.23"]
backend_tasks: ["TASK-002.16", "TASK-002.25", "TASK-002.30"]
api_contracts: ["U02", "U03", "R03", "R04"]
blocked_by: []
scope:
  - "lib/features/record/presentation/anonymous_record_notifier.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/features/record/presentation/upload_modal.dart"
  - "lib/features/record/presentation/label_speakers_modal.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/record/anonymous_flow_test.dart"
  - "docs/ai/tasks/TASK-FE-001.24.md"
planned_paths:
  - "test/features/record/anonymous_flow_test.dart"
delivery_stage: current
---

# TASK-FE-001.24: Заменить anonymous confirm на owner-only V2 batch UX

## Goal

Авторизованный upload без workspace через общий WAV/capture/journal/tracker, без legacy confirm и без назначения имён; после canonical открывается transcript.

Текущий этап выбран; исполнение после независимого review коррекции, по DAG.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Anon пишет M4A/OGG; открывает недismissible LabelSpeakersModal, collects name/email и confirm создаёт workspace.

**Целевое:** Авторизованный upload без workspace через общий WAV/capture/journal/tracker, без legacy confirm и без назначения имён; после canonical открывается transcript.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.23](TASK-FE-001.23.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.30
API: U02, U03, R03, R04.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: owner-only anonymous V2, сразу к результату без confirm/назначений.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Без workspace — тот же pre-Start snapshot/confirmed finish, без preview; Stop/leave dialog в .49.
- [ ] После accepted — tracking и открытие canonical transcript с backend Speaker N. Формы назначения, Skip и временного ручного имени нет.
- [ ] Общий mic/system WAV capture на macOS/Linux; workspace_id не посылается, accepted job/session сохраняются.
- [ ] failed/cancelled/expired terminal; двойные stop/upload/mode switch блокируются, email только owner.
- [ ] Legacy fragments/confirm/LabelSpeakersModal удалены. Workspace/contacts/profiles и имена не создаются из anonymous flow.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Уточнение platform capture — 2026-11-03

Anonymous использует тот же platform capture: .15/.16 на macOS и .17 в обоих
режимах на Linux. Нет fallback на pinned record_linux file recorder. UI Pause
зависит от supportsPause выбранного adapter.

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

План будущих проверок текущей реализации, сейчас **NOT RUN** в коррекции документации. Cwd — frontend, pinned SDK после .01; .01 не переоткрывается.

| Command / scenario | Expected | Actual / status / граница |
|---|---|---|
| `flutter test test/features/record/anonymous_flow_test.dart` | WAV/options/202 и canonical transcript, без confirm/editor | NOT RUN; тестовые fixtures только действующего контракта |
| Scoped format и analyze при реализации Dart | Нет новых проблем выбранного scope | NOT RUN; исходный unrelated baseline не исправляется автоматически |
| Real platform/live checks где релевантны | Реальный результат, не mock evidence | NOT RUN; .36/.37/.40, без будущих assignments |
| Links/DAG/hash/diff и независимый review коррекции | Текущая очередь без future prereqs, код сохранён | Coordinator evidence в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
