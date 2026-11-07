---
id: REVIEW-FE-001.16-01
task_ids: ["TASK-FE-001.16"]
reviewer: /root/review20_resume
mode: read-only
status: open
completion: partial
---

# REVIEW-FE-001.16-01

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не автор .16.
База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, current diff
`macos/Runner/SystemAudioRecorder.swift`, `macos/RunnerTests/RunnerTests.swift`,
`lib/features/record/data/system_audio_service.dart`, новый
`lib/features/record/data/macos_audio_capture.dart`,
`test/features/record/macos_capture_test.dart` и карточка .16.
Исследованы все файлы, обе стороны MethodChannel, связанные .15/.18, AppDelegate,
Info.plist и обе entitlements. Прежняя Keychain настройка .04 сохранена.
AppDelegate/Info.plist и entitlement changes этой задачей не добавлялись.
Reviewer пишет только этот отчёт, не исправляет реализацию.

## Findings

| ID / priority | Файл и строки первого прохода | Описание и влияние | Evidence | Рекомендация | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `macos/Runner/SystemAudioRecorder.swift:84–109`, `:339–350`, `:148–150` | Неуспешная отмена теряет handle ещё не подтверждённо остановленного ScreenCaptureKit stream. Повторный cancel может ложно подтвердить cleanup, а новый start допускается при неизвестном исходе прежнего stop. | cancel сохраняет stream только в локальной переменной, вызывает finish, который очищает `capture`, затем ожидает async stopCapture. Если callback сообщает ошибку или timeout отвечает `STOP_TIMEOUT`, retained teardown state отсутствует. Следующий cancel видит capture=nil и возвращает nil. Dart disposal допускает retry после ошибки, поэтому второй success может быть ложным. Автор подтвердил отсутствие отдельного retained teardown handle. Это finding по исходникам, не real hardware reproduction. | Сохранять stream/pending teardown до подтверждённой остановки, сохранять retry при error/timeout, блокировать новый start при неподтверждённом teardown. Добавить regression seam с failed/delayed callback, чтобы повторная отмена не возвращала success преждевременно. | open, передано implementer через coordinator |

Других actionable findings первого статического прохода не обнаружено.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`.

| Проверка reviewer | Actual | Статус и граница |
|---|---|---|
| `flutter test --no-pub test/features/record/macos_capture_test.dart test/features/record/microphone_capture_test.dart --reporter expanded` через закреплённый SDK | 43/43 tests, exit 0 | PASS. 24 .16 и 19 .15, fake channel/microphone. |
| `flutter analyze --no-pub` по system_audio_service, macos_audio_capture и macos_capture_test через закреплённый SDK | No issues found | PASS scoped Dart. |
| `dart format --output=none --set-exit-if-changed` по тем же трём paths | 3 files, 0 changed | PASS. |
| `plutil -lint` для Info.plist и обеих entitlements | Все три OK | PASS. |
| Standalone native source в `/tmp/dictai-macos16-20261106/BoundedWAV.swift` против текущего enum BoundedWAV | Побайтово совпадает участок enum до EOF | PASS сверки, не запуск тестов. |
| Независимая компиляция current RunnerTests с этим точным native enum, Xcode XCTest, define DICTAI_AUDIO_STANDALONE | Начата, результат будет добавлен | PENDING. Не заменяет ScreenCaptureKit host test. |
| Авторские Debug build, 8 native XCTest, длинная conversion/mix и RSS | Evidence прочитано в карточке .16 | Не собственный повтор reviewer. Memory proof относится к offline synthetic pipeline, не live capture/UI. |
| Реальные permission/no-display/no-samples/interruption, mic+system, live RSS, Release и полный Stop/leave UX | Не запускались | NOT RUN, остаются gate .36 после .23/.24/.49. |
| Delta F01 | Ожидает implementer | PENDING. |

SHA-256 первого проверенного diff.

- `SystemAudioRecorder.swift` — `d70000b9b3d5988b727aa43d25650f82a1d133f1fe0a33f2c69d19c4a894244f`
- `RunnerTests.swift` — `cde6e904e5ab82e4cbca028a3d302b57c0d546842dc663933795bf7f68941a93`
- `system_audio_service.dart` — `4efcfb15fb887a052b5a927097d41fab12e892a771310a5cad95c1a6ee399c8b`
- `macos_audio_capture.dart` — `5f74188f693a4ca6fff2a246d272ef3b3d98ee6422a330216e8811512bc8a59f`
- `macos_capture_test.dart` — `c40cf8b3076fecc138c01ab7f06ca699494e866f4979917bc87694452450481f`

## Strengths and residual risk

Offline conversion/mix не читают весь файл. Persistent AVAudioConverter
использует фиксированные 4096-frame blocks, ручной RIFF writer публикует PCM16/
16k/mono через owned partial и atomic rename. Cancellation и publish синхронизированы.
Conversion проверяет длительность и finite samples, mix сохраняет более длинный
вход и clipping. Источники и ранее существующий destination не перезаписываются.

Dart adapter сериализует finish, при отказе одного source останавливает второй,
не подменяет combined mic-only и не обещает pause. Dispose прерывает pending
native command и microphone permission независимо от combined queue. Финальный
WAV проходит реальный общий .18 validator. Legacy callers сохранены до .23/.24.

Реальный ScreenCaptureKit lifecycle пока не проверен аппаратно. Source tests и
synthetic conversion не доказывают работающую permission/capture ветку. До delta
F01 остаётся открытым. Отчёт не устанавливает `accepted` и не разрешает публикацию.
