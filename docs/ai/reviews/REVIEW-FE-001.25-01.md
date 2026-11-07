---
id: REVIEW-FE-001.25-01
task_ids: ["TASK-FE-001.25"]
reviewer: /root/review20_resume
mode: read-only
status: open
completion: partial
---

# REVIEW-FE-001.25-01

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не автор .25.
База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, текущие
`processing_notifier.dart`, `pending_job_store.dart`, добавление API/tracker
providers и CancelToken в существующие `speech_status_api.dart`/`canonical_api.dart`,
новый `processing_recovery_test.dart` и карточка .25.
Прежние изменения providers .05/.09/.14 сохранены и отделены от .25.

Прочитаны весь новый tracker/store/test, API/DTO и действующий AuthInterceptor,
связанные auth tests, backend R01 persistence, R03/R04 handler и U03 Session.
Backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, read-only.
Прежний назначенный reviewer `/root/macos16_resume` успел только source reading,
не писал report и передал TTL observation координатору. Этот отчёт пишет только
`/root/review20_resume`.

## Findings

| ID / priority | Файл и строки первого прохода | Описание и влияние | Evidence | Рекомендация | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `lib/features/results/presentation/processing_notifier.dart:251–256` | Поздний 401 старой credential навсегда останавливает tracker после успешного JWT renewal той же логической сессии. ProcessingSession остаётся действующей, но jobs очищены, а `_stopped=true` не позволяет track/restore. | AuthInterceptor .09 сравнивает token/revision и не удаляет новую credential при stale 401, но передаёт исходный HTTP401 клиенту. `_active` продолжает разрешать текущую логическую сессию, а tracker на любом unauthorized вызывает stopSession. Первые tests использовали Dio без AuthInterceptor и не проверяли это сочетание. Исходный finding по source, отдельный reviewer probe не создавался. | Не трактовать каждый read401 как подтверждённый logout новой credential. Учитывать реальную session invalidation, оставлять безопасное восстановление чтения без автоматического refresh/POST. Добавить shared Dio/storage delayed old401 → renewal → manual GET с новым JWT. | open, implementer уведомлён |

Других actionable findings первого прохода не обнаружено.

Перед передачей этого diff координатор уже исправил предварительное TTL
наблюдение прежнего reader. Reviewer независимо подтвердил по backend
`upload_v2.go:247–266` и `speech_handler.go:41–98`, что anonymous U03 может
истечь, пока owner-authorized R03/R04 остаются доступны. Проверенная версия
получает R03/R04 до U03 и не блокирует готовый canonical TTL-ом. Это исправление
проверено текущими tests, не представлено как новая backend возможность.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 /
Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true`. Собственные проверки reviewer.

| Команда или сценарий | Actual | Статус и граница |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/results/processing_recovery_test.dart test/features/results/speech_status_api_test.dart test/features/results/canonical_api_test.dart --reporter expanded` | 109/109 tests, exit 0 | PASS, 25 tracker/recovery и 84 API. F01 не покрыт первым набором. |
| `flutter analyze --no-pub` по пяти production paths и новому test через закреплённый SDK | No issues found, exit 0 | PASS scoped analyze. |
| `dart format --output=none --set-exit-if-changed` по тем же шести paths | 6 files, 0 changed | PASS. |
| Tracked scope `git diff --check`, no-index whitespace checks пяти новых относительно HEAD Dart-файлов | Diagnostics отсутствуют | PASS. Exit 1 для no-index означает новые файлы. |
| Backend R01/R03/R04/U03 source | Подтверждены owner/job/version selection, result_id=job_id, tombstone filtering, независимость canonical/summary и особенность anonymous TTL | PASS сверки исходников, не live backend test. |
| Full UI wiring, фактический restart приложения, session transition .23/.24/.34, real gateway и Linux | Не запускались | NOT RUN. |
| Delta F01 | Ожидает implementer | PENDING. |

SHA-256 первого прохода.

- `processing_notifier.dart` — `b2a506832c73ea29ff831cb1f7c4f1a9f063d871739e8d33f6d351bf8248c30e`
- `pending_job_store.dart` — `4f57a08c36367022c3a5c47a69459724dcb7d1de9ef3a93a77b5c253fc6c3b2e`
- `providers.dart` — `ae4267feb52602ec6672301ac9d3f46c6dd6901598e975d4dde03f1a19d68d8d`
- `speech_status_api.dart` — `65ef82e89f52878768afafb84d212272fbedf2eb0ad92f64ae3452139d44873c`
- `canonical_api.dart` — `76cebaabb7e0d0fd198259abc71aab428e0d742484bd4164add845de3e8fdf89`
- `processing_recovery_test.dart` — `4b21206519d21414cc50e9f173b34708391a277c88ab156dd9b193d8c4d848ae`

## Strengths and residual risk

Один read cycle на job, до четырёх одновременно, timer запускается после ответа.
202 и artifact 503 не выдаются за canonical ready. Owner/version/job проверяются,
summary pending/failed не скрывает доступный transcript. Backoff ограничен, GET
retry не запускает server reprocess или upload. Сохранённый 202 восстанавливается
из .20, R01 дополняет reference без выдуманного processing_version. Второго durable
journal, назначения Speaker и навигации из polling нет.

Удалённые audio подавляются в текущем session store до asynchronous cleanup,
tokens/timers отменяются при stopSession/removeAudio/dispose. Session owner
обязан синхронно вызвать stopSession до публикации другого аккаунта/JWT, хранить
один ProcessingSession на логическую сессию и проверять generation при публикации
UI. Полная проверка этой интеграции остаётся .23/.24/.27/.34. При недоступном
локальном хранилище или power loss receipt cleanup не объявлен гарантированным.
До delta F01 открыт. Отчёт не устанавливает `accepted`.
