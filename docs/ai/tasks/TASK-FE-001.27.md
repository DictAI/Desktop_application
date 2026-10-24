---
id: TASK-FE-001.27
plan: PLAN-FE-001
title: "Адаптировать библиотеку результатов и фильтры"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.25","TASK-FE-001.26"]
backend_tasks: ["TASK-002.15","TASK-002.20"]
api_contracts: ["R01","R03"]
blocked_by: []
scope:
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "test/features/results/results_library_test.dart"
  - "docs/ai/tasks/TASK-FE-001.27.md"
planned_paths:
  - "test/features/results/results_library_test.dart"
---

# TASK-FE-001.27: Адаптировать библиотеку результатов и фильтры

## Goal

Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Экран показывает карточки и PDF buttons по isDone; polling загружает первую страницу без текущих фильтров.

**Целевое:** Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.26](TASK-FE-001.26.md).
Backend traceability: TASK-002.15, TASK-002.20
API: R01, R03.

## Acceptance criteria

- [ ] Сохранены визуальные карточки и date filtering, добавлены pagination controls; обновления не сбрасывают page/filter и не повторяют бесконечный load.
- [ ] Pending/done/failed списка не определяет готовность всех downloads; карточка использует независимые статусы/URL availability и открывает details после .28.
- [ ] Anonymous записи показываются без fictitious workspace; old STUB text и «Delete not yet available» не выдаются вместо реальной ошибки.
- [ ] Новый endpoint meetings detail/workspace meetings не используется; library строится на R01 и known audio/job IDs.
- [ ] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
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

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/features/results/results_library_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
