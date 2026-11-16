# iOS: микрофон и аудиосессия

Текущая реализация [TASK-FE-002.06](../ai/tasks/TASK-FE-002.06.md),
2026-11-17. Проверки Simulator не подтверждают качество записи на iPhone.

## Устройство реализации

`IosAudioCapture` реализует существующий `AudioCapture` и дополнительный
`AudioCaptureEvents`. Factory `RecordNotifier` выбирает его только на iOS.
Desktop adapters и зависимости сохранены. Список desktop devices/system audio
на iOS отсутствует; записывается только микрофон.

В закреплённом `record_darwin 1.2.2` проверены исходники: результат
`prepareToRecord()/record()` не проверяется, delegate завершения пустой, отсутствуют
нужные encoding-error/route/media-services hooks и полное освобождение session.
Поэтому Runner содержит узкий `AudioSessionBridge` на AVAudioRecorder/AVAudioSession,
который удерживает AppDelegate. Обновление plugin/lock не требуется.

MethodChannel `com.dictai/ios_audio`: start/pause/resume/finish/dispose с identity
владельца. EventChannel `com.dictai/ios_audio_events`: status, identity, revision,
owned path и безопасное сообщение. Swift сериализует обращения на main queue;
generation отменяет поздний permission callback, identity защищает новую запись
от старого dispose. Dart сериализует команды и отбрасывает старые revisions/events.
Ошибка потока терминальна: поздний ответ может вернуть путь исходника, но не
возобновить статус recording. Dispose можно повторить после ошибки cleanup.

WAV — PCM16, mono, 16 kHz; после finish проверяются реальные RIFF bytes.
Для каждой записи создаётся отдельный private temporary directory с protection
`completeUntilFirstUserAuthentication` и исключением из backup. Готовый файл
не удаляется при dispose; существующий upload journal получает собственную
durable copy. До передачи в journal файл временный: ОС может очистить его,
восстановление после force kill не обещается.

Session: `.playAndRecord`, `.default`, `.allowBluetooth`, `.defaultToSpeaker`.
Info.plist содержит понятное назначение микрофона и background mode `audio`.
Это настройка активной записи; она не даёт бессрочный background upload/polling.
Interruption или смена input route приостанавливает запись, продолжение только
по нажатию пользователя. Media-services loss/reset и recorder error завершают
сессию с ошибкой и сохранением доступного исходника. Swift проверяет bool
`prepareToRecord()/record()`, deactivation ошибки возвращаются в Dart.

## Повторение проверок

Cwd всех команд — корень frontend. Использован Flutter 3.41.3 / Dart 3.11.1,
Xcode на macOS, iPhone 17 Pro Simulator / iOS 26.5. Подготовленные зависимости,
`--no-pub`; SDK, pubspec/lock, ATS, signing и Keychain этим scope не менялись.

```sh
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub test/features/record/ios_audio_capture_test.dart
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --target test/features/record/ios_audio_smoke_app.dart
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl privacy booted grant microphone com.dictai.app
xcrun simctl launch --console --terminate-running-process booted com.dictai.app
```

Smoke действительно включает микрофон: использовать тишину или тестовый тон.
Он не подключает account/backend, проверяет pause/resume, отмену finish,
идемпотентность, реальный WAV с непустыми samples и нового владельца после cleanup.
Удаляет только собственные тестовые файлы и пустые собственные каталоги.
PASS требует строки `DICTAI_IOS_AUDIO PASS capture`; exit0 от simctl недостаточен.
Вывод не содержит audio bytes, private paths или native exception text: diagnostic
печатает только фиксированные code/stage. Production его не импортирует.

Для отказа в доступе собирается отдельная фаза:

```sh
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --target test/features/record/ios_audio_smoke_app.dart --dart-define=DICTAI_IOS_AUDIO_PHASE=permission_denied
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl privacy booted revoke microphone com.dictai.app
xcrun simctl launch --console --terminate-running-process booted com.dictai.app
```

Требуется `DICTAI_IOS_AUDIO PASS permission_denied`. После тестовых targets нужно
собрать `lib/main.dart` с прежней конфигурацией backend, установить и запустить
production app; удалять приложение или очищать sandbox/Keychain не требуется.

## Evidence и ограничения

Host adapter tests: **21 PASS**, включая terminal stream fault при Start/Pause/
Resume, native revision races, permission/timeout/cleanup retry, WAV validation
и notifier/session cleanup. Лог `/tmp/dictai-ios-batch-audio-terminal-tests.log`.
Независимый reviewer повторил audio/anonymous/confirmation: **45 PASS**, а также
исходный stream-error repro: **1 PASS**, логи
`/tmp/dictai-native-review-audio-tests.log`,
`/tmp/dictai-native-review-stream-fixed.log`.

Native build/link: **PASS**, `/tmp/dictai-ios-batch-audio-build.log`.
Первый capture запуск: **FAIL checkpoint=start**,
`/tmp/dictai-ios-batch-audio-capture.log`; точная причина не установлена.
После исправления Dart terminal race и добавления безопасного stage diagnostic
два последовательных запуска реального native capture: **PASS**, без native
ошибок, `/tmp/dictai-ios-batch-audio-capture-diagnostic.log` и
`/tmp/dictai-ios-batch-audio-capture-repeat.log`. Это не доказывает причину первого
сбоя; она остаётся ограничением runtime evidence.

Physical iPhone: **NOT RUN** — нет подготовленной подписи/устройства.
Обязательны: слышимый звук и длительная запись, блокировка/background,
звонок/Siri, Bluetooth/проводная гарнитура, отзыв разрешения, media-services
reset, нехватка места и тепловые/памятные ограничения. Host events проверяют
обработчики, но не аппаратные notifications. Полная .06 не verified/accepted.


Продолжение 2026-11-17: ранее собранная permission-denied фаза установлена в тот же
Simulator, microphone permission отозван через simctl. Консоль native target:
`DICTAI_IOS_AUDIO START permission_denied`,
`DICTAI_IOS_AUDIO native=permission_denied stage=none`,
`DICTAI_IOS_AUDIO PASS permission_denied`; launch завершился exit0.
Это фактический native permission API, не mock; физический permission revoke всё
ещё NOT RUN. Runtime сохраняет прежний сторонний warning дублирующего FileUtils
в file_picker/OSAnalytics; дымовой тест завершился PASS, plugin не изменялся.

После smoke main target восстановлен с прежней public gateway config:
`flutter --no-version-check build ios --simulator --debug --no-pub --target lib/main.dart --dart-define-from-file=/tmp/dictai-ios-nav-gateway.json` —
PASS, Xcode12.3s; install/launch PASS, microphone grant восстановлен.
Screenshot `/tmp/dictai-ios-resume-production.png` визуально подтверждает обычный
Record и нижние вкладки, без тестового экрана. Sandbox/Keychain не удалялись.
Повтор полного regression: 658 PASS, changed/new Dart format27 PASS, analyze
PASS с7 прежними info. Global format lib/test FAIL на10 старых файлах вне scope;
`--output=none` сохранил их. Логи `/tmp/dictai-ios-resume-{full-tests,scoped-format,format,analyze,production-build}.log`.
Независимые актуальные отчёты: [audio/Files](../ai/reviews/REVIEW-FE-002.06-01.md)
и [общий batch](../ai/reviews/REVIEW-FE-002.04-02.md).

Оба независимых отчёта завершены `reviewed/complete`, открытых actionable findings
нет. Documentation/preservation checker `/tmp/check_dictai_ios_resume.py` PASS;
исходники/tests/native этого продолжения побайтово сохранены. Наблюдавшиеся
permission-denied stdout markers отдельно зафиксированы в
`/tmp/dictai-ios-resume-permission-denied.log` (выдержка из tool output).
