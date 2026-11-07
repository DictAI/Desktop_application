---
id: TASK-FE-001.27
plan: PLAN-FE-001
title: "Адаптировать библиотеку результатов и фильтры"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.25", "TASK-FE-001.26"]
backend_tasks: ["TASK-002.15", "TASK-002.20"]
api_contracts: ["R01", "R03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "test/features/results/results_library_test.dart"
  - "docs/ai/tasks/TASK-FE-001.27.md"
planned_paths:
  - "test/features/results/results_library_test.dart"
delivery_stage: current
---

# TASK-FE-001.27: Адаптировать библиотеку результатов и фильтры

## Goal

Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Экран показывает карточки и PDF buttons по isDone; polling загружает первую страницу без текущих фильтров.

**Целевое:** Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.26](TASK-FE-001.26.md).
Backend traceability: TASK-002.15, TASK-002.20
API: R01, R03.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: библиотека/пагинация/незавершённые отправки; нет Назначить участников.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Results различает server accepted jobs и local pending uploads до 202; восстановление через .20 показывает реальную причину/доступное действие.
- [ ] Open ведёт в detail/transcript; после restart доступны те же реальные результаты. Нет Назначить участников/Переименовать/Save/Skip для Speaker.
- [ ] Сохранены карточки/date filters и server pagination; обновление не сбрасывает page/filter и не повторяет load бесконечно.
- [ ] List pending/done/failed не определяет summary/download availability; anonymous без фиктивного workspace.
- [ ] Library строится на R01/known IDs, без meetings detail/workspace meetings новых endpoints, заглушек вместо доступного delete или mock data production.
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
| `flutter test test/features/results/results_library_test.dart` | Acceptance criteria текущего реального API и безопасные failure/recovery сценарии | NOT RUN; тестовые fixtures только действующего контракта |
| Scoped format и analyze при реализации Dart | Нет новых проблем выбранного scope | NOT RUN; исходный unrelated baseline не исправляется автоматически |
| Real platform/live checks где релевантны | Реальный результат, не mock evidence | NOT RUN; .36/.37/.40, без будущих assignments |
| Links/DAG/hash/diff и независимый review коррекции | Текущая очередь без future prereqs, код сохранён | Coordinator evidence в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
