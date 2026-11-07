---
id: TASK-FE-001.16
plan: PLAN-FE-001
title: "Сделать macOS system+microphone capture совместимым и ограниченным по памяти"
status: review
owner: /root/finish_native_teardown
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.15"]
backend_tasks: ["TASK-002.08", "TASK-002.16"]
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "macos/Runner/SystemAudioRecorder.swift"
  - "macos/Runner/AppDelegate.swift"
  - "lib/features/record/data/system_audio_service.dart"
  - "lib/features/record/data/macos_audio_capture.dart"
  - "macos/Runner/Info.plist"
  - "macos/Runner/DebugProfile.entitlements"
  - "macos/Runner/Release.entitlements"
  - "macos/RunnerTests/RunnerTests.swift"
  - "test/features/record/macos_capture_test.dart"
  - "docs/ai/tasks/TASK-FE-001.16.md"
planned_paths:
  - "lib/features/record/data/macos_audio_capture.dart"
  - "test/features/record/macos_capture_test.dart"
delivery_stage: current
---

# TASK-FE-001.16: Сделать macOS system+microphone capture совместимым и ограниченным по памяти

## Goal

Один macOS adapter для двух режимов с bounded conversion/mix и проверенным WAV output.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Swift сначала пишет AAC temp, затем readConvertedBuffer читает весь файл; mix выделяет полные buffers. Anonymous macOS system flag фактически не подключён.

**Целевое:** Один macOS adapter для двух режимов с bounded conversion/mix и проверенным WAV output.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.15](TASK-FE-001.15.md).
Backend traceability: TASK-002.08, TASK-002.16
API: U01, U02.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Диалог реализуется Dart-задачей .49; native scope не расширяется ради новой навигации.

В .16 adapter/channel tests моделируют cancel/confirm intent без готового dialog;
итоговое UI/native взаимодействие проверяет .36 после .49. Обратного prerequisite нет.

## Этап и решение — 2026-11-02

Нужна: bounded macOS capture; native/память проверять на настоящем host.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Открытый/отменённый Stop dialog не посылает native stop; confirmed finish вызывает его один раз, при этом сохраняются Keychain entitlements из .04.
- [ ] MethodChannel и Swift согласованы; permission denial/no display/no samples/repeated stop завершаются без зависания или ложного success.
- [x] Conversion/mix идут ограниченными блоками, UI не блокируется полным чтением длинной записи; память измерена отдельно от фейкового теста.
- [x] Final WAV соответствует RIFF PCM/float без RF64/EXTENSIBLE; native bytes проверены теми же input правилами, включая duration/size.
- [x] Если combined pause не поддерживается синхронно, UI не предлагает его; downgrade до mic-only не выполняется молча.
- [x] Правки entitlements/Info.plist только необходимые для выбранного capture; signing/notarization/добавочные разрешения не выполняются скрыто.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

2026-11-06, cwd `/Users/verliiar/Desktop_application`, macOS arm64,
Flutter 3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.
Новые packages и lockfile changes не требовались. Native compiler — установленный
Xcode toolchain через `xcrun swiftc`; module cache помещён в `/tmp`, поскольку
стандартный cache за пределами workspace недоступен.

| Command / scenario | Actual / status | Limitation |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/macos_capture_test.dart test/features/record/microphone_capture_test.dart --reporter expanded` | PASS, 44 tests, exit 0. 25 .16 и 19 .15 regressions, включая повтор cleanup после native STOP_FAILED. Лог `/tmp/dictai-macos16-20261106/dart-tests.log` | MethodChannel и microphone подменены только в тестах. Первый restricted запуск не смог открыть служебный localhost socket, повтор с разрешённым доступом прошёл |
| `flutter analyze --no-pub lib/features/record/data/system_audio_service.dart lib/features/record/data/macos_audio_capture.dart test/features/record/macos_capture_test.dart` через тот же pinned SDK | PASS, No issues found | Scoped analyze, не проверка всего незавершённого приложения |
| `dart format --output=none --set-exit-if-changed` по тем же трём paths | PASS, 3 files, 0 changed | Проверен final Dart diff |
| `flutter build macos --debug --no-pub` через pinned SDK с существующим local `XCODE_XCCONFIG_FILE` | PASS, `build/macos/Build/Products/Debug/Dict AI.app` | Использован ранее настроенный локальный signing override, Xcode project/scheme не менялись. Capture permission не запрашивалось |
| Native `RunnerTests` с настоящими AVAudioFile/AVAudioConverter | PASS, 12 tests после F01 fix. Stereo 48k/44.1k→mono16k, mix разной длины, clipping, invalid/empty input, existing destination preservation, cancellation до и во время conversion, длинный synthetic file; failed/timeout stop→retry, coalesced stops и late callbacks разных streams | Запущен standalone XCTest suite с точными `AudioStreamTeardown` и `BoundedWAV` из текущего native source, без Flutter host. `DICTAI_AUDIO_STANDALONE` исключает только `@testable import Dict_AI`. Test source и XCTest assertions настоящие |
| `DICTAI_AUDIO_TEST_SECONDS=600 /usr/bin/time -l /tmp/dictai-macos16-20261106/native-tests` против обычного short run | PASS, 8/8 в обоих memory проходах до F01; BoundedWAV после F01 не менялся, lifecycle delta отдельно прошла 12/12. Max RSS short 26,198,016 bytes, long 26,132,480 bytes. Native 10-minute 48k stereo float input — около 230.4 MB, конвертируется блоками 4096 frames. Long run 12.14s | Это synthetic offline conversion/mix, не память live ScreenCaptureKit/Flutter UI и не 2-hour performance benchmark. Логи `native-memory-short.log` / `native-memory-long.log` в том же temp каталоге |
| `dart /tmp/dictai-macos16-20261106/validate.dart` через pinned Dart | PASS. Существующий `.18 WavValidator` принял настоящий native mix: PCM16/16000/mono, 1600 frames, 3244 bytes | Временный harness импортирует текущий validator, не копирует его реализацию. Input полностью синтетический |
| `plutil -lint` Info.plist и обеих entitlements; scoped `git diff --check` и no-index checks новых Dart files | PASS | .16 не меняла Info.plist, Keychain/capture entitlements, AppDelegate, Xcode project/scheme или dependencies |
| Независимый `REVIEW-FE-001.16-01` | PARTIAL, F01/P2 найден и исправлен implementer, ожидает independent delta | Автор не закрывает finding сам |
| Живые permissions, no-display/no-samples/interruption, реальное совмещение mic+system, live RSS, Release и полноценный UI Stop/leave | NOT RUN, остаются в .36 после интеграции .23/.24/.49 | Dart channel error tests и чтение native branch не объявляются аппаратным smoke. Linux не проверяется этой задачей |

Standalone native verification воспроизводится без изменения Xcode project:
в temp-файл копируется без изменений участок `SystemAudioRecorder.swift`, начиная
с `final class AudioStreamTeardown`, включая BoundedWAV до EOF, с imports Foundation/AVFoundation. `swiftc` компилирует его
вместе с текущим `RunnerTests.swift`, define `DICTAI_AUDIO_STANDALONE`,
Xcode XCTest framework и Swift overlay (`MacOSX.platform/Developer/usr/lib`).
Временный `main.swift` запускает `RunnerTests.defaultTestSuite`, проверяет
`testRun.hasSucceeded` и возвращает ненулевой exit при failure. Native test harness
и compiler outputs находятся в `/tmp/dictai-macos16-20261106/` и не включаются в Git.
Существующий Xcode RunnerTests TEST_HOST указывает на старое имя приложения.
Обычный `xcodebuild test` здесь не заявлен выполненным, изменение чужого project
не включалось в задачу. Standalone выполняет те же двенадцать committed test methods.

## Result

Реализован exact scope .16, готов к независимому review, не accepted.

- `macos/Runner/SystemAudioRecorder.swift`: capture/writer state сериализован,
  callbacks отвечают один раз, ошибки разрешений/дисплея/no samples/записи/timeout
  не выдают success. Offline conversion/mix работают в отдельной очереди фиксированными
  блоками через persistent AVAudioConverter. EOF проверяется по framePosition перед
  read: native synthetic tests обнаружили и устранили реальное исключение AVAudioFile
  при чтении после EOF. Final output — обычный RIFF PCM16/mono16k, лимит два часа,
  публикация atomic rename только после успешной записи header и закрытия файла.
- Native `cancelRecording` отменяет pending capture и offline jobs. Поток прекращается
  через ScreenCaptureKit, ответ cleanup bounded; processing отменяется между блоками.
  Cancellation и финальный rename синхронизированы, поздний callback не публикует
  успешный результат новой сессии. Это локальный MethodChannel, не backend API.
- `system_audio_service.dart`: прежние методы совместимы, уникальные destinations,
  bounded deadlines и независимая отмена. При cancellation/timeout caller ждёт
  acknowledgement перед удалением только собственного неуспешного mix destination.
- `macos_audio_capture.dart`: общий combined adapter для будущего подключения обоих
  upload modes. Cancel Stop не останавливает inputs; confirmed finish сериализован,
  дублирующие нажатия не запускают второй stop/mix. Оба inputs завершаются даже при
  отказе одного. Нет mic-only fallback, false pause/resume или публикации файла после
  dispose. Actual final mixed file проверяется существующим `.18 WavValidator`.
- `macos/RunnerTests/RunnerTests.swift` и `test/features/record/macos_capture_test.dart`
  содержат проверки реальной native конвертации и deterministic Dart lifecycle.
  Полезные исходники сохраняются при ошибке; adapter не удаляет captured inputs
  при forced dispose. Внешние files и backend не затронуты.

Проверки runtime ScreenCaptureKit/физических устройств и живого Flutter UI остаются
неподтверждёнными до .36, что отражено открытым вторым acceptance criterion.
Эта карточка не приписывает .16 готовую UI-интеграцию .23/.24/.49 и не выставляет
автоматическую приёмку. Отдельный reviewer проверяет итоговый diff и ограничения.

## Review delta F01 — 2026-11-06

[Независимый review .16-01](../reviews/REVIEW-FE-001.16-01.md) обнаружил P2:
неподтверждённый stop очищал capture и терял retryable stream handle. Исправление
выбрано coordinator в рамках текущего поручения. F01 не объявляется закрытым
автором, ожидается независимый delta.

Native `AudioStreamTeardown` сохраняет closure с конкретным SCStream до успешного
stop callback. Ошибка/timeout оставляют его в recorder registry, а `start` отказывает
с CLEANUP_PENDING. Повтор cancel вызывает настоящую повторную попытку stop.
Параллельные cancel/ordinary Stop присоединяются к одной попытке. Только confirmed
callback удаляет запись соответствующего stream; stale error и duplicate callback
не меняют другой stream и не отвечают второй раз. Поздний success прежней попытки
может подтвердить только этот же stream. Обработка всех transitions сериализована
в captureQueue. Capture writer и pending Flutter replies отменяются отдельно,
без потери cleanup ownership. Это внутренний lifecycle seam, не новый слой API.

После исправления PASS: 44 Dart tests, scoped analyze No issues, final Debug build,
12 native tests (8 conversion + 4 teardown-state), format 3 files/0 changed, plist и
scoped diff. Новый Dart regression проверяет fail cleanup→повторный настоящий native
cancel без ложного idempotent success. Native tests воспроизводят failed stop,
потерянный callback/timeout, фактический retry, shared in-flight и поздние callbacks
двух разных stop operations. Лог `/tmp/dictai-macos16-20261106/native-delta.log`.
Исходный memory evidence сохранён только для неизменённого offline BoundedWAV;
новые tests не заменяют hardware ScreenCaptureKit проверки .36.

## Повторная проверка остановки, 2026-11-07

После `SCStreamDelegate.didStopWithError` ScreenCaptureKit уже остановил поток.
Обработчик завершает совпавший активный capture с ошибкой прерывания и подтверждает
остановку записи в registry того же stream. Подтверждение отменяет таймер и завершает
ожидающие ответы один раз, в том числе когда активный capture уже освобождён после
cancel. Поздние stop callbacks и повторное уведомление об остановке не меняют исход.

В `RunnerTests.swift` добавлена регрессия failed stop → retry → подтверждение от
delegate. Проверены повторное уведомление, поздние success/error callbacks и отсутствие
третьего native stop после подтверждения.

| Проверка из `/Users/verliiar/Desktop_application` на macOS arm64 | Результат |
|---|---|
| Standalone `RunnerTests` с текущим исходником `AudioStreamTeardown` и `BoundedWAV`, Xcode XCTest overlay и private-framework rpath | PASS, 13 tests, 0 failures. Лог `/tmp/dictai-macos16-20261107/native-tests.log` |
| Pinned Flutter 3.41.3 `flutter build macos --debug --no-pub` с существующим локальным signing override | PASS, `build/macos/Build/Products/Debug/Dict AI.app`. Лог `/tmp/dictai-macos16-20261107/debug-build.log` |
| `plutil -lint` и scoped `git diff --check` | PASS |
| Живой захват и разрешения ScreenCaptureKit | NOT RUN, проверка .36 |

Swift-изменения и регрессия переданы на независимую проверку .16-02.

2026-11-07. Независимый [REVIEW-FE-001.16-02](../reviews/REVIEW-FE-001.16-02.md)
завершён. F01/F02 закрыты, открытых замечаний нет. Повторно прошли 13 native XCTest,
44 связанных Dart-теста, scoped analyze, format, plist и whitespace. macOS Debug
build прошла после последнего исправления. Реальный capture и разрешения проверяются
в .36. Статус review, приёмка владельцем отдельно.
