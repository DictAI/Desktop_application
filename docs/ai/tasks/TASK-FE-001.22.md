---
id: TASK-FE-001.22
plan: PLAN-FE-001
title: "Добавить canonical transcript DTO и 200/202 result API"
status: review
owner: /root/results_contracts
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07", "TASK-FE-001.21"]
backend_tasks: ["TASK-002.05", "TASK-002.06", "TASK-002.11", "TASK-002.15"]
api_contracts: ["R04", "§8"]
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
delivery_stage: current
---

# TASK-FE-001.22: Добавить canonical transcript DTO и 200/202 result API

## Goal

Ручные Dart DTO dictai-transcript/v1 и typed union canonical/status/unavailable.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Canonical model/API отсутствуют; legacy anonymous SegmentDto использует seconds и fragments.

**Целевое:** Ручные Dart DTO dictai-transcript/v1 и typed union canonical/status/unavailable.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md), [TASK-FE-001.21](TASK-FE-001.21.md).
Backend traceability: TASK-002.05, TASK-002.06, TASK-002.11, TASK-002.15
API: R04, §8.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: R04 200/202 и canonical IDs/labels; убрать requirement модели назначений.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

После завершения review коррекции плана и .21 реализован только действующий R04/v1. Targeted tests/analyze/format PASS; независимый review завершён, приёмка не заявляется.

## Acceptance criteria

- [x] Готовность для показа — R04 200 валидного canonical выбранного job; R03/list/anonymous ready без canonical недостаточны, summary не gate.
- [x] speaker_id и label сохраняются точно как backend (speaker_N / Speaker N); UNKNOWN не подменяется человеком. Полей пользовательского имени/participant_id/overlay нет.
- [x] Отражены transcript/access/engines/speakers/segments/words и required nullable keys; integer microseconds — не epoch/seconds.
- [x] word_timing=unavailable требует words=[]; no_speech — пустые speakers/segments; confidence/identity не выдумываются.
- [x] 200 canonical отличается от 202 SpeechStatus; failed/cancelled202 — terminal, artifact503 не пустой transcript.
- [x] JSON fixtures действующего canonical_v1 покрывают overlap/UNKNOWN/no_speech/nulls; схем будущего assignments API нет.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; F01 dependency исправлена, open findings нет; accepted требует решения владельца.

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

Все команды из `/Users/verliiar/Desktop_application`, macOS 26.2, Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
готовые dependencies, `--no-pub`. Tests/analyze имеют доступ к локальному кэшу и
тестовому порту; реальный API в этих командах не вызывается.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/results/canonical_api_test.dart` | 71 tests passed: v1 fields/nulls/overlap/UNKNOWN/no_speech, schema/domain invariants, identity, 200/202 terminal/unknown, independent summary, artifact503 и safe HTTP/transport/storage errors | PASS | ScriptedAdapter текущего HTTP; не live сервер/model/native evidence |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/results/data/canonical_api.dart lib/features/results/data/dto/canonical_transcript_dto.dart test/features/results/canonical_api_test.dart` | No issues found | PASS | Только scope; не полный repo baseline |
| `.dart_tool/codex-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib/features/results/data/canonical_api.dart lib/features/results/data/dto/canonical_transcript_dto.dart test/features/results/canonical_api_test.dart` | 3 files, 0 changes | PASS | Только scope |
| Первые test/analyze runs тех же файлов | Test не скомпилировался из-за ambiguous literal в test fixture; analyze указал тот же literal и 2 curly-braces infos. Исправлены; повтор выше PASS | FAIL → PASS | Исходный неуспех не скрыт; runtime tests первого прохода не выполнялись |
| Backend source review: transcript.schema.json, transcript.go/decode.go, speech_handler.go и их tests, HEAD | `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; source подтверждает v1 invariants и R04 200/202/503 | PASS source review | Чтение не runtime test; backend не изменён |
| Полный diff four new files/card, synthetic fixture JSON и whitespace через `git diff --no-index --check /dev/null <path>` | Новые файлы просмотрены целиком; whitespace diagnostics нет | PASS | Посторонний dirty diff сохранён |
| Независимый review | [REVIEW-FE-001.22-01](../reviews/REVIEW-FE-001.22-01.md): reviewed/complete, независимо 71 tests/analyze/format PASS; F01 metadata dependency .22→.21 fixed coordinator, open findings нет | PASS | Не live API и не accepted |
| Real gateway/JWT/artifact storage/model и platform builds/smoke | Не запускались | NOT RUN | Нет platform/UI изменений; .36/.37/.40 проверяют реальное окружение |

## Result

Добавлены `canonical_api.dart`, `canonical_transcript_dto.dart`,
`test/features/results/canonical_api_test.dart`, `test/fixtures/canonical_v1.json`;
обновлена эта карточка. Fixture-файл содержит два именованных синтетических HTTP
body: speech с overlap/UNKNOWN/nulls и no_speech. Реальные данные/аудио не копировались.

CanonicalApi получает injected общий Dio: 200 даёт CanonicalReady только после
v1 validation и совпадения recording_id/pinned job_id; 202 даёт CanonicalStatus,
который может быть terminal failed/cancelled либо diagnostic unknown. Summary не
gate. Документированный artifact503 отдельно даёт CanonicalUnavailable с common
ApiFailure/retryRead; прочие HTTP/transport/invalid responses сохраняют AppException.
Ни один failure не превращается в пустой transcript; нет автоматических retries.

Immutable ручные DTO сохраняют исходные поля, текст, Speaker IDs/labels, UNKNOWN,
confidence null/zero, language и microseconds. Проверяются required nullable keys,
запрет лишних canonical полей, JSON-exact integer range, intervals/ordering,
recording-local contiguous speakers/first appearance, допустимый overlap разных
speakers, запрет self-overlap, engines/revisions и word timing bounds. No_speech
с пустыми speakers/segments — успешный canonical. Unsupported schema_version
даёт safe invalidResponse, не интерпретируется по v1 и не означает ready.

Клиент проверяет декодированную Dio JSON-модель; отдельный raw JSON parser, server
artifact hash/byte validation и новый transport stack не добавлены. Сервер остаётся
авторитетной границей raw duplicate-key/50MiB artifact validation. Это не заявление
о проверенном live artifact storage или deployment. Assignment/name/participant
wire fields, providers, router, UI, dependencies и backend не менялись.

71 tests/analyze/format и независимый [review](../reviews/REVIEW-FE-001.22-01.md) PASS. F01: реальное использование SpeechStatusDto отражено явной dependency .22→.21; coordinator синхронизировал PLAN/DAG/active. Open findings нет. Status review,
accepted не выставлен. Commit/push/merge не выполнялись.

## Dependency correction — 2026-11-03

По независимому review .22-01 добавлена явная .22→.21: CanonicalStatus
использует существующий SpeechStatusDto для R04 202. Это реальная compile/runtime
зависимость, DTO не дублируется; plan table/DAG синхронизированы.
