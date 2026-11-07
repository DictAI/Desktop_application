---
id: REVIEW-FE-001.17-01
task_ids: ["TASK-FE-001.17"]
reviewer: /root/review20_resume
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.17-01

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не автор .17.
База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, current untracked
`linux_audio_capture.dart`, `linux_capture_test.dart`, `docs/development/LINUX_AUDIO.ru.md`
и изменённая карточка .17. Все четыре файла прочитаны целиком. Сверены общий
AudioCapture, .15/.18, текущие требования PLAN-FE-001 и граница реального host
smoke .37. Прочитана документация Process в закреплённом Dart SDK, включая
независимость завершения exitCode от завершения stdout/stderr.
Reviewer пишет только этот отчёт, не реализацию, карточки или общий план.

## Findings

| ID / priority | Файл и строка первого прохода | Описание и влияние | Evidence | Рекомендация | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `lib/features/record/data/linux_audio_capture.dart:122–147`, `:360–363` первого прохода | Auxiliary child теряется при неуспешном terminate/join. После timeout или отмены `_command` может оставить pactl/ffmpeg или незакрытые pipes вне дальнейшего lifecycle cleanup. Следующий dispose объявляет `disposed`, проверив только capture-процессы. | `_Child.terminate` возвращает false, если joined не завершился после TERM и KILL deadlines. `_command` игнорирует этот исход, хранит child только в локальной переменной и в finally очищает `_cancelCommand`. `_stopRecorders` видит только `_recorders`, а auxiliary child туда не попадает. Первый test helper всегда завершает процесс по KILL, поэтому существующий hanging-mixer test этой ветки не проверяет. Это finding по исходникам, не воспроизведение реального Linux сбоя. | Сохранять auxiliary child до подтверждённого join. Не объявлять успешный dispose, пока остался незавершённый child; сохранять возможность повторного cleanup. Добавить fake case, в котором TERM/KILL не приводят к join, затем процесс завершается и повторный dispose может завершиться. | fixed with independent evidence первого delta, 18 tests PASS |
| F02 / P2 | `lib/features/record/data/linux_audio_capture.dart:373–374` первого delta | Ошибка cleanup auxiliary child прерывает dispose до остановки активных capture children. Микрофон способен продолжать запись после попытки закрыть adapter. | `listInputDevices()` разрешён во время recording и может оставить незавершённый pactl после timeout. В delta dispose сначала ожидал `_stopCommands()`, который throws при таком child. Следующая `_stopRecorders()` не выполнялась. | При dispose попытаться завершить обе группы независимо от ошибки первой и только после обеих попыток вернуть failure, сохранив незавершённые handles для retry. Добавить regression active mic + hanging metadata child. | fixed with independent evidence финального delta, 19 tests PASS |

Оба findings исправлены implementer и повторно проверены независимо. Открытых
actionable findings P0–P3 не осталось. Независимый review завершён.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`.

| Проверка reviewer | Результат | Статус и граница |
|---|---|---|
| `flutter test --no-pub test/features/record/linux_capture_test.dart --reporter expanded` через закреплённый SDK | 17/17 tests, exit 0 | PASS. Fake Process и реальные маленькие synthetic WAV. |
| `flutter analyze --no-pub lib/features/record/data/linux_audio_capture.dart test/features/record/linux_capture_test.dart` через закреплённый SDK | No issues found, exit 0 | PASS scoped Dart. |
| `dart format --output=none --set-exit-if-changed` по двум Dart paths | 2 files, 0 changed | PASS. |
| Полное чтение source/test/docs/card, общего интерфейса и SDK Process semantics | Проверены аргументы без shell, monitor текущего sink, no fallback, bounded metadata, stop/join, WAV preflight и сохранность источников | PASS сверки исходников. Выявлено F01. |
| Linux build и реальный pactl/parec/ffmpeg capture, устройства, длинная запись и нагрузка | Не запускались на macOS | NOT RUN. Не заменены fake tests, gate .37 остаётся. |
| Первый delta F01, те же targeted test/analyze/format команды | 18/18 tests PASS, No issues found, 2 files/0 changed, whitespace чистый | PASS. F01 исправлен. Статически выявлен F02, ожидает исправления и повторного review. |
| Финальный delta F01/F02, те же targeted test/analyze/format команды | 19/19 tests, exit 0, No issues found, 2 files/0 changed | PASS. Новые cases проверяют retained mixer и активный microphone при незавершающемся pactl. |
| Whitespace для финальных source/test/docs через no-index и tracked card через `git diff --check` | Diagnostics отсутствуют | PASS. Exit 1 у no-index означает новый файл. |

SHA-256 первого независимого прохода, до исправления F01.

- `linux_audio_capture.dart` — `cfe170b53f879a22c6e8cc8d9cc0f923f9d708e35a861b6401e888cb7166b016`
- `linux_capture_test.dart` — `fefeb42db18e0183a424e9cdb971938a61eaa85260cb497bbff38d1427562c08`
- `LINUX_AUDIO.ru.md` — `89825167f9d446d8e4b07951736fa9746ebaf21350e8d3669ac9b53a7941b26b`

Финальный delta сохраняет auxiliary children в `_commands` до подтверждённого
join. `_cleanupChildren()` запускает обе группы через `Future.wait<void>` с
`eagerError=false` по умолчанию. Поэтому ошибка одной группы не предотвращает
остановку другой. Незавершённый child оставляет dispose в failed и доступен
следующей попытке cleanup. После фактического завершения child повторный dispose
успешен. Эта ветка повторно подтверждена reviewer двумя регрессионными cases.

SHA-256 финальной независимо проверенной версии.

- `linux_audio_capture.dart` — `97fd386806d2395dd9b22e26cf032c6a34e29a9665287ddeaa3bb1cd4829a592`
- `linux_capture_test.dart` — `19a1b632aa64636fcdb593f71a472ef048e954ed17c71052f8992c3691643ad8`
- `LINUX_AUDIO.ru.md` — `89825167f9d446d8e4b07951736fa9746ebaf21350e8d3669ac9b53a7941b26b`

## Strengths and residual risk

Mic-only и combined используют один adapter без record_linux file fallback.
Метаданные pactl ограничены 64 KiB, pipes читаются с момента старта. Неподдержанная
пауза не выдаётся за доступную. Отмена Stop не завершает запись. Finalized inputs
проверяются до смешивания; неудачный mixer не публикует partial и не удаляет inputs.
Повторное finish сериализовано. Пользовательские данные/секреты в отчёт не включены.

Подключение к двум формам записи относится к .23/.24, UI guard к .49.
Сохранённые после ошибок файлы требуют интеграционной cleanup policy .23/.24/.34.
Фактическая совместимость parec/libsndfile, WAV finalization по сигналу,
синхронизация источников и Linux build пока не подтверждены. Отчёт не является
приёмкой задачи или разрешением публикации. F01/F02 исправлены с независимым evidence.
