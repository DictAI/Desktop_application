---
id: TASK-FE-001.29
plan: PLAN-FE-001
title: "Показать canonical transcript с исходными Speaker ID/labels"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.22", "TASK-FE-001.28"]
backend_tasks: ["TASK-002.05", "TASK-002.10", "TASK-002.11", "TASK-002.15"]
api_contracts: ["R04", "§8"]
blocked_by: []
scope:
  - "lib/features/results/presentation/transcript_view.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "test/features/results/transcript_view_test.dart"
  - "docs/ai/tasks/TASK-FE-001.29.md"
planned_paths:
  - "lib/features/results/presentation/transcript_view.dart"
  - "test/features/results/transcript_view_test.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
delivery_stage: current
---

# TASK-FE-001.29: Показать canonical transcript с исходными Speaker ID/labels

## Goal

Показать canonical transcript с исходными Speaker ID/labels backend, без переименования и frontend overlay.

Текущий этап. Реализация после завершения пересмотра и независимого review, в порядке DAG.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Нет текстового canonical viewer; старые speaker fragments требуют имён/email.

**Целевое:** Показать canonical transcript с исходными Speaker ID/labels backend, без переименования и frontend overlay.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.22](TASK-FE-001.22.md), [TASK-FE-001.28](TASK-FE-001.28.md).
Backend traceability: TASK-002.05, TASK-002.10, TASK-002.11, TASK-002.15
API: R04, §8.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: исходные Speaker ID/labels, UNKNOWN/timings; убрать .43 и имя-overlay.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Отображаются исходные canonical speaker_id/label (Speaker 1, Speaker 2…), UNKNOWN и порядок/связи segments без изменения.
- [ ] Нет frontend aliases, пользовательских имён, contact projection, локального store или зависимости от .43/.46/.50.
- [ ] Таймкоды из integer microseconds, overlap/unavailable timing явны; no_speech — успешный empty state.
- [ ] Большой реальный canonical до artifact limit 50 MiB использует ленивый UI, selection/scrolling проверяются synthetic fixtures того же wire.
- [ ] Нет canonical merge/split/правки speaker IDs, fake processing versions/live animation; нет rename/select-contact/save controls.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

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
| `flutter test test/features/results/transcript_view_test.dart` | Исходные backend labels, UNKNOWN/overlap/timings/no_speech, без aliases/contact projection | NOT RUN; тестовые fixtures только действующего контракта |
| Scoped format и analyze при реализации Dart | Нет новых проблем выбранного scope | NOT RUN; исходный unrelated baseline не исправляется автоматически |
| Real platform/live checks где релевантны | Реальный результат, не mock evidence | NOT RUN; .36/.37/.40, без будущих assignments |
| Links/DAG/hash/diff и независимый review коррекции | Текущая очередь без future prereqs, код сохранён | Coordinator evidence в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
