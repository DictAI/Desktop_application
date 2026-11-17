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
