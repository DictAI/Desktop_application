# Воспроизводимый Flutter/Dart toolchain DictAI

Выбрано в TASK-FE-001.01, 2026-10-25: **Flutter 3.41.3 stable с bundled Dart
3.11.1**, framework revision `48c32af0345e9ad5747f78ddce828c7f795f7159`.
Не заменяйте bundled Dart отдельной установкой. Это точная проверенная версия,
а не рекомендация использовать произвольный latest stable.

## Почему выбран этот SDK

Прежний установленный Flutter 3.38.1 содержит Dart 3.10.0, тогда как исходный
`pubspec.lock` требует Dart >=3.11.0. Поэтому прежние нижние границы
`pubspec.yaml` (Dart >=3.3 / Flutter >=3.19) не описывали воспроизводимую среду.
Теперь там Dart >=3.11.0 <4.0.0 и Flutter >=3.41.3; для команд ниже используйте
именно 3.41.3. Нижняя граница не является фиксацией точной patch-версии.

У Flutter 3.41.3 SDK-пакет `flutter_test` закрепляет `test_api` 0.7.9 и `matcher`
0.12.18, совпадающие с исходным lock. 3.41.0 требует `test_api` 0.7.8, а
проверенные 3.41.4, 3.41.5, 3.41.6 и 3.41.9 требуют 0.7.10 / `matcher` 0.12.19.
Выбор 3.41.3
позволил выполнить `pub get --enforce-lockfile` без изменения lock-файла,
версий пакетов или dependency overrides. Обновление SDK/пакетов после этого
среза требует отдельного выбранного scope и повторных проверок.

Источники: [официальный SDK archive](https://docs.flutter.dev/install/archive),
[macOS release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json),
[Linux release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json),
[flutter_test pubspec 3.41.3](https://github.com/flutter/flutter/blob/3.41.3/packages/flutter_test/pubspec.yaml).

## Получение SDK

Скачайте архив для архитектуры своего host и проверьте SHA-256 **до** распаковки.
Распаковывайте в отдельный доступный пользователю каталог, сохраняя прежний SDK.
Не требуется менять глобальный PATH, shell profile или выполнять `flutter upgrade`.

| Host | Официальный архив Flutter 3.41.3 | SHA-256 |
|---|---|---|
| macOS arm64 | [ZIP](https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.3-stable.zip) | `751b21251c06c437b20c0e9f8584012c2a3efb98fa75652ca34155796110d716` |
| macOS x64 | [ZIP](https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.41.3-stable.zip) | `1886e02d3242f26f1121d2cc62c4122fa311496826f0abafe7b1d68817db61b1` |
| Linux x64 | [tar.xz](https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.3-stable.tar.xz) | `f620731182669befdcd7fc56962def81b0434d0ba4358f363e88059f37656670` |

Хеши и revision сверены с официальными manifest. Linux arm64 bundle 3.41.3
в прочитанном manifest не найден: не подменяйте его x64 SDK без отдельной
проверки окружения. Проверка Linux/macOS x64 исполнения в этой задаче не выполнена.

Для macOS проверьте файл командой `shasum -a 256 <archive.zip>`. После совпадения
распакуйте его через `ditto -x -k <archive.zip> <existing-destination-directory>`.
На Linux используйте `sha256sum <archive.tar.xz>`, затем
`tar -xf <archive.tar.xz> -C <existing-destination-directory>`.
Все пути в угловых скобках — заменяемые локальные значения, не файлы проекта.
Инструкции установки: [официальное руководство](https://docs.flutter.dev/install/manual).

## Команды команды

После распаковки задайте свой реальный путь вместо `/absolute/path/to/flutter`.
Все команды выполняются из корня своего frontend checkout. Явный путь исключает
случайный запуск старого SDK из PATH.

```sh
DICTAI_SDK_DIR=/absolute/path/to/flutter
"$DICTAI_SDK_DIR/bin/flutter" --version --machine
"$DICTAI_SDK_DIR/bin/dart" --version
"$DICTAI_SDK_DIR/bin/flutter" pub get --enforce-lockfile
"$DICTAI_SDK_DIR/bin/flutter" analyze --no-pub
"$DICTAI_SDK_DIR/bin/flutter" test --no-pub
"$DICTAI_SDK_DIR/bin/dart" format --output=none --set-exit-if-changed lib test
```

Сначала подтвердите Flutter 3.41.3 / Dart 3.11.1. Pub должен использовать
существующий lock; при несовместимости не удаляйте lock и не запускайте
`pub upgrade` или `flutter upgrade` для обхода ошибки. Сообщения о более новых
доступных пакетах не являются поручением обновлять их. `--no-pub` после
успешного `pub get` не изменяет dependency graph повторно.

Format-команда выводит `Changed`, но с `--output=none` не записывает файлы.
Ненулевой exit code означает отличия формата; не выдавайте его за PASS.
Постоянный FVM wrapper, новый task runner и CI этой задачей не добавлены.

## Требования к host

macOS: Git, распакованный SDK и права записи в его cache/pub-cache. Для native
build потребуются Xcode command line tools, подходящая локальная подпись и
CocoaPods согласно окружению host. Проект задаёт macOS 13.0 в Podfile; наличие
SDK само по себе не подтверждает native permissions, Keychain или capture.

Linux: Git, распакованный Linux SDK, toolchain CMake/Ninja/clang/pkg-config и
GTK3 development libraries для текущего CMake/GTK runner; для secure-storage
плагина потребуются libsecret и libjsoncpp development/runtime libraries.
Проверяйте реальные prerequisites через `flutter doctor -v` на Linux host.
Аудио pactl/parec/ffmpeg, secret-service, реальные устройства и файловые операции
проверяются отдельно в TASK-FE-001.17/.37. macOS-run не заменяет Linux build.

`flutter doctor -v` полезен для подготовки native host, но не заменяет проверки
приложения. TASK-FE-001.36/.37 выполняют отдельные platform builds/smoke;
установка SDK здесь не разрешает signing/notarization/release или изменение ОС.

## Фактический baseline 2026-10-25

Host macOS arm64. Использован отдельный временный SDK
`/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter` и отдельный `PUB_CACHE`
`/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`. Старый SDK
`/Users/verliiar/flutter` не менялся. Временные каталоги не входят в Git и не
нужны команде: после их удаления SDK воспроизводится из архивов выше.

| Проверка | Результат |
|---|---|
| Официальный macOS arm64 архив, SHA-256 и `flutter --version --machine` / `dart --version` | PASS: Flutter 3.41.3 / Dart 3.11.1, revision и checksum совпали |
| `flutter pub get --enforce-lockfile` | PASS: зависимости получены; исходный lock остался побайтово тем же |
| `flutter analyze --no-pub` | FAIL, exit 1: 13 `prefer_const_constructors` info, 0 errors / 0 warnings |
| `flutter test --no-pub` | FAIL, exit 1: исходный пустой `test/widget_test.dart` не имеет `main`, listener не компилируется; это не прошедший тест и не покрытие приложения |
| `dart format --output=none --set-exit-if-changed lib test` | FAIL, exit 1: проверены 42 файла, 32 требуют форматирования; файлы не записывались |
| SHA-256 source/platform/test files и pubspec.lock относительно базы `fdd95eb` | PASS: функциональный код, platform files, исходные тесты и lock не менялись |
| macOS/Linux native builds, capture, Keychain и real API | NOT RUN: не нужны для scope выбора toolchain; переданы соответствующим будущим задачам |

Ненулевые baseline результаты не скрыты и не исправлены попутно. Исходники
в `lib/` и пустой test сохранены. Тестовую основу создаст отдельно выбранная
TASK-FE-001.06; formatter/lint проблемы должны решаться только в разрешённом
scope. Успешное восстановление SDK/зависимостей не означает зелёный baseline
приложения или готовый release. После изменений кода baseline/evidence нужно
оценивать заново.

Результаты implementation и независимого review — в
[TASK-FE-001.01](../ai/tasks/TASK-FE-001.01.md).
