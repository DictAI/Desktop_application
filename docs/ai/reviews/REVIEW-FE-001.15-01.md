---
id: REVIEW-FE-001.15-01
task_ids: ["TASK-FE-001.15"]
reviewer: /root/record_data
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.15-01

## Scope

2026-11-03, независимый reviewer `/root/record_data`. База frontend HEAD
`80959cc10eacabf45fbf461dbe596030e4e7277c`. Проверены весь новый код и тесты в
`lib/features/record/data/audio_capture.dart`,
`lib/features/record/data/microphone_capture.dart`,
`test/features/record/microphone_capture_test.dart` и tracked diff карточки
`docs/ai/tasks/TASK-FE-001.15.md`. Начальный и итоговый scope сверены через Git и
SHA-256. Reviewer записал только этот отчёт.

Проверены локальные закреплённые исходники `record` 5.2.1, `record_linux` 1.3.0 и
`record_darwin` 1.2.2. `package_config.json`, Podfile.lock и symlink CocoaPods
указывают на macOS исходники последнего пакета. При чтении platform behavior
также проверены настройки microphone usage и audio-input entitlements.

## Findings

### F01 [P1] Stop из Pause на Linux оставляет остановленный parecord

Файл `lib/features/record/data/microphone_capture.dart`, строки 33, 132, 169 и 208.

**Impact.** После Pause вызов Finish либо forced dispose может завершить FFmpeg,
оставив `parecord` остановленным и недоступным для последующего cleanup. WAV может
пройти проверку, пока исходный capture process ещё существует.

**Evidence.** В `record_linux` 1.3.0 `lib/record_linux.dart:76–87` Pause отправляет
SIGSTOP, Resume отправляет SIGCONT. Stop в `:137–153` отправляет обычный SIGTERM,
сразу теряет process handle и ждёт только FFmpeg. PulseAudio устанавливает
обработчик SIGTERM в исполняемом файле, на который ссылается `parecord`. На
локальном синтетическом процессе с таким обработчиком TERM не завершил SIGSTOP
состояние. После SIGCONT обработчик выполнился и процесс завершился.
[Алиас parecord в PulseAudio](https://github.com/pulseaudio/pulseaudio/blob/master/src/utils/meson.build#L5-L27), [обработчик SIGTERM](https://github.com/pulseaudio/pulseaudio/blob/master/src/utils/pacat.c#L1089-L1092).

**Recommendation.** В .15 выдавать `supportsPause=false` для этого драйвера на
Linux и отклонять прямые вызовы Pause/Resume, чтобы избежать входа в опасное
состояние. Если .17 позже добавит Pause, она должна владеть handle и проверять
resume/terminate/wait с bounded escalation на всех путях выхода.

**Disposition.** Open.

### F02 [P1] Linux Start подтверждается до запуска кодировщика и теряет его ошибки

Файл `lib/features/record/data/microphone_capture.dart`, строки 108–117 и 169–176.

**Impact.** Когда `parecord` запускается, а `ffmpeg` недоступен, пользователь может
получить состояние `recording` без записи. При раннем Stop можно потерять контроль
над ещё запускающимся FFmpeg. Долгая запись с недренированным stderr может также
заблокировать кодировщик и finalization.

**Evidence.** В `record_linux.dart:103–113` запуск `parecord` ожидается, но
`_startFfmpegWithAmplitudeMonitoring` вызывается без `await`. Сама функция
ожидает `Process.start` в `:398–433` и не дренирует stderr FFmpeg. `stop` в
`:137–153` ждёт FFmpeg только при уже установленном handle, игнорирует его код
выхода и не ждёт завершения `parecord`. WAV validation после `stop` проверяет
байты найденного файла, тогда как ошибки запуска и владение процессами находятся
внутри зависимости. FakeRecorder с ожидаемым `start()` эту разницу не моделирует.

**Recommendation.** Вывести default Linux plugin из production пути .15 до
управляемого adapter. В .17 использовать её существующий scope для контролируемого
старта, drain, exit status и bounded terminate/join. В .23/.24 направлять через
него также Linux mic-only, иначе этот дефект останется в одном из режимов.

**Disposition.** Open.

### F03 [P2] Ошибка нативной записи до Stop блокирует очередь macOS adapter

Файл `lib/features/record/data/microphone_capture.dart`, строки 43–52, 169 и 208.

**Impact.** При досрочном завершении записи платформой, например из-за ошибки
записи, поздний Finish может ждать ответ бесконечно. Следующий Dispose также
остаётся в очереди, UI не получает ошибку и путь к доступному исходнику через
обычный finish outcome.

**Evidence.** В `record_darwin` 1.2.2 `macos/Classes/delegate/RecorderFileDelegate.swift:63–69`
`stopCb` устанавливается только при Stop и после команды stopRecording. В
`:104–115` completion без `stopCb` не сохраняет результат. Переданные onStop/onPause
callbacks не сохраняются в `:11`. Платформа вправе завершить запись с ошибкой до
команды Stop. Поздний Stop идёт через `macos/Classes/Recorder.swift:66–72` и
`macos/Classes/SwiftRecordPlugin.swift:103–106`, где ответ зависит от этого callback.
Dart `record` 5.2.1 держит semaphore на ожидаемом Stop (`lib/src/record.dart:100–111`,
`:284–290`), а Dispose требует тот же semaphore (`:201–217`). В adapter обе операции
дополнительно ждут общий `_tail`.
[Правила завершения AVCaptureFileOutput при ошибке](https://developer.apple.com/documentation/avfoundation/avcapturefileoutputrecordingdelegate/fileoutput%28_%3Adidfinishrecordingto%3Afrom%3Aerror%3A%29?language=objc).

**Recommendation.** Для .15 ограничить ожидание caller outcome и явно сохранить
`sourcePath`/failed state, если driver не подтверждает finalization. Не создавать
новый recorder, пока release не подтверждён. Простого `timeout` с немедленным
`await dispose()` недостаточно из-за semaphore. Исправление нативного пути в
допустимом platform scope должно сохранять ранний completion/error и гарантировать
один ответ Stop и независимый cleanup. Добавить regression pending Stop и late
completion. Проверить реальный capture interruption в .36.

**Disposition.** Open.

### F04 [P3] Таблица плана .15 расходится с карточкой и DAG

Файл `docs/ai/plans/PLAN-FE-001.md`, строка 251.

**Impact.** Таблица показывает `.15` как `draft` с `unassigned` и не отражает
`.18`, хотя карточка уже передана на review и использует `WavValidator`.

**Evidence.** Строка 191 плана и frontmatter [карточки .15](../tasks/TASK-FE-001.15.md)
указывают зависимость `.18`. Карточка указывает статус `review` и owner `primary-agent`.

**Recommendation.** Coordinator синхронизирует таблицу с карточкой при записи
результата review и сохраняет открытые F01–F03.

**Disposition.** Open.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64. Flutter 3.41.3 и Dart
3.11.1 из `.dart_tool/codex-tools/flutter`. Для Flutter test использовались
`PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Команда или проверка reviewer | Actual | Статус и пределы |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/microphone_capture_test.dart --reporter expanded` | 15 tests passed, exit 0 | PASS. Fake recorder и реальные маленькие PCM файлы |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart analyze lib/features/record/data/audio_capture.dart lib/features/record/data/microphone_capture.dart test/features/record/microphone_capture_test.dart` | No issues found, exit 0 | PASS, scoped Dart |
| Тот же Dart, `format --output=none --set-exit-if-changed` для трёх указанных Dart-файлов | 3 files, 0 changed, exit 0 | PASS |
| `python3` subprocess probe с SIGSTOP, SIGTERM и SIGCONT | Процесс с SIGTERM handler пережил TERM до CONT и завершился после CONT | PASS, локальная механика сигналов. Контроль с `/bin/sleep` без handler завершился от TERM. Нативный Linux/PulseAudio smoke не проводился |
| `git diff --check` для task/review и `git diff --no-index --check /dev/null <file>` для трёх новых Dart-файлов | Whitespace diagnostics отсутствуют | PASS |
| Полный анализ проекта | Reviewer не повторял | NOT RUN. Автор зафиксировал FAIL по 13 прежним `prefer_const_constructors` вне .15 |
| Нативный mic/device/permissions/paused Stop, Linux process inventory, сборки macOS/Linux и UI обоих режимов | Reviewer не запускал | NOT RUN. Аппаратные проверки .36/.37 и UI wiring .23/.24/.49 остаются открытыми |

## Strengths and residual risk

Узкий `AudioCapture` подходит обоим режимам, synthetic tests подтверждают
отмену Finish без stop, повторный подтверждённый Finish без повторной остановки,
сохранение доступного файла, проверку фактических WAV bytes и ошибки на Dart
границе. Источник остаётся на диске при cleanup failure. F01–F03 ограничивают
вывод о безопасном production lifecycle закреплённых драйверов. Отчёт завершает
первый review с открытыми findings. Приёмка пользователя отсутствует.
