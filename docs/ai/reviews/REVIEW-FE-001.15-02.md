---
id: REVIEW-FE-001.15-02
task_ids: ["TASK-FE-001.15"]
reviewer: /root/review_platform_clients
mode: read-only
status: reviewed
completion: complete
reviewed_at: 2026-11-04
---

# REVIEW-FE-001.15-02

## Scope

Повторная независимая проверка [TASK-FE-001.15](../tasks/TASK-FE-001.15.md)
после [REVIEW-FE-001.15-01](REVIEW-FE-001.15-01.md). База frontend
`80959cc10eacabf45fbf461dbe596030e4e7277c`. Три проверенных Dart-файла новые,
поэтому просмотрены целиком, включая изменения вне tracked diff.

| Файл | SHA-256 проверенной версии |
|---|---|
| `lib/features/record/data/audio_capture.dart` | `194a9a18dda79a11f0d9708e96e7491f09d54f0f7eeb0484e87475ceb60264a9` |
| `lib/features/record/data/microphone_capture.dart` | `7b0b910ded856119bb313118043c8be5399af35a140228ed5aa34bcd5ea7216e` |
| `test/features/record/microphone_capture_test.dart` | `7e59903dab12be340f8fd23b4c83c0bf89c41fe07a1efbfbc3dd24007c591813` |

Сверены task/plan DAG, дальнейший выбор платформы в .17/.23/.24, macOS permissions
и фактические исходники `record` 5.2.1, `record_platform_interface` 1.5.0,
`record_darwin` 1.2.2, `record_linux` 1.3.0 и Flutter engine из закреплённого SDK.
Проверка не меняла исходники, зависимости или статусы карточек.

## Findings

| ID / priority | Файл | Evidence / impact | Disposition |
|---|---|---|---|
| .15-01 F01 P1 | `microphone_capture.dart:42,47` | Linux gate отклоняет Start/Pause/Resume до вызова платформы, `supportsPause` false. Сценарий SIGSTOP без надёжного join больше недостижим через этот adapter. | Fixed with evidence |
| .15-01 F02 P1 | `microphone_capture.dart:47,119` | Default file recorder выключен на Linux. .17 отвечает за mic-only и combined с владением процессами, .23/.24 требуют выбор .17 без fallback. Fake test проверяет отсутствие native create/start на Linux. | Fixed with evidence в .15, интеграция в .17/.23/.24 предстоит |
| .15-01 F03 P2 | `microphone_capture.dart:203–255` | Bounded Stop и независимый dispose идут через публичный RecordPlatform. Pinned Dart MethodChannel не держит AudioRecorder semaphore. В `SwiftRecordPlugin.swift:150–153` dispose снимает recorder ID и отвечает независимо от completion предыдущего Stop. Tests с потерянным ответом и с уже завершённым recorder подтверждают ошибку, сохранённый source, вызов dispose и свободную Dart queue. | Fixed with evidence для зависания при пропавшем callback |
| .15-01 F04 P3 | `PLAN-FE-001.md:191,251` | DAG, таблица и карточка совпадают по .04/.06/.07/.18, `review` и `primary-agent`. | Fixed with evidence |
| F05 P3 | `microphone_capture.dart:28–30,80–95` | В первой версии delta новый ID на каждую запись оставлял два новых native event handlers. Pinned `SwiftRecordPlugin.swift:208–223` регистрирует оба, а `:150–153` удаляет только recorder. Flutter `FlutterChannels.mm` и `FlutterEngine.mm` хранят обработчик по имени канала до cleanup или замены. Исправление использует ID экземпляра повторно после подтверждённого dispose, разные адаптеры получают разные ID. Regression test проверяет оба свойства. | Fixed with evidence |

Открытых actionable findings в проверенном scope нет. Исторический отчёт
сохраняет исходные замечания, их текущий disposition записан здесь.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS 26.2 arm64. Flutter 3.41.3 и Dart
3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Проверка reviewer | Фактический результат |
|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/microphone_capture_test.dart --reporter expanded` | PASS, 19/19 на итоговом snapshot |
| Dart `analyze` для двух capture sources и `microphone_capture_test.dart` | PASS, No issues found |
| Dart `format --output=none --set-exit-if-changed` для тех же путей | PASS, 3 files, 0 changed |
| `git diff --check` по task/plan, `git diff --no-index --check /dev/null <path>` по новым файлам | PASS, whitespace diagnostics нет |
| Сверка Linux gate, native MethodChannel и engine registration | PASS, source review, без реального microphone capture |
| Реальная запись, Pause/Resume, interruption, native build и Linux smoke | NOT RUN, аппаратные проверки относятся к .36/.37 |

## Strengths and residual risk

Подтверждённый Stop выдаёт только валидированный PCM RIFF, отмена диалога оставляет
запись активной, аппаратный adapter защищён от неподходящей платформы. При
неподтверждённом native release handle удерживается для повторной очистки. Новая
запись его не заменяет. Завершение source validation и все аппаратные стадии
остаются отдельными результатами проверки.

Pinned Darwin передаёт путь файла без отдельного признака успешного завершения
AVFoundation. Структурная проверка WAV подтверждает байты и формат, а реальное
поведение при прерывании захвата и аппаратный Pause/Resume нужно проверить в .36.
Повторный ID ограничивает регистрации числом экземпляров adapter. Pinned plugin
по-прежнему сохраняет регистрации до замены или завершения engine, поэтому
интеграции следует переиспользовать adapter в его рабочем lifecycle. Linux
process cleanup проверяется в .17/.37. Отчёт не выставляет `accepted`.
