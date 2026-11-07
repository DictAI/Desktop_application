---
id: TASK-FE-001.13
plan: PLAN-FE-001
title: "Завершить contact CRUD и пояснить email recipients"
status: review
owner: primary-agent
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.12"]
backend_tasks: ["TASK-002.25", "TASK-002.30"]
api_contracts: ["W06–W09"]
blocked_by: []
scope:
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "lib/features/workspace/presentation/workspace_notifier.dart"
  - "test/features/workspace/contact_crud_widget_test.dart"
  - "docs/ai/tasks/TASK-FE-001.13.md"
planned_paths:
  - "test/features/workspace/contact_crud_widget_test.dart"
delivery_stage: current
---

# TASK-FE-001.13: Завершить contact CRUD и пояснить email recipients

## Goal

Name/email contacts с редактированием и честным описанием рассылки.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Есть add/delete, updateParticipant не показан отдельным edit UX; формы смешаны с voice library.

**Целевое:** Name/email contacts с редактированием и честным описанием рассылки.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.12](TASK-FE-001.12.md).
Backend traceability: TASK-002.25, TASK-002.30
API: W06–W09.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: W06–W09 name/email CRUD; P1, без привязки к Speaker.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] W06–W09 add/edit/delete используют настоящие name/email и server IDs, null list — пустая. Повторы/409/ошибки не создают дубликат.
- [x] Контакты не называются распознанными speakers, invitations или аккаунтами с доступом. Нет выбора контакта для Speaker, editor или фиктивного email.
- [x] Owner+contacts email для workspace и owner-only для anonymous объяснены без обещания доставки/resend/новых recipients.
- [x] Удаление/переименование общего контакта не меняет транскрипт; исторический snapshot — будущее .47/.50.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

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

2026-11-07, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Pinned Flutter 3.41.3 / Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`.

| Проверка | Фактический результат |
|---|---|
| `flutter test --no-pub test/features/workspace --reporter expanded` | PASS, независимо 65 тестов, включая 14 contact tests и две регрессии W06 после потерянного PUT |
| `flutter analyze --no-pub` для workspace_detail_screen.dart, workspace_notifier.dart и contact_crud_widget_test.dart | PASS, No issues found после двух braces fixes |
| `dart format --output=none --set-exit-if-changed` по тем же Dart paths | PASS, 3 files, 0 changed |
| Сверка W06–W09 с backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, diff, whitespace | PASS, проверены существующие контракты и текущий scope |
| Независимый [REVIEW-FE-001.13-01](../reviews/REVIEW-FE-001.13-01.md) | PASS, F01/F02 исправлены и повторно проверены, открытых findings нет |
| Живой gateway и email delivery | NOT RUN. Fixtures действующих W06–W09 не подтверждают настройку SMTP или доставку |

## Result

Исходная реализация от /root/workspace12_resume. Coordinator завершил два
замечания review. Workspace показывает реальные name/email contacts, поддерживает
add/edit/delete, confirmation, validation, загрузку, безопасные ошибки и явное
восстановление после неизвестного исхода. Редактирование сохраняет server ID.
При потере ответа W06 сверяет текущий список до явного повтора тех же данных.
Если email занят другим контактом или редактируемый ID исчез, ожидание снимается
и отображается актуальный список. Для исчезнувшего ID кнопка сохранения скрыта.

Объяснение recipients различает owner+contacts и owner-only anonymous. Contacts
не дают доступа и не меняют сохранённый транскрипт. Доставка и resend не обещаются.
Изменены `workspace_detail_screen.dart`, `workspace_notifier.dart`,
`test/features/workspace/contact_crud_widget_test.dart` и эта карточка.
Статус `review`, приёмка владельцем отдельно.
