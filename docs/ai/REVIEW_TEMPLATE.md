---
id: REVIEW-FE-000.00-01
task_ids: []
reviewer: independent-subagent
mode: read-only
status: open
---

# REVIEW-FE-000.00-01

Шаблон будущего review. Координатор резервирует ID и назначает независимого
reviewer, не писавшего проверяемый diff. Заполни task_ids; для bootstrap без
task явно опиши scope. Reviewer меняет только назначенный отчёт либо передаёт
текст координатору; исходники, конфигурацию, карточки и планы не редактирует.
Статус отчёта: open или reviewed. Это не task status и не приёмка пользователя.

## Scope

Task IDs, точные файлы, база commit/исходный snapshot, tracked/untracked diff,
результаты verification и неизученные области. Укажи дату и личность reviewer.

## Findings

Одна запись на проблему. Пример ниже — будущий placeholder, не существующий файл:

```text
[P2] <repo-relative-path>:<line>
Impact: Что может сломаться или стать неверным.
Evidence: Наблюдение и способ проверки.
Recommendation: Конкретное направление исправления.
Disposition: open / fixed with evidence / deferred by user.
```

Если actionable findings нет, скажи это явно, сохрани границы проверки.
Не исправляй реализацию и не объявляй отложенный finding закрытым.

## Verification

Что проверено самим reviewer: команды/cwd/окружение, PASS/FAIL/SKIP/NOT RUN.
Отделяй повторно выполненные проверки от evidence, прочитанного в task Result.
Не воспроизводи секреты. Для документации проверь ссылки, статусы, scopes и diff.

## Strengths and residual risk

Полезные свойства, непроверенные сценарии, ограничения платформ/окружения,
оставшиеся findings и пределы выводов. Отчёт не устанавливает status accepted.
