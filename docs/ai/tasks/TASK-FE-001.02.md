---
id: TASK-FE-001.02
plan: PLAN-FE-001
title: "Удалить значения секретов из tracked-конфигурации"
status: review
owner: primary-agent
priority: P0
readiness_category: A
phase: "0"
depends_on: []
backend_tasks: []
api_contracts: []
blocked_by: []
scope:
  - ".vscode/launch.json"
  - ".gitignore"
  - ".vscode/launch.example.json"
  - "docs/development/SECRETS.ru.md"
  - "docs/ai/tasks/TASK-FE-001.02.md"
planned_paths:
  - ".vscode/launch.example.json"
  - "docs/development/SECRETS.ru.md"
---

# TASK-FE-001.02: Удалить значения секретов из tracked-конфигурации

## Goal

Tracked-конфигурация содержит только безопасные примеры; оператор знает действия с потенциально раскрытым credential.

Пользователь явно выбрал реализацию .01 и .02 2026-10-25. Эта карточка выполняется
в ветке `codex/TASK-FE-001.02-secrets` от `fdd95eb`; другие implementation-задачи
не выбраны. Commit/push/merge новых результатов этим поручением не разрешены.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Текущее:** В .vscode/launch.json есть значение ключа; оно не выводилось в аудит и не переносится в документы.

**Целевое:** Tracked-конфигурация содержит только безопасные примеры; оператор знает действия с потенциально раскрытым credential.

**Категория A, P0.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: нет.
Backend traceability: Нет отдельной speech-задачи; существующие frontend foundation/auth behavior.
API: нет новых API.

## Acceptance criteria

- [x] Удалены реальные ключи/токены из текущего дерева, добавлены placeholders и описание локального ввода без публикации значений.
- [x] Проверены tracked/untracked предлагаемые файлы и итоговый diff без вывода найденных значений; журнал содержит только пути/типы findings.
- [x] Владелец уведомлён о необходимости отдельного решения по revoke/rotation; агент не обращается к provider и не переписывает Git history.
- [x] Если credential требует реального отзыва, до evidence владельца security release gate остаётся открытым.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
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

Cwd: `/Users/verliiar/.codex/worktrees/fe-001-02-secrets/Desktop_application`.
2026-10-25, macOS, Python 3 stdlib/Git; Flutter SDK для config/doc scope не нужен.
Все выводы credential scan/diff редактируются до вывода; значение исходного
credential читается из HEAD только в памяти для проверки отсутствия его копий.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| Python stdlib credential pattern + original-value comparison по `git ls-files -co --exclude-standard` | Этот worktree, все tracked/proposed files | Нет credential в текущем дереве/новых документах | 156 файлов до добавления review, включая 8 binary assets по ASCII/byte matching; 0 findings и 0 копий исходного значения | PASS | Проверены provider-key/JWT/private-key форматы; scanner не доказывает активность/отзыв ключа и не очищает Git history |
| Первый вспомогательный scanner запуск, затем binary-aware повтор | Python 3 | Честный результат сканирования | Первый запуск остановился на UTF-8 decode binary asset; исправлен scanner, повтор завершён результатом выше | FAIL helper, затем PASS | Ошибка одноразового скрипта, не скрытый PASS проекта; dependency/scanner tool не добавлялся |
| `json.loads` launch.json/example, сравнение configurations | Python 3 | Валидный безопасный одинаковый пример | JSON совпадают, ANTHROPIC_API_KEY/MODEL defines удалены, API_BASE_URL=localhost сохранён | PASS | Этот define пока не читается кодом; переключение API не реализуется |
| `git check-ignore --no-index -q -- <path>` для 10 положительных/отрицательных примеров | Git | Private files ignored, безопасные tracked examples доступны Git | Все 10 cases соответствуют ожиданиям | PASS | .gitignore не защищает tracked launch.json; локальные env/local JSON не загружаются автоматически |
| `git diff --check`, полный redacted diff; SHA-256 baseline | Этот worktree, база fdd95eb | Только task/coordinator scope | Изменены .gitignore, launch.json, карточка и records; добавлены launch.example.json/SECRETS.ru.md; остальные файлы неизменны | PASS self-check | Final checks/review отдельно; удалённая secret-строка в выводах redacted |
| Flutter analyze/test/build и provider revoke/validity check | Не нужны для config/doc scope | Не выдавать их за выполненные | Не запускались | NOT RUN | Нет runtime изменений; отзыв/rotation требует действия владельца вне этой задачи |

## Result

Реализация .02 подготовлена в ветке `codex/TASK-FE-001.02-secrets` от `fdd95eb`.
Удалены Anthropic credential и неиспользуемый model define из tracked launch.json;
добавлены safe launch.example.json, правила ignore и
[SECRETS.ru.md](../../development/SECRETS.ru.md). Функциональный Dart/Swift/Linux
код, API/DTO, SDK constraints и dependencies этой веткой не менялись.

В текущем дереве этой ветки секретных значений проверенными способами не найдено.
Main, peer-ветка и Git history сохраняют исходный commit; значение из них не
переносится в diff evidence. Пользователь уведомлён: credential потенциально
раскрыт, владельцу нужен отдельный revoke/rotation и безопасное подтверждение.
До evidence владельца security release gate .42 остаётся открытым. Агент
не обращался к Anthropic и не переписывал историю; удаление строки не равно отзыву.

Независимый [REVIEW-FE-001.02-01](../reviews/REVIEW-FE-001.02-01.md) завершён
агентом /root/review_fe_foundation_01_02: actionable findings нет. Reviewer
повторил current-tree scan (156 файлов до отчёта), JSON, 16 ignore cases,
redacted diff/source checks и подтвердил открытый внешний security gate.
Отчёт reviewed/complete не доказывает отзыв ключа или runtime готовность.
Accepted не выставлен; приёмка локального исправления не закрывает внешний
security gate. Другие задачи не выполнены, commit/push/merge новых результатов нет.
