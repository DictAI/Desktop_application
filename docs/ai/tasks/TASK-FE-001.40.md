---
id: TASK-FE-001.40
plan: PLAN-FE-001
title: "Выполнить реальную batch-интеграцию на подготовленном стенде"
status: blocked
owner: unassigned
priority: P1
readiness_category: C
phase: "5"
depends_on: ["TASK-FE-001.36","TASK-FE-001.37","TASK-FE-001.39"]
backend_tasks: ["TASK-002.17","TASK-002.24","TASK-002.30","TASK-002.37"]
api_contracts: ["A01–A03","W01–W09","U01–U04","R01–R05"]
blocked_by: ["Ожидаются backend .17 acceptance и подготовленный staging/операционный scope .24.","Нужны test deployment из .39, разрешённые данные и доступные macOS/Linux hosts; при отсутствии любого evidence NOT RUN."]
scope:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/REAL_BATCH_E2E.ru.md"
  - "docs/ai/tasks/TASK-FE-001.40.md"
planned_paths:
  - "test/integration/batch_backend_test.dart"
  - "docs/testing/REAL_BATCH_E2E.ru.md"
---

# TASK-FE-001.40: Выполнить реальную batch-интеграцию на подготовленном стенде

## Goal

Пройденный ordinary/anonymous путь с реальными workers и документированными partial failures.

Не выполнять сейчас. Создание карточки разрешено, реализация пользователем
не выбрана. Ready/category A/B не заменяют selection и acceptance зависимостей.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** Mock/unit tests и принятый service code не доказывают полный model flow.

**Целевое:** Пройденный ordinary/anonymous путь с реальными workers и документированными partial failures.

**Категория C, P1.** Полное завершение заблокировано внешним backend/operator evidence; отсутствие evidence нельзя заменить mocks.
FE prerequisites: [TASK-FE-001.36](TASK-FE-001.36.md), [TASK-FE-001.37](TASK-FE-001.37.md), [TASK-FE-001.39](TASK-FE-001.39.md).
Backend traceability: TASK-002.17, TASK-002.24, TASK-002.30, TASK-002.37
API: A01–A03, W01–W09, U01–U04, R01–R05.

### Блокировки и разблокировка

- Ожидаются backend .17 acceptance и подготовленный staging/операционный scope .24.
- Нужны test deployment из .39, разрешённые данные и доступные macOS/Linux hosts; при отсутствии любого evidence NOT RUN.

Разблокировать только после документированного получения перечисленного evidence
и принятия FE prerequisites; затем coordinator меняет blocked на допустимый status.
Не считать status accepted backend-задачи достаточным без scope/Result/config.
## Acceptance criteria

- [ ] Выполнены upload→queued/running→canonical→summary/documents→notification observation для разрешённых synthetic/consented inputs в обоих режимах.
- [ ] Проверены restart/lost-response/idempotency, owner isolation, no-speech, partial success, WAV validation и original integrity без вымышленных public cancel/retry APIs.
- [ ] Evidence фиксирует frontend/backend SHA, build/OS/config, .17 quality acceptance и .24 staging готовность; worker/model quality не оценивается frontend на глаз вместо backend gates.
- [ ] Провалы не маскируются изменением fixtures/expectations или исправлением backend вне scope; задачи остаются незавершёнными до evidence.
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
| `flutter test test/integration/batch_backend_test.dart с явным test-origin/opt-in и credentials вне Git` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `macOS/Linux клиентский smoke против того же test deployment` | Указанный в criteria host/стенд; credentials вне Git | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
