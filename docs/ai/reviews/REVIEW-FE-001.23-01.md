---
id: REVIEW-FE-001.23-01
task_ids: ["TASK-FE-001.23"]
reviewer: /root/review_ordinary_v2
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.23-01

## Scope

2026-11-09. Независимый reviewer `/root/review_ordinary_v2`, не автор .23.
Frontend base `88248be96664ecc8ff70fe60df58483e4a52812e`. Изучены diff
обычного Record и импорта WAV, общий session provider, новый ordinary flow test,
две обновлённые workspace fixtures и карточка .23. Проверенный снимок из этой
базы содержит только реализацию .23. Семь Dart-файлов совпадают побайтно с
замороженным scope рабочего дерева.

Сверены UX, карточки .20 и .25, `PendingUploadStore`, `V2UploadApi`, платформенные
адаптеры, tracker, auth interceptor и backend SHA
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. Из backend прочитаны U01
`services/audio-ingest-service/internal/presentation/handler/upload_v2_handler.go`
и `services/audio-ingest-service/internal/application/upload_v2.go`, тест маршрутов
`services/gateway/internal/presentation/speech_routes_test.go` и обработчик R03
`services/results-service/internal/presentation/handlers/speech_handler.go`.

## Findings

В замороженном diff открытых actionable findings нет.

| ID / priority | Файл и строки итогового diff | Влияние и evidence первого прохода | Рекомендация и disposition |
|---|---|---|---|
| F01 / P2 | `lib/features/record/presentation/record_notifier.dart:310–366` | Подтверждение Stop во время выполняющейся паузы могло быть проигнорировано, и запись продолжалась после закрытия диалога. | Дождаться перехода паузы и повторно проверить generation, recording identity и статус. Исправлено. Регрессия запускает два Stop на незавершённой паузе и подтверждает одну финализацию и один POST. |
| F02 / P3 | `lib/features/record/presentation/upload_modal.dart:100–113` | Новые параметры языка увеличили высоту модального окна. В низком desktop-окне действия могли выходить за пределы доступной области. | Сделать содержимое прокручиваемым. Исправление `SingleChildScrollView` подтверждено по финальному diff. Ручное изменение размера окна не запускалось. |

## Verification

Рабочий cwd `/Users/verliiar/Desktop_application`. Тестовый cwd
`/tmp/dictai-task-publish-20261107/snapshot-23-candidate`. macOS 26.2 arm64,
Flutter 3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true`.

| Команда или сценарий | Результат reviewer |
|---|---|
| `flutter test --no-pub test/features/record/ordinary_flow_test.dart test/features/workspace/profile_free_flow_test.dart test/features/workspace/workspace_record_start_test.dart --reporter expanded` в изолированном снимке | PASS, 23/23, exit 0. Проверены подтверждение и отмена Stop, пауза, один POST, закрепление параметров и workspace, недействительный WAV, повтор с тем же ключом, 202 и поздний ответ после logout. |
| Тот же тест в совместном рабочем дереве при записи .27 | FAIL компиляции из-за временного отсутствия импорта `ProcessingJob` в соседнем diff. Наблюдение относится к совместному дереву. Изолированный повтор .23 прошёл. |
| `flutter analyze --no-pub` по семи Dart-файлам .23 в рабочем cwd | PASS, `No issues found`. |
| `dart format --output=none --set-exit-if-changed` по семи Dart-файлам .23 | PASS, 7 файлов, 0 изменено. |
| `git diff --check` по .23 и `git diff --no-index --check /dev/null test/features/record/ordinary_flow_test.dart` | PASS, whitespace diagnostics отсутствуют. |
| Сверка с U01 и R03 в backend | PASS сверки исходников. Подтверждены multipart WAV, параметры workspace/language/mixed, `Idempotency-Key`, ответ 202 и отдельное авторизованное чтение job status. |
| Живой gateway и захват с устройствами macOS/Linux | NOT RUN. Плановые проверки .36, .37 и .40. |

Координатор отдельно выполнил полный прогон изолированного снимка. Его отчёт
зафиксировал 522 PASS. Reviewer независимо повторил целевой набор из таблицы.

SHA-256 замороженного Dart scope.

- `record_notifier.dart` — `c6f24d469f68c97504d651a7557158ce5aaf98ade3b7fcb46971235869843ef9`
- `record_screen.dart` — `8b8ed0daa7121a56fe8fad6fd80866517bd77cbc790eddfe362eecd76b6a4fa9`
- `upload_modal.dart` — `d758f08d7802ecb86528c51fc952ea38688c843a3134524b45a49b825ba9edcc`
- `providers.dart` — `c9bfd3651629f84a8e48d958555363eb8d32a3deec16807f8daf7ea1edbe2c0a`
- `ordinary_flow_test.dart` — `701aee699857ec4293427cae81dea8d5545d73858ead5f33ff9d3d7234664a28`
- `profile_free_flow_test.dart` — `d78ed755dfdf8c2ad697861b8b70b4414c41fd9cb3057f45cd7e18c06ac48503`
- `workspace_record_start_test.dart` — `977ab7b87992f36b19c8dd270364c31fdd7d28eacaf77a2d357d3383d6768b0d`

## Strengths and residual risk

Параметры фиксируются до начала операции. Точный WAV и ключ сохраняются до POST.
Ошибка сети оставляет возможность явно повторить ту же отправку. 202 переводит
ordinary flow в принятую обработку, а tracker читает фактический статус. Смена
аккаунта отменяет запросы прежней сессии и исключает публикацию её позднего ответа
в текущем UI. Импорт сохраняет исходный пользовательский файл.

Переход anonymous на V2 входит в .24. Общий detail относится к .28, уведомление
к .48, защита ухода и общее подтверждение к .49. Платформенное поведение требует
планового smoke. Review завершён для .23, приёмка пользователя отдельна.
