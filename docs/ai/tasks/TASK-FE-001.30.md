---
id: TASK-FE-001.30
plan: PLAN-FE-001
title: "Добавить авторизованный document/original download client"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.05","TASK-FE-001.06","TASK-FE-001.07"]
backend_tasks: ["TASK-002.14","TASK-002.15","TASK-002.16","TASK-002.37"]
api_contracts: ["R05","U04"]
blocked_by: []
scope:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/dto/document_kind.dart"
  - "test/features/results/documents_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.30.md"
planned_paths:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/dto/document_kind.dart"
  - "test/features/results/documents_api_test.dart"
---

# TASK-FE-001.30: Добавить авторизованный document/original download client

## Goal

Четыре document kinds и original WAV с JWT и безопасным streaming-to-temp API.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** ResultsApi использует удалённые summary/transcript/audio paths и скачивает весь файл в List<int>.

**Целевое:** Четыре document kinds и original WAV с JWT и безопасным streaming-to-temp API.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md).
Backend traceability: TASK-002.14, TASK-002.15, TASK-002.16, TASK-002.37
API: R05, U04.

## Acceptance criteria

- [ ] Используются только documents/{transcript.txt,transcript.pdf,summary.txt,summary.pdf} и /ingest/v2/audio/{audio_id}/original, job_id сохраняется для documents.
- [ ] Bytes не декодируются как JSON; document404/pending и artifact503 различаются, text error в download не сохраняется как PDF.
- [ ] Original до 1 GiB сохраняется потоком, partial transfer не становится готовым файлом; нет требования Range/Content-Length, когда сервер их не обещает.
- [ ] Origin/relative URL проверены до отправки JWT; никаких MinIO/public signed URLs, source grant IDs и private APIs.
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
| `flutter test test/features/results/documents_api_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
