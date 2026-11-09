---
id: REVIEW-FE-001.27-01
task_ids: ["TASK-FE-001.27"]
reviewer: /root/review_ordinary_v2
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.27-01

## Scope

2026-11-09. Независимый reviewer `/root/review_ordinary_v2`, не участвовавший
в реализации .27 или связанной .23. База первого прохода
`88248be96664ecc8ff70fe60df58483e4a52812e`. База итогового diff после .23
`c66017fbd1aecfdd17a6795cf3667a7fb01fafdf`. Проверены изменения
`lib/features/results/presentation/results_notifier.dart`,
`lib/features/results/presentation/results_screen.dart`, узкая классификация
ошибок в `lib/features/record/data/pending_upload_store.dart`, новая проверка
`test/features/results/results_library_test.dart` и карточка .27. Общая сессия
из .23, план и реестр изучены как контекст. Посторонние настройки Xcode и VS Code
исключены из scope.

Для сверки использованы UX, снимок API, карточка .25, реализация журнала .20,
tracker .25 и актуальный backend `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`.
В backend прочитаны `presentation/router.go`,
`presentation/handlers/result_handler.go`, `presentation/handlers/speech_handler.go`,
`infrastructure/persistence/postgres_result_repository.go` и
`infrastructure/persistence/speech_delete.go` относительно `services/results-service/internal/`.

## Findings

| ID / priority | Файл и строки первого прохода | Влияние и evidence | Рекомендация | Disposition |
|---|---|---|---|---|
| F01 / P2 | `lib/features/results/presentation/results_notifier.dart:271–308`, `lib/features/results/presentation/results_screen.dart:304–310` | После `ValidationException` действие повторной отправки исчезало до смены сессии. `PendingUploadStore.submit` возвращает этот тип и при временной занятости. Если повтор начат в Record, второй вызов в Results может получить busy, а первый завершиться временной ошибкой. Тогда сохранённый WAV остаётся без действия повтора в Results. | Различать временную блокировку и необратимую непригодность локального WAV. | Исправлено. `PendingUploadStore.isUnrecoverableReplayError` отделяет три необратимые причины, включая повреждение WAV. Regression подтверждает успешный повтор с прежним ключом после busy и 503 первой отправки. |
| F02 / P2 | `lib/features/results/presentation/results_notifier.dart:168–211,219–242` | Точное совпадение с R01 могло удалить receipt незавершённого job. Tracker получал только записи журнала, поэтому при перезапуске job из R01 переставал опрашиваться через R03. Карточка .25 и `PendingJobStore.recover` предусматривают восстановление известного job из R01. | Восстанавливать pending job по точным ID из R01, сохраняя `processingVersion/sessionId` из доступного receipt для того же job. | Исправлено. Регрессии покрывают restart после prune, приоритет richer anonymous receipt с U03 и точный pending R01 при недоступном журнале. Нового POST нет. |
| F03 / P3 | `lib/features/results/presentation/results_screen.dart:312–315,367–369` | Первоначальная проверка `ProcessingPhase.unavailable` скрывала Open даже после временного сбоя R03. При подключении detail это лишало пользователя доступа к реальному результату из R01 и безопасному повтору чтения. | Сохранять переход для точной server row, а в local receipt отдельно учитывать подтверждённую потерю доступа. | Исправлено. GoRouter fixture открывает точный `audio_id/job_id` после ответа R03 503. Подключение production-маршрута в .28. |

В итоговом diff открытых actionable findings нет.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS 26.2 arm64,
закреплённый Flutter 3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`.

SHA-256 исходного diff первого прохода.

- `results_notifier.dart` — `eea902c8fedf9cc61676eb6b9d490b670232ecd70ad12fa791e4fca942d82662`
- `results_screen.dart` — `83ef39ec83850cc9b5658b62c58aa6c19deebe0d48fec4de39c848d47979ef21`
- `results_library_test.dart` — `6222be3e9e8b7dbc70b3d3547e22bd3538407127193775717e7a2bb6517f9dfd`

SHA-256 итогового Dart scope.

- `pending_upload_store.dart` — `484bd75bd359612936589d4920b17407a79a14fe23bff18aac8f8653bbf185a2`
- `results_notifier.dart` — `d04cf84b3074b4845566066e01216ec0763c6ad38fe5b397d71bc829a2095ffe`
- `results_screen.dart` — `9e1f951d96bd807a63bd0a2e076d7461202faa7e6e02b4e2812260c1fe0b4e1a`
- `results_library_test.dart` — `d301869674d02d42e540715e5bced20428a33080788aa6191d04bfb43ccc70eb`

| Сценарий | Результат reviewer |
|---|---|
| Сверка R01, R02 и R03 с исходниками backend | PASS сверки. Подтверждены авторизованный owner scope, inclusive date bounds, пагинация, latest job, точные `audio_id/job_id` и R02 tombstone. |
| `flutter test --no-pub test/features/results test/features/record/pending_upload_store_test.dart --reporter expanded` | PASS, 202/202, exit 0. Тестовый транспорт воспроизводит действующие контракты. Журнал работает с временными WAV и receipts. |
| `flutter analyze --no-pub` по четырём Dart-файлам итогового scope | PASS, `No issues found`. |
| `dart format --output=none --set-exit-if-changed` по тем же четырём файлам | PASS, 4 файла, 0 изменений. |
| `git diff --check` по tracked scope, `git diff --no-index --check /dev/null` по новому test и review | PASS, whitespace diagnostics отсутствуют. |
| Живой gateway, ручной перезапуск приложения и Linux | NOT RUN. |

## Strengths and residual risk

Фильтры и текущая страница сохраняются при ручном обновлении и повторном входе
в Results в пределах сессии. Устаревшие ответы страницы и записи другого owner
отфильтрованы. Обновление local journal отделено от server page. Переход в detail
через реальные идентификаторы подключает .28. Файлы экспорта и summary имеют
собственные контракты. Финальная очистка при удалении относится к .32.

Pending ordinary receipt можно очистить после точного совпадения R01. Pending
anonymous receipt сохраняет U03 reference до терминального состояния R01.
Готовность транскрипта опирается на canonical tracker. Обновление job status
использует GET. Итоговый review завершён. Приёмка пользователя отдельна.
