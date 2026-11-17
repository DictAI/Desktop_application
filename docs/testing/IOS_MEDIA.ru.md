# iOS: original WAV, плеер и аудиосессия

TASK-FE-002.13 использует существующие DocumentsApi и audioplayers 6.6.0 /
audioplayers_darwin 6.4.0. Backend/API wire, зависимости и подпись сохранены.

## Владение файлами и сессией

Original скачивается общим авторизованным Dio потоково. Кеш принадлежит текущей
сессии и ключу account/audio/job; сам U04 по контракту принимает только audio ID.
Один полный WAV и его временная загрузка ограничены одной квотой: по умолчанию
256 MiB, configurable до текущего original limit 1 GiB. Content-Length, RIFF
size и полученные chunks проверяются до записи. MIME/размер/RIFF/PCM проверяет
DocumentsApi/WavValidator, частичный файл не публикуется. Серверный checksum
не предусмотрен текущим HTTP-контрактом; hash не выдумывается.

Очередь кеша сериализует проверку tmp-файла, lease и eviction. Другой файл не
заменяет принадлежащий декодеру input. Файлы удаляются после остановки/освобождения
декодера; cleanup failure сохраняет владение для повтора. Close отменяет download,
ждёт lease и удаляет только собственный cache root. Original из Files/пользовательские
exports не затрагиваются. prepareDirectory hook предназначен для native file policy
из .16; physical protection attributes этим host scope ещё не подтверждены.

В закреплённом плагине AudioContext меняет глобальный AVAudioSession даже при
вызове на одном player. Поэтому Swift bridge предоставляет отдельный канал
com.dictai/ios_playback с identity acquire/release. Capture сначала резервирует
сессию, затем запрашивает Dart stopForCapture; ACK приходит после всех уже
начатых plugin commands, stop и dispose. Таймаут 5 секунд не запускает запись;
поздний ACK не действует на новую reservation. Release старого playback owner
не деактивирует уже работающий capture.

При interruption/смене route/потере foreground playback останавливается;
автоматического resume, фонового плеера и lock-screen controls нет. Активная
фоновая микрофонная запись сохраняет собственные правила .06. Ошибка final
plugin bookkeeping после Dart state=disposed показывается отдельно: pinned
plugin уже завершил stop/release, поэтому input безопасно освобождается, но
полное удаление native plugin instance в этой ветке не заявляется.

## Воспроизведение проверок

Cwd `/Users/mxdnght/dictai-app`, Flutter 3.41.3 / Dart 3.11.1, macOS/Xcode,
подготовленные зависимости, без pub/lock обновлений.

```sh
/tmp/dictai-flutter-3.41.3/bin/flutter test --no-pub test/features/results/ios_audio_player_test.dart test/features/results/documents_api_test.dart
/tmp/dictai-flutter-3.41.3/bin/flutter analyze --no-pub --no-fatal-infos
/tmp/dictai-flutter-3.41.3/bin/flutter build ios --simulator --debug --no-pub --target test/features/results/ios_media_smoke_app.dart --dart-define=DICTAI_IOS_MEDIA_PHASE=capture
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl privacy booted grant microphone com.dictai.app
xcrun simctl launch --console --terminate-running-process booted com.dictai.app
```

Explicit target воспроизводит synthetic tone через настоящий audioplayers,
проверяет реальную длительность/seek/pause/resume, подходит к концу WAV и запускает
настоящий IosAudioCapture. Требуется stop request → delegated stop → ACK до
capture recording, затем stale release и валидный новый capture WAV. Это реально
активирует микрофон: использовать тишину/тестовый тон. Backend/account/Keychain
и сеть не используются; fixture adapter принимает единственный synthetic path.

Вторая сборка заменяет define на `DICTAI_IOS_MEDIA_PHASE=timeout`. Delegated stop
выполняется реально, задерживается только ACK. Первый Start обязан завершиться
ошибкой по native timeout; новый capture начинается, поздний ACK не влияет на
него. Обе фазы завершаются cleanup своих файлов, не печатают приватные пути,
аудиобайты и сырой текст native exceptions. Успех требует соответственно
`DICTAI_IOS_MEDIA PASS capture` / `DICTAI_IOS_MEDIA PASS timeout`, одного exit0
от simctl недостаточно. После smoke координатор восстанавливает lib/main.dart
с прежней backend config, не удаляя sandbox/Keychain.

## Текущее evidence

Host test результаты и independent review записываются в TASK-FE-002.13.
Native build/Simulator phases выполняет координатор; до явного результата
они NOT RUN. Physical iPhone, Bluetooth/наушники, lock/interruption и качество
звука NOT RUN и не доказываются синтетическим target или host fakes.


2026-11-17 coordinator повторил обе фазы на iPhone17Pro Simulator/iOS26.5:
`/tmp/dictai-finish-media-capture.log` и `/tmp/dictai-finish-media-timeout.log`
содержат соответствующие PASS markers и validated capture WAV. Xcode builds
5.3s/10.7s PASS. Затем production main build7.4s PASS. Исправление derived
stream decoder errors проверено regression/97 targeted host tests; Swift
handshake после этих smoke не менялся. Physical ограничения выше сохраняются.


## iOS export — TASK-FE-002.14

В detail iOS действие «Скачать и поделиться» предлагает transcript TXT/PDF,
summary TXT/PDF и original WAV. Transcript/summary status независимы; разрешение
попытки download не означает наличия каждого PDF. Перед system sheet требуется
реальный validated200 соответствующего документа. API document-unavailable,
partial/MIME/content validation и network failure показываются безопасно без sheet.
Документы идут через общий авторизованный DocumentsApi, original без job query;
публичные URL/token links и новые API не добавлялись.

Только URL принадлежащего операции временного файла передаётся
UIActivityViewController. Bytes сохраняются без перекодировки, память ограничена
потоком DocumentsApi; channel содержит id/path/MIME, не bytes. Файл живёт до
completion/dismissal activity. Cancel/logout не удаляют его раньше этого момента,
в том числе при failed cancel. Cleanup failure сохраняет ссылку и явный retry.
Пользовательские copies в Files и файлы иных операций не удаляются.

Native принимает только canonical regular files в native temporary/cache roots
с собственным layout `dictai-export-*/dictai-download-*/fixedName`.
Это учитывает pinned path_provider_foundation: getTemporaryDirectory на iOS
возвращает Library/Caches; произвольный sandbox path не разрешён.

Native bridge `com.dictai/ios_document_export`: `share {id,path,contentType}`
завершается `completed`/`cancelled` либо safe FlutterError после окончания окна;
`cancel {id}` действует только на собственную activity. Событие `presented(id)`
поступает после UIKit presentation completion. Ранний cancel откладывает dismiss
до её completion. iPad получает sourceView/sourceRect в bounds foreground presenter.
Контейнер приложения не выставлен в Files, системные permissions не менялись.

```sh
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub test/features/results/ios_document_export_test.dart test/features/results/documents_api_test.dart test/features/results/ios_result_detail_test.dart test/features/results/ios_results_library_test.dart test/features/results/ios_audio_player_test.dart --reporter expanded
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --target test/features/results/ios_media_smoke_app.dart --dart-define=DICTAI_IOS_MEDIA_PHASE=export
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch --console --terminate-running-process booted com.dictai.app
```

Native phase не использует account/backend/сеть. Fixture получает synthetic
TXT, валидный одностраничный PDF и WAV. Для каждого она ждёт настоящий native
`presented`, проверяет наличие input до завершения, посылает stale cancel,
затем own cancel и проверяет пустой owned root. Отдельный цикл отменяет окно
до окончания UIKit presentation animation. Требуются markers
`CHECK export_present_cancel_transcriptTxt`, `CHECK export_present_cancel_summaryPdf`,
`CHECK export_present_cancel_original`, `CHECK export_early_cancel` и
`DICTAI_IOS_MEDIA PASS export`. Проверить на iPhone и iPad Simulator; один
успешный launch не считается PASS. После smoke восстановить production main
прежней public config без удаления sandbox/Keychain.

Host targeted102 PASS и format5/analyze7info PASS записаны в карточке .14.
Фактические native results дописывает coordinator; до этого NOT RUN.
Save to Files/provider writes, внешние share apps, device accessibility,
физический iPhone и поведение системных providers при ошибке остаются NOT RUN;
синтетическая sheet/cancel проверка их не заменяет.


## .14: итог нативной проверки coordinator — 2026-11-18

Cwd frontend, pinned Flutter3.41.3/Dart3.11.1, Xcode26.5/macOS,
iPhone17Pro и iPadPro11M5 Simulator/iOS26.5. Зависимости/lock/signing сохранены.
`flutter build ios --simulator --debug --no-pub --target test/features/results/ios_media_smoke_app.dart --dart-define=DICTAI_IOS_MEDIA_PHASE=export`:
после F03 PASS9.2s, log `/tmp/dictai-finish-export-build-fixed.log`.
`simctl install`/`launch --console --terminate-running-process` на каждом:
PASS, logs `/tmp/dictai-finish-export-iphone-fixed.log` и
`/tmp/dictai-finish-export-ipad-fixed.log`. На обоих есть все четыре CHECK:
TXT/PDF/WAV real presentation + stale cancel + own cancel, early cancel во время
анимации, затем `DICTAI_IOS_MEDIA PASS export`. Файл удерживается до dismissal,
owned staging удаляется. Это реальный UIKit/iPad popover smoke с synthetic
bytes; внешний Files provider Save/write и physical iPhone не выполнялись.

Первый native run обоих FAIL на export_present_transcriptTxt из-за несовпадения
Library/Caches и NSTemporaryDirectory. F03 исправлен до push; первый FAIL не
выдаётся за успешную проверку. Native guard теперь учитывает оба принадлежащих
приложению ephemeral roots и строгое имя owned export/download directories.

Final production main `python3 /tmp/dictai_ios_max_build.py 14-final`: PASS7.8s;
установка/запуск на обоих Simulator PASS, production target/config восстановлены.
Doc checker YAML20/DAG/table/status/owner/scope/149 local links/whitespace PASS;
исходный .DS_Store сохранён вне commit.
