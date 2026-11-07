---
id: TASK-FE-001.34
plan: PLAN-FE-001
title: "Проверить и завершить account isolation и cleanup всего batch flow"
status: draft
owner: unassigned
priority: P0
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.09", "TASK-FE-001.20", "TASK-FE-001.25", "TASK-FE-001.27", "TASK-FE-001.28", "TASK-FE-001.32", "TASK-FE-001.33"]
backend_tasks: ["TASK-002.13", "TASK-002.15", "TASK-002.16", "TASK-002.37"]
api_contracts: ["§2", "R01–R04", "U01–U04"]
blocked_by: []
scope:
  - "lib/shared/providers/providers.dart"
  - "lib/core/network/auth_interceptor.dart"
  - "lib/core/router/app_router.dart"
  - "lib/features/auth/presentation/auth_notifier.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/features/record/data/pending_upload_store.dart"
  - "test/security/account_isolation_test.dart"
  - "docs/ai/tasks/TASK-FE-001.34.md"
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
planned_paths:
  - "test/security/account_isolation_test.dart"
  - "lib/features/results/presentation/processing_notifier.dart"
  - "lib/features/results/data/pending_job_store.dart"
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
delivery_stage: current
---

# TASK-FE-001.34: Проверить и завершить account isolation и cleanup всего batch flow

## Goal

Owner namespace и generation fencing во всём capture/upload/poll/download восстановлении.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Глобальные providers и async callbacks могут продолжить старую сессию после logout/account switch.

**Целевое:** Owner namespace и generation fencing во всём capture/upload/poll/download восстановлении.

**Категория B, P0.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.09](TASK-FE-001.09.md), [TASK-FE-001.20](TASK-FE-001.20.md), [TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.27](TASK-FE-001.27.md), [TASK-FE-001.28](TASK-FE-001.28.md), [TASK-FE-001.32](TASK-FE-001.32.md), [TASK-FE-001.33](TASK-FE-001.33.md).
Backend traceability: TASK-002.13, TASK-002.15, TASK-002.16, TASK-002.37
API: §2, R01–R04, U01–U04.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: isolation существующих session/jobs/audio; убрать repository/mock/drafts будущих имён.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Owner/session isolation покрывает реальные upload journal, pending jobs, current detail, original cache/player и ready notices; назначений/mock/drafts текущая версия не имеет.
- [ ] Logout/expiry закрывают recorder/process/timer/subscriptions; late401/202/poll/download не удаляют новый JWT и не показывают данные другому owner.
- [ ] Restart A→B→A, deletion и недоступный локальный source проверены; чужие entries не запрашиваются/не открываются.
- [ ] Токен даёт только локальный namespace, сервер авторизует каждый API. Нет нового /me или assignments endpoint; credentials/audio/transcript не в логах.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| `flutter test test/security/account_isolation_test.dart` | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
