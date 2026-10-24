---
id: TASK-FE-001.18
plan: PLAN-FE-001
title: "Проверять WAV/лимиты и формировать upload options"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.06","TASK-FE-001.07"]
backend_tasks: ["TASK-002.02","TASK-002.08","TASK-002.16"]
api_contracts: ["U01","U02"]
blocked_by: []
scope:
  - "lib/features/record/data/wav_validator.dart"
  - "lib/features/record/data/dto/upload_options.dart"
  - "test/features/record/wav_validator_test.dart"
  - "docs/ai/tasks/TASK-FE-001.18.md"
planned_paths:
  - "lib/features/record/data/wav_validator.dart"
  - "lib/features/record/data/dto/upload_options.dart"
  - "test/features/record/wav_validator_test.dart"
---

# TASK-FE-001.18: Проверять WAV/лимиты и формировать upload options

## Goal

Bounded preflight и typed options без выдуманных расширений backend.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Picker допускает любое audio, локального byte/duration/format gate нет.

**Целевое:** Bounded preflight и typed options без выдуманных расширений backend.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.02, TASK-002.08, TASK-002.16
API: U01, U02.

## Acceptance criteria

- [ ] Проверяются RIFF fmt/data, PCM/float bit depths, 8–192 kHz, 1–8 channels, >0 duration, ≤7200 s и ≤1,073,741,824 bytes; MIME/extension недостаточны.
- [ ] Чтение header/chunks не загружает 1 GiB в RAM; boundary tests используют управляемые tiny fixtures/limits без ложного real-scale evidence.
- [ ] ru/en/auto и mixed=true с пустым language; workspace обязателен только ordinary, idempotency input фиксируется.
- [ ] Пользователь видит требования к WAV; автоматическое универсальное MP3/M4A transcoding не добавляется.
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
| `flutter test test/features/record/wav_validator_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
