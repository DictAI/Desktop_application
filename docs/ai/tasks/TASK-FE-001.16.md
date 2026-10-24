---
id: TASK-FE-001.16
plan: PLAN-FE-001
title: "Сделать macOS system+microphone capture совместимым и ограниченным по памяти"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.15"]
backend_tasks: ["TASK-002.08","TASK-002.16"]
api_contracts: ["U01","U02"]
blocked_by: []
scope:
  - "macos/Runner/SystemAudioRecorder.swift"
  - "macos/Runner/AppDelegate.swift"
  - "lib/features/record/data/system_audio_service.dart"
  - "lib/features/record/data/macos_audio_capture.dart"
  - "macos/Runner/Info.plist"
  - "macos/Runner/DebugProfile.entitlements"
  - "macos/Runner/Release.entitlements"
  - "macos/RunnerTests/RunnerTests.swift"
  - "test/features/record/macos_capture_test.dart"
  - "docs/ai/tasks/TASK-FE-001.16.md"
planned_paths:
  - "lib/features/record/data/macos_audio_capture.dart"
  - "test/features/record/macos_capture_test.dart"
---

# TASK-FE-001.16: Сделать macOS system+microphone capture совместимым и ограниченным по памяти

## Goal

Один macOS adapter для двух режимов с bounded conversion/mix и проверенным WAV output.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Swift сначала пишет AAC temp, затем readConvertedBuffer читает весь файл; mix выделяет полные buffers. Anonymous macOS system flag фактически не подключён.

**Целевое:** Один macOS adapter для двух режимов с bounded conversion/mix и проверенным WAV output.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.15](TASK-FE-001.15.md).
Backend traceability: TASK-002.08, TASK-002.16
API: U01, U02.

## Acceptance criteria

- [ ] MethodChannel и Swift согласованы; permission denial/no display/no samples/repeated stop завершаются без зависания или ложного success.
- [ ] Conversion/mix идут ограниченными блоками, UI не блокируется полным чтением длинной записи; память измерена отдельно от фейкового теста.
- [ ] Final WAV соответствует RIFF PCM/float без RF64/EXTENSIBLE; native bytes проверены теми же input правилами, включая duration/size.
- [ ] Если combined pause не поддерживается синхронно, UI не предлагает его; downgrade до mic-only не выполняется молча.
- [ ] Правки entitlements/Info.plist только необходимые для выбранного capture; signing/notarization/добавочные разрешения не выполняются скрыто.
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
| `flutter test test/features/record/macos_capture_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter build macos --debug; macOS 13+ synthetic/native permission/capture smoke (подробный release smoke .36)` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
