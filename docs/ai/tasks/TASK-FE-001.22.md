---
id: TASK-FE-001.22
plan: PLAN-FE-001
title: "Добавить canonical transcript DTO и 200/202 result API"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.05","TASK-FE-001.06","TASK-FE-001.07"]
backend_tasks: ["TASK-002.05","TASK-002.06","TASK-002.11","TASK-002.15"]
api_contracts: ["R04","§8"]
blocked_by: []
scope:
  - "lib/features/results/data/canonical_api.dart"
  - "lib/features/results/data/dto/canonical_transcript_dto.dart"
  - "test/features/results/canonical_api_test.dart"
  - "test/fixtures/canonical_v1.json"
  - "docs/ai/tasks/TASK-FE-001.22.md"
planned_paths:
  - "lib/features/results/data/canonical_api.dart"
  - "lib/features/results/data/dto/canonical_transcript_dto.dart"
  - "test/features/results/canonical_api_test.dart"
  - "test/fixtures/canonical_v1.json"
---

# TASK-FE-001.22: Добавить canonical transcript DTO и 200/202 result API

## Goal

Ручные Dart DTO dictai-transcript/v1 и typed union canonical/status/unavailable.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Canonical model/API отсутствуют; legacy anonymous SegmentDto использует seconds и fragments.

**Целевое:** Ручные Dart DTO dictai-transcript/v1 и typed union canonical/status/unavailable.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.05, TASK-002.06, TASK-002.11, TASK-002.15
API: R04, §8.

## Acceptance criteria

- [ ] Полностью отражены transcript/access/engines/speakers/segments/words, required nullable keys; microseconds integer в диапазоне JSON exact, не epoch/seconds.
- [ ] word_timing=unavailable требует words=[]; no_speech speakers/segments=[]; нет вымышленных confidence/participant identity.
- [ ] 200 canonical отличается от 202 SpeechStatus; failed/cancelled202 не означает ждать, artifact503 не означает пустой transcript.
- [ ] Синтетические JSON fixtures включают overlap/UNKNOWN/no-speech/nulls; реальное аудио и reference datasets не копируются.
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
| `flutter test test/features/results/canonical_api_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
