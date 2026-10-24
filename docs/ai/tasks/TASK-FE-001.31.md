---
id: TASK-FE-001.31
plan: PLAN-FE-001
title: "Сделать экспорт TXT/PDF/WAV и локальное открытие кроссплатформенными"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.29","TASK-FE-001.30"]
backend_tasks: ["TASK-002.14","TASK-002.15","TASK-002.16"]
api_contracts: ["R05","U04"]
blocked_by: []
scope:
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "lib/features/results/data/export_service.dart"
  - "test/features/results/export_service_test.dart"
  - "docs/ai/tasks/TASK-FE-001.31.md"
planned_paths:
  - "lib/features/results/data/export_service.dart"
  - "test/features/results/export_service_test.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
---

# TASK-FE-001.31: Сделать экспорт TXT/PDF/WAV и локальное открытие кроссплатформенными

## Goal

Независимые действия TXT/PDF/original с корректными именами, атомарным save и платформенным open.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Сохраняются только PDF и audio.mp3 в Downloads, xdg-open вызывается даже на macOS; кнопки завязаны на общий isDone.

**Целевое:** Независимые действия TXT/PDF/original с корректными именами, атомарным save и платформенным open.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.29](TASK-FE-001.29.md), [TASK-FE-001.30](TASK-FE-001.30.md).
Backend traceability: TASK-002.14, TASK-002.15, TASK-002.16
API: R05, U04.

## Acceptance criteria

- [ ] Экспорт всех четырёх kinds и original.wav по доступности; transcript.txt не подменяется PDF и summary failure не отключает transcript.
- [ ] Файл создаётся через безопасный выбор/разрешённый каталог; filename sanitization, overwrite/cancel/error и cleanup partial file проверены.
- [ ] macOS использует допустимое системное открытие/Save dialog, Linux — доступный opener с обработкой отсутствия; не hardcode HOME/xdg-open для всех платформ.
- [ ] Локальный playback может использовать только полностью скачанный original; .wav не маркируется .mp3, изменение server Content-Disposition не требуется.
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
| `flutter test test/features/results/export_service_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
