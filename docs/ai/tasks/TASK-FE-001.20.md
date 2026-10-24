---
id: TASK-FE-001.20
plan: PLAN-FE-001
title: "Сохранить upload identity и job references для восстановления"
status: draft
owner: unassigned
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.04","TASK-FE-001.19"]
backend_tasks: ["TASK-002.13","TASK-002.16","TASK-002.22","TASK-002.37"]
api_contracts: ["U01","U02","R01","R03"]
blocked_by: []
scope:
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/record/data/dto/pending_upload.dart"
  - "pubspec.yaml"
  - "pubspec.lock"
  - "test/features/record/pending_upload_store_test.dart"
  - "docs/ai/tasks/TASK-FE-001.20.md"
planned_paths:
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/record/data/dto/pending_upload.dart"
  - "test/features/record/pending_upload_store_test.dart"
---

# TASK-FE-001.20: Сохранить upload identity и job references для восстановления

## Goal

Owner-scoped atomic journal: immutable source/options/key до acceptance, job metadata после.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Upload/job state только в RAM, temp paths и один audio_id теряются при restart.

**Целевое:** Owner-scoped atomic journal: immutable source/options/key до acceptance, job metadata после.

**Категория B, P1.** Сейчас можно реализовать с fake data по существующим DTO; живой end-to-end зависит от настроенного backend.
FE prerequisites: [TASK-FE-001.04](TASK-FE-001.04.md), [TASK-FE-001.19](TASK-FE-001.19.md).
Backend traceability: TASK-002.13, TASK-002.16, TASK-002.22, TASK-002.37
API: U01, U02, R01, R03.

## Acceptance criteria

- [ ] После потери 202/краша повтор использует те же bytes/options/key; файл в app-owned bounded storage, изменение/утрата source запрещает слепой retry.
- [ ] Журнал хранит owner namespace, локальную input identity и accepted IDs, не JWT/пароли/transcript/сырые логи; другие account не получают доступ.
- [ ] Revisions deployment могут дать 409: journal сохраняет conflict и требует решения, не создаёт дубликат новым ключом.
- [ ] Есть schema version/atomic write/corrupt-entry recovery, cleanup после определённого outcome без потери pending source; quota учтена.
- [ ] Если для checksum нужен crypto, добавить только явную минимальную direct dependency в выбранном scope, без общего upgrade; сейчас ничего не менять.
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
Исключение внутри указанного scope: минимальная прямая checksum dependency при доказанной необходимости; lock diff отдельно проверить.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/features/record/pending_upload_store_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
