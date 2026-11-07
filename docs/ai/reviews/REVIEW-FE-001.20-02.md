---
id: REVIEW-FE-001.20-02
task_ids: ["TASK-FE-001.20"]
reviewer: /root/review20_resume
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.20-02

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не участвовавший в
реализации или исправлении .20. База frontend
`80959cc10eacabf45fbf461dbe596030e4e7277c`, текущие untracked файлы
`lib/features/record/data/pending_upload_store.dart`,
`lib/features/record/data/dto/pending_upload.dart`,
`test/features/record/pending_upload_store_test.dart` и изменённая карточка .20.
Эти три новых Dart-файла исследованы целиком. Сверены AGENTS, WORKFLOW,
архитектурный snapshot, актуальный PLAN-FE-001, UX, backend requests и API/target
snapshots. Прочитаны связанные .18/.19 и реальные backend handler, application и
`services/audio-ingest-service/internal/infrastructure/db/upload_v2.go`.
Backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, доступ только для чтения.

Отдельно проверено F01 из [предыдущего прохода](REVIEW-FE-001.20-01.md).
Тот отчёт сохранён как исторический partial review. Reviewer меняет только этот
новый отчёт, не исходники, тесты, карточки или план.

## Findings

Новых actionable findings P0–P3 в проверенном scope не обнаружено.
Независимый review завершён.

| Finding | Проверенное исправление | Evidence | Disposition |
|---|---|---|---|
| .20-01 F01 / P2 | `pending_upload_store.dart:200–213` и `:390–401` | `submit` и `_lockOwner` сохраняют результат, освобождают locks в `finally`, затем проверяют текущую сессию непосредственно перед успешным возвратом. После этой проверки нет awaited cleanup. Два regression tests переключают session flag в microtask между прежней последней проверкой и завершением cleanup. Оба проходят с `UnauthorizedException`; сохранённая запись/accepted receipt остаётся доступной новой авторизованной сессии того же владельца. | fixed with independent evidence |

Обновление карточки и общей таблицы после этого отчёта остаётся работой
координатора. Отметка `accepted` этим review не устанавливается.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true`. Ниже собственные проверки reviewer.

| Команда или сценарий | Результат | Статус и граница |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/pending_upload_store_test.dart test/features/record/v2_upload_api_test.dart test/features/record/wav_validator_test.dart --reporter expanded` | 112/112 tests, exit 0. Journal 22, связанные .18/.19 90. | PASS. Реальные временные файлы, fake HTTP transport, без живого backend. |
| Первый запуск той же команды в ограниченном окружении | Test engine не смог открыть loopback socket, ни один test body не запущен. | FAIL окружения, не PASS и не дефект кода. Повтор после штатного разрешения запуска тестового движка прошёл. |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/record/data/pending_upload_store.dart lib/features/record/data/dto/pending_upload.dart test/features/record/pending_upload_store_test.dart` | No issues found, exit 0. | PASS, scoped analyze. |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed` по тем же трём Dart paths | 3 files, 0 changed, exit 0. | PASS. |
| `git diff --check -- docs/ai/tasks/TASK-FE-001.20.md` и `git diff --no-index --check /dev/null <file>` для трёх новых Dart-файлов | Whitespace diagnostics отсутствуют. | PASS. Exit 1 у no-index означает новый файл. |
| Source review journal/DTO/tests и backend upload handler/application/repository | Подтверждены owner-scoped idempotency, точные inputs, различие local ID и server references, accepted poll-only и terminal conflict. | PASS сверки исходников, не runtime backend test. |
| Real gateway, UI Results/polling, межпроцессные locks, power loss, полный перезапуск приложения, Linux smoke и сквозная смена аккаунта | Не запускались. | NOT RUN, вне этого data scope. |

SHA-256 исследованной версии перед записью отчёта.

- `pending_upload_store.dart` — `f0cc1130e2f3a31f463fe37b98b9b3b30641cf2cbbfab7117e935182059fcd8c`
- `pending_upload.dart` — `baf83c800ea962312a48d8e69c2edf1fcd9f2a2a0c0392cef7f3a4ecf18886e4`
- `pending_upload_store_test.dart` — `6e780f7b9b12adc0c8aa428753362f40b2f965817d20444ae9ca0d8c499b11a0`

## Strengths and residual risk

До POST создаётся app-owned WAV с неизменными options/key, размером и SHA-256.
Atomic metadata outcome сохраняется до удаления принятой копии. Потерянный ответ
не создаёт новый ключ, `409` не превращается в повтор с новыми inputs, а accepted
запись повторно не отправляется. Проверены повреждения, symlink, квоты,
одновременные submit и сохранность исходного пользовательского файла.
Digest вычисляется блоками в worker isolate без новых зависимостей.

Подтверждён только data scope .20. Первый UI-критерий карточки честно остаётся
открытым до .25/.27, которые подключат Results и polling. Callers .23/.24/.34
должны отменять token прежней сессии до публикации другого владельца/JWT и
проверять generation при публикации собственного UI-state. Guards журнала не
заменяют эту интеграционную обязанность.

Межпроцессные locks advisory, модель записи рассчитана на один isolate.
Хеши не защищают от злонамеренного локального писателя. Flush/rename не
объявлены гарантией устойчивости к отключению питания. Серверная смена
processing/engine/config revisions может дать реальный conflict при replay.
Живой backend и полный recovery UX этим review не объявляются проверенными.
Приёмка остаётся решением владельца проекта.
