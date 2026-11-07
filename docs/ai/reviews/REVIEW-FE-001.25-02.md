---
id: REVIEW-FE-001.25-02
task_ids: ["TASK-FE-001.25"]
reviewer: /root/review_snapshot_platform
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.25-02

## Scope

2026-11-07. Независимый повторный review .25 после
[REVIEW-FE-001.25-01](REVIEW-FE-001.25-01.md). База frontend
`80959cc10eacabf45fbf461dbe596030e4e7277c`. Проверены
`processing_notifier.dart`, `pending_job_store.dart`, wiring в `providers.dart`,
CancelToken в `speech_status_api.dart` и `canonical_api.dart`,
`processing_recovery_test.dart` и карточка .25. Сверены AuthInterceptor,
owner-scoped journal .20, backend R01/R03/R04/U03 на
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`.

## Findings

| ID / priority | Файл | Влияние и evidence | Рекомендация | Disposition |
|---|---|---|---|---|
| .25-01 F01 / P2 | `lib/features/results/presentation/processing_notifier.dart:251–256` | Поздний HTTP 401 после замены credential ранее останавливал действующую сессию tracker. Итоговый code path прекращает автоматический retry конкретного чтения. Регрессия с общим Dio/AuthInterceptor и тестовым secure storage подтвердила, что новый JWT сохраняется и последующий ручной GET проходит. | Подключить реальный `stopSession()` к завершению сессии в .23/.24/.27/.34. | fixed with evidence |
| F02 / P2 | `lib/features/results/presentation/processing_notifier.dart:263–275`, версия до исправления | После уже опубликованного canonical ответ R03 404 сохранял `ready` и старый текст. Backend R03 скрывает удалённый или чужой результат как 404 (`speech_handler.go:53–61`). Итоговый код сбрасывает canonical/status на 403/404, останавливает ожидание, не выводит факт удаления из неоднозначного ответа. 503 сохраняет ранее полученный текст и использует backoff. | Различать отказ доступа и временную недоступность. Durable receipt и подтверждённое удаление остаются отдельными состояниями. | fixed with evidence, ready → 403/404/503 regressions PASS |

Открытых actionable findings по проверенному scope нет.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS 26.2 arm64,
Flutter 3.41.3/Dart 3.11.1 из `.dart_tool/codex-tools/flutter`.
Для Flutter применялись `CI=true FLUTTER_SUPPRESS_ANALYTICS=true` и
`PUB_CACHE=/Users/verliiar/.pub-cache`.

| Проверка | Actual | Статус и граница |
|---|---|---|
| `flutter test --no-pub test/features/results/processing_recovery_test.dart test/features/results/speech_status_api_test.dart test/features/results/canonical_api_test.dart --reporter expanded` | 113 tests | PASS. Поздний 401, 403/404/503 после готовности, owner/version checks, polling, backoff, отмена и recovery |
| `flutter analyze --no-pub` по шести Dart paths .25 | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed` по тем же шести paths | 0 changed | PASS |
| `git diff --check`, scoped no-index whitespace checks новых Dart paths | Нет diagnostics | PASS |
| Backend source review | R01 latest job identity, R03/R04 owner/job + tombstone, U03 TTL | PASS статической сверки. Готовый canonical проверяется до U03 |
| Real gateway, полный UI wiring, фактический restart и logout с интегрированным session owner | Не запускались | NOT RUN, .23/.24/.27/.34/.36–.40 |

Итоговые SHA-256:

- `processing_notifier.dart` — `8bfa3106f341d48c8a13bf1446cfc075e5829ee663c56b82318e2106a394759f`
- `pending_job_store.dart` — `4f57a08c36367022c3a5c47a69459724dcb7d1de9ef3a93a77b5c253fc6c3b2e`
- `providers.dart` — `ae4267feb52602ec6672301ac9d3f46c6dd6901598e975d4dde03f1a19d68d8d`
- `speech_status_api.dart` — `65ef82e89f52878768afafb84d212272fbedf2eb0ad92f64ae3452139d44873c`
- `canonical_api.dart` — `76cebaabb7e0d0fd198259abc71aab428e0d742484bd4164add845de3e8fdf89`
- `processing_recovery_test.dart` — `a6ac015b94b9aa153a8a28517e840f7fd93f00e140eaeb77647b81bbb3a6cb88`

## Strengths and residual risk

Recovery использует .20 receipt и актуальную R01 page. Tracker сверяет
owner/job/version и отделяет готовность canonical от summary и anonymous TTL.
Запросы ограничены одним циклом на job и четырьмя одновременно. Caller при
подключении UI хранит один `ProcessingSession` на логическую сессию и
синхронно завершает tracker при выходе или смене аккаунта. Приёмка относится к
решению владельца.
