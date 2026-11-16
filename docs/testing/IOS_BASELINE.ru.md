# iOS baseline — TASK-FE-002.01

Дата аудита: 2026-11-16. Owner: `/root/ios_baseline`. Репозиторий:
`/Users/mxdnght/dictai-app`, исходный HEAD `260b149`, исходный git status чистый
по baseline координатора `/tmp/dictai-ios-five-baseline.json`. На старте .01
присутствовали только назначенные координатором изменения карточек/реестра/плана.

Исходная .01 — аудит окружения и native manifests. Актуальные результаты .02
приведены первыми ниже; исторические ограничения не описывают текущий запуск.

## Текущий Simulator build/launch — TASK-FE-002.02, 2026-11-16

Пользователь установил runtime iOS26.5 build23F77. На Flutter3.41.3 из
постоянного каталога выполнена actual сборка с исходными dependencies:

```sh
CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /Users/mxdnght/.local/share/dictai/flutter/3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>
```

Cwd frontend, macOS26.5.2 arm64/Xcode26.5/CocoaPods1.16.2. **PASS**, exit0,
Xcode193.9s, `build/ios/iphonesimulator/Runner.app`. На выбранном iPhone17 Pro
выполнены `simctl boot`, `bootstatus -b`, `install` и `launch com.dictai.app`:
все exit0. Визуально проверен screenshot существующего экрана Sign In/Sign Up;
Runner остаётся запущенным. Первый snapshot белого launch screen не засчитан
как UI PASS; последующий screenshot подтверждает отрисованную форму.

Evidence: `/tmp/dictai-ios-simulator-build.log`,
`/tmp/dictai-ios-simulator-launch.log`, `/tmp/dictai-ios-simulator-login.png`.
Полные команды/границы — [карточка .02](../ai/tasks/TASK-FE-002.02.md).
Native files/pubspec/lock неизменны в этом проходе относительно baseline334.
Обновление runtime не требует повторения552 unit/widget tests и analyze на тех
же Dart sources/SDK. Native manifest checker повторён: PASS.
Новый независимый [REVIEW-FE-002.02-03](../ai/reviews/REVIEW-FE-002.02-03.md)
завершён: reviewed/complete, findings нет; .03 dependency gate открыт.

Это scaffold/entry evidence. Real login, Dio HTTPS, native Keychain и физический
iPhone NOT RUN в .02. Подпись физического iPhone недоступна по ответу пользователя;
Simulator не закрывает её или обязательные lock/unlock/reinstall/restore .03.
Ниже сохранена история предыдущих проверок до установки runtime.

## Toolchain Flutter3.41.3 и предыдущая проверка без runtime — 2026-11-16

Пользователь явно разрешил отдельный Flutter3.41.3. Primary-agent установил его
из официального Git tag3.41.3. Постоянный путь:
`/Users/mxdnght/.local/share/dictai/flutter/3.41.3`, HEAD
`48c32af0345e9ad5747f78ddce828c7f795f7159`, engine
`327ed814500baca0480a02f8555aa84a9afe32bf`, Dart3.11.1, DevTools2.54.1.
Из-за shallow checkout tag команда показывает channel `[user-branch]`, а не
stable branch; версия и revision подтверждены git и выводом Flutter. Это
локальный SDK, не project SDK pin-файл. Bootstrap/tests выполнялись через
`/tmp/dictai-flutter-3.41.3`; после переноса этот путь оставлен как symlink на
постоянный SDK, git revision и --version повторно совпали. Повторный enforced
pub по постоянному пути подготовил package config для дальнейших запусков.
Команды ниже используют сохранённый alias того же SDK; глобальный Flutter3.44
не перенастраивался.

Установка и bootstrap:

```sh
git clone --depth 1 --single-branch --branch 3.41.3 https://github.com/flutter/flutter.git /tmp/dictai-flutter-3.41.3
CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check --version
```

Current cwd `/Users/mxdnght/dictai-app`, macOS26.5.2 arm64, Xcode26.5,
CocoaPods1.16.2. Это проверки **actual project** с исходным `pubspec.lock`, а не
изолированного Flutter3.44 candidate. Сравнение SHA-256 с baseline332 files
`/tmp/dictai-ios-sdk3413-baseline.json` подтверждает неизменность pubspec/lock.
Новые зависимости или изменения UploadModal не требовались.

После переноса SDK выполнены --version/git HEAD (тот же revision), enforced pub
по постоянному пути (exit0, SHA lock прежний) и повторный simulator build
(конкретно `/Users/mxdnght/.local/share/dictai/flutter/3.41.3/bin/flutter` с теми
же CI/SPM/define/no-pub flags). Pod install615ms PASS, build exit1 с тем же
missing destination. Generated package config и Flutter xcconfig теперь
ссылаются на постоянный путь. Логи: `/tmp/dictai-ios-sdk3413-persistent-pub.log`,
`/tmp/dictai-ios-sdk3413-persistent-build.log`; device identifiers удалены.
Повторять552 теста после переноса тех же SDK файлов не требовалось: code/lock
не менялись, исходный test evidence относится к тем же binary/revision.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check pub get --enforce-lockfile` | Exit0, Got dependencies; package configuration создана, pubspec/lock hashes сохранены | PASS | Локальный SDK, не новая версия project dependencies |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded` | Exit0, 552 tests passed | PASS | Unit/widget regression, не запуск iOS приложения |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit0, 9 прежних prefer_const_constructors info, errors/warnings нет | PASS | Не native compile/link |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | Pod install PASS759ms; затем exit1: нет generic iOS Simulator destination, iOS26.5 platform/runtime не установлен | FAIL | Compiling/linking/launch не подтверждены |
| `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/dictai-ios-native-sdk3413 CODE_SIGNING_ALLOWED=NO build` | Exit70, Found no destinations for scheme Runner and action build | FAIL | Прямой SDK build также требует подготовленную Xcode platform |
| `xcodebuild -checkFirstLaunchStatus`; `xcrun simctl list runtimes` | Exit0 для first launch status; список runtimes пуст | PASS для инвентаризации | Не app smoke; iPhone signing по-прежнему недоступна |
| Protected lib/test/macOS/Linux/pubspec/lock/rules/architecture hashes against fresh baseline | 142 unchanged | PASS | Посторонний .DS_Store не откатывался |

CocoaPods создал **actual** `ios/Podfile.lock` и штатно дополнил
`ios/Runner.xcodeproj/project.pbxproj`,
`ios/Runner.xcworkspace/contents.xcworkspacedata`. Эти пути заранее входят в .02
scope. Registrants вручную не менялись; Pods/symlinks/generated/build artifacts
игнорируются. Native source manifest теперь42 files (40 SDK template + Podfile
+ Podfile.lock). `.metadata` сохраняет создание iOS на Flutter3.44 и прежние
root/macOS revisions: выполнение3.41.3 не подменяет provenance генерации.

Неизменённые AppDelegate/SceneDelegate/framework plist совместимы с templates
3.41.3, locked SDK pins совпадают; source-проверка не заменяет native build.
Отличие двух ListTile failures Flutter3.44 подтверждено полным regression:
на3.41.3 оба existing сценария прошли без изменения исходников. Старый candidate
lock patch не применяется и больше не нужен для выбранного решения.

Логи команд без credentials: `/tmp/dictai-ios-sdk3413-pub.log`,
`/tmp/dictai-ios-sdk3413-tests.log`, `/tmp/dictai-ios-sdk3413-analyze.log`,
`/tmp/dictai-ios-sdk3413-build.log` (device identifiers удалены) и
`/tmp/dictai-ios-sdk3413-native-build.log`. Сборка/запуск Simulator и device
Keychain/auth остаются blockers .02/.03. .04/.05 не разблокированы. Новый
независимый [REVIEW-FE-002.02-02](../ai/reviews/REVIEW-FE-002.02-02.md)
текущего delta завершён: reviewed/complete, F01 P3 fixed with evidence, открытых
findings нет; ниже
сохранены исторические результаты3.44, не текущее SDK/lock состояние.

## Предыдущая проверка исполнения .02 с Flutter3.44 — 2026-11-16

Owner `.02`: `/root/ios_runner`. После checks/review `.01` добавлен CocoaPods
Runner текущим SDK по [точному manifest](IOS_SCAFFOLD_MANIFEST.ru.md). Видимое
имя `DictAI`, bundle ID `com.dictai.app`, minimum iOS 13.0. Team/подпись не
назначены; capabilities, ATS exceptions и доверенные сертификаты не добавлялись.
Проектный pubspec и lock сохранены. Подготовка зависимостей и native build
фиксируются ниже отдельно от статического аудита `.01`.

При дальнейшей сверке найдено ограничение точного lock: Flutter 3.44.0
`packages/flutter_test/pubspec.yaml` требует `test_api 0.7.11`,
`matcher 0.12.19`, `meta 1.18.0`, тогда как проектный lock содержит соответственно
`0.7.9`, `0.12.18`, `1.17.0`. Удовлетворение минимальным SDK constraints в `.01`
не доказывает, что SDK-owned dependencies совместимы с неизменным lock.
Обновление SDK/lock ради обхода проверки не входит в `.02`. Координатор выполнил
`CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check pub get --enforce-lockfile`
из корня frontend: **FAIL**, exit 65, `Would change 3 dependencies`,
`Unable to satisfy pubspec.yaml using pubspec.lock`. У `pubspec.yaml` и
`pubspec.lock` сохранён исходный SHA-256. Согласованная package configuration не подготовлена;
`flutter build ios --simulator --debug` — **NOT RUN**, а не build PASS/FAIL.
`--no-pub` с несогласованными dependencies не использовался.

Поэтому `.02` содержит реализованный scaffold, но остаётся **blocked**.
`ios/Podfile.lock` пока не создан: native installation/build следуют только
после успешной подготовки locked dependencies. Проверенный launch существующего
приложения также остаётся незавершённым критерием. Статические `plutil`, native
manifest/XML/assets и Ruby Podfile syntax checks — PASS; unit/widget/native
runtime результатами они не являются. Исправление SDK/lock требует отдельного
решения; ни Flutter SDK, ни dependencies в репозитории не обновлялись.

На момент подготовки `.02` runtime Simulator не установлен. Координатор начал
загрузку matching iOS 26.5 arm64 (`8.52 GB`) и отменил её после медленной передачи
примерно `27 MB`. Tool сообщил `Download was cancelled`: подготовка runtime
отменена, а не PASS; Simulator launch пока NOT RUN. Пользователь сообщил, что
signing сейчас недоступна. Это внешние ограничения запуска, не проверка приложения.

### Изолированная проверка возможного решения, не actual repository PASS

Координатор подготовил candidate вне репозитория:
`/var/folders/nk/dn15wj451d90zxf_gxkbdgjr0000gn/T/dictai-ios-lock-proposal-_m_ssbgg`.
В него скопированы исходники/тесты/Runner и предложен lock для установленного
Flutter 3.44.0. Полный lock delta: три версии и их archive SHA-256
(`matcher 0.12.18→0.12.19`, `meta 1.17.0→1.18.0`, `test_api 0.7.9→0.7.11`),
плюс `sdks.flutter >=3.35.6→>=3.41.3`. Последний минимум уже указан в pubspec,
поэтому declared минимум приложения не меняется. Patch:
`/tmp/dictai-ios-lock-proposal.patch`; actual lock SHA-256
`d1e569ba3b1d2b319ee34fbc8cfb87f2db21cc10f85b6c791c5468759985def0`, candidate
`7582a08dc08e84556dab3f8d4dd524acf1816a4920e4db0a52f31b41fa1e4d67`.
Actual pubspec/lock и native source freeze сохранены; candidate не применён.

| Candidate command / scenario | Actual | Status | Ограничение |
|---|---|---|---|
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check pub get` | Exit 0, Changed 3 dependencies; создан candidate package config | PASS | Только временная копия с предложенным lock, не успешный enforced pub проекта |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | `pod install` завершён за 138.1 s; build exit 1: `Unable to find a destination matching {generic:1,platform:iOS Simulator}`, iOS 26.5 platform не установлена | FAIL | Native lock создан только в candidate; runtime отсутствует, compile и launch не подтверждены |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check test --no-pub --reporter expanded` | Exit 1, 550 PASS / 2 FAIL из 552 | FAIL | Новый ListTile assertion Flutter 3.44 в прежнем UploadModal; это не PASS приложения |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit 0, 9 info | PASS | Только candidate; не устраняет два failing tests/native runtime blocker |
| Сверка tagged Flutter 3.41.3 `packages/flutter_test/pubspec.yaml` | Три SDK-owned pin совпадают с actual lock | PASS | Source-only; отдельный SDK 3.41.3 не установлен, его pub/build/tests NOT RUN |

Оба failing tests — `test/features/record/anonymous_flow_test.dart`
(owner-only shared WAV) и `test/features/workspace/profile_free_flow_test.dart`
(empty workspace WAV). Assertion: `background color or ink splashes may be
invisible`; CheckboxListTile находится под decorated Container в существующем
`lib/features/record/presentation/upload_modal.dart` (90–100, 371–381).
Этот файл вне `.02`, исправления или маскировка assertion не выполнялись.
Предложение обновить три зависимости **не считается полностью проверенным**.
Candidate tests/analyze logs находятся в `/tmp/dictai-ios-lock-proposal-tests.log`
и `/tmp/dictai-ios-lock-proposal-analyze.log`; персональные device данные
из вывода в документацию не перенесены.

CocoaPods изменил только candidate project/workspace integration и создал
candidate Podfile.lock. Эти файлы из временной копии не перенесены в actual
Runner. Требуется отдельный выбор решения SDK/lock и, для Flutter 3.44, выбор
исправления UploadModal; новая реализация вне selected scope не назначается.

## Toolchain

| Компонент | Фактическое состояние | Evidence |
|---|---|---|
| Host | macOS 26.5.2, build 25F84, arm64 | `sw_vers`, `uname -m` — PASS |
| Flutter | 3.44.0 stable, revision `559ffa3f75e7402d65a8def9c28389a9b2e6fe42` | Координатор: `CI=true flutter --no-version-check --version` — PASS; совпадает с локальным `bin/cache/flutter.version.json` и SDK git HEAD |
| Dart | 3.12.0 stable, macos_arm64 | `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart --version` — PASS; также вывод Flutter координатора |
| Xcode | 26.5, build 17F42 | `xcodebuild -version` — PASS |
| Developer directory | `/Applications/Xcode.app/Contents/Developer` | `xcode-select -p` — PASS |
| SDKs | iPhoneOS 26.5, iPhoneSimulator 26.5 | Координатор: `xcodebuild -showsdks` — PASS |
| CocoaPods | 1.16.2 | `pod --version` — PASS |
| Simulator | На время аудита 0 available devices, runtimes отсутствуют | `xcrun simctl list devices available` — PASS для инвентаризации; координатор: `xcrun simctl list runtimes` — PASS, список пустой |
| iPhone | На время аудита 0 online, 1 offline iOS 18.5 | `xcrun xctrace list devices` — PASS для инвентаризации; имена/UDID в документацию не перенесены |
| Engine artifacts | `ios`, `ios-profile`, `ios-release` содержат `Flutter.xcframework` | Проверка существования файлов — PASS; не проверка native linking |

Проект задаёт Flutter `>=3.41.3`, Dart `>=3.11.0 <4.0.0` в
[pubspec.yaml](../../pubspec.yaml); [pubspec.lock](../../pubspec.lock) задаёт Dart
`>=3.11.0 <4.0.0`, Flutter `>=3.35.6`. Установленный SDK удовлетворяет этим
ограничениям. Отдельного pin-файла SDK в проекте нет: для воспроизводимости .02
использует зафиксированный здесь установленный revision, без SDK upgrade.

Обычный `flutter --version` в sandbox сначала завершился ошибкой записи SDK cache,
а повтор вне sandbox завис в сетевой проверке версии Git. Подвисшая команда
остановлена; вариант `CI=true ... --no-version-check` координатора завершился
успешно. Аналогичные первоначальные sandbox-ошибки simctl/xctrace не принимаются
за отсутствие устройств: выше приведена повторная инвентаризация вне sandbox.
Пакеты/SDK/lock проекта в .01 не изменялись.

## Deployment target и pinned плагины

Выбран **iOS 13.0**: максимум минимальных версий текущего Flutter engine/template
и native реализаций из lock. Native сборка всей комбинации остаётся проверкой .02.

| Direct package / lock | iOS implementation / lock | Минимум iOS | Проверенный источник |
|---|---|---|---|
| `record 5.2.1` | `record_darwin 1.2.2` | 11.0 | Cached `record_darwin-1.2.2/ios/record_darwin.podspec:17` |
| `audioplayers 6.6.0` | `audioplayers_darwin 6.4.0` | 13.0 | Pinned archive: `darwin/audioplayers_darwin.podspec`, `darwin/audioplayers_darwin/Package.swift` |
| `flutter_secure_storage 9.2.4` | В том же пакете | 9.0 | Cached `flutter_secure_storage-9.2.4/ios/flutter_secure_storage.podspec:18` |
| `file_picker 8.3.7` | В том же пакете | 12.0 | Cached `file_picker-8.3.7/ios/file_picker.podspec:19` |
| `path_provider 2.1.5` | `path_provider_foundation 2.5.1` | 13.0 | Cached `path_provider_foundation-2.5.1/darwin/path_provider_foundation.podspec:18` |
| `shared_preferences 2.5.5` | `shared_preferences_foundation 2.5.6` | 13.0 | Cached `shared_preferences_foundation-2.5.6/darwin/shared_preferences_foundation.podspec:18` |
| `url_launcher 6.3.2` | `url_launcher_ios 6.3.6` | 13.0 | Cached `url_launcher_ios-6.3.6/ios/url_launcher_ios.podspec:23` |
| Flutter 3.44.0 | Engine / Runner template | 13.0 | SDK `packages/flutter_tools/bin/podhelper.rb` engine podspec; `templates/app/ios.tmpl/Runner.xcodeproj/project.pbxproj.tmpl` |

Cached package sources прочитаны из `~/.pub-cache/hosted/pub.dev/`. На старте
`audioplayers 6.6.0` и `audioplayers_darwin 6.4.0` в cache отсутствовали, как и
проектный `.dart_tool/package_config.json`. Для native manifest координатор скачал
только `https://pub.dev/api/archives/audioplayers_darwin-6.4.0.tar.gz` в `/tmp`;
SHA-256 `c994b3bb3a921e4904ac40e013fbc94488e824fd7c1de6326f549943b0b44a91`
совпал с lock. Архив изучен без изменения pub cache/зависимостей проекта.
Подготовка всех pinned dependencies потребуется в .02; обновлять lock для
обхода несовместимости нельзя. Flutter/Dart constraints прочитанных пакетов
совместимы с установленным SDK; это source evidence, не runtime test.

## Runner и уровни проверки

Точный список scaffold и способ безопасного переноса приведены в
[IOS_SCAFFOLD_MANIFEST.ru.md](IOS_SCAFFOLD_MANIFEST.ru.md).

- Simulator debug build не требует регистрации App ID или provisioning profile.
  Отсутствие runtime не исключает попытку compile при установленном simulator SDK;
  запуск/вход в приложение без runtime подтвердить нельзя.
- Физический iPhone нужен для Keychain lock/unlock/reinstall, permissions,
  микрофона, background audio, interruptions, Files и suspend/resume. На момент
  аудита online устройства нет; пользователь сообщил, что подключит iPhone и
  укажет тестовый HTTPS-адрес. Доступность следует перепроверить в .03.
- Подписанный candidate требует устройства/учётной записи владельца, team,
  provisioning и отдельно разрешённого signing/release scope. Эти доступы
  не предполагаются из наличия Xcode; сертификаты/профили не менялись.

Предлагаемый bundle identifier для .02 — `com.dictai.app`: он уже используется
в `macos/Runner/Configs/AppInfo.xcconfig`, поэтому не вводится новая продуктовая
идентичность. Это не доказательство его регистрации у Apple. `--org com.dictai`
создаёт в изолированном шаблоне `com.dictai.dictAi`; в .02 project settings
согласуются с `com.dictai.app` и test suffix. Development team не выбирается
случайно; для simulator остаётся неназначенной. Никакие capabilities, microphone
prompt, background audio, широкие ATS exceptions или Keychain sharing в .01
не добавляются. Их проверяют отдельные выбранные этапы.

## Verification и ограничения

Все команды аудита выполнены из корня frontend, кроме отмеченной генерации,
полученной от координатора в `/tmp`. Приведённые в таблицах PASS подтверждают
только указанный инвентаризационный/source результат.

| Проверка | Actual / Status | Ограничение |
|---|---|---|
| SDK/host/plugin manifests и SHA pinned archive | PASS | Совместимость заявленных minima, без native link/runtime |
| `CI=true flutter --no-version-check create --platforms=ios --project-name dict_ai --org com.dictai --no-pub /tmp/dictai-ios-scaffold-00201` | PASS, координатор; Flutter сообщил 52 созданных файла, проверены 40 файлов внутри ios/ | Изолированный шаблон; не приложение DictAI |
| Сверка 40 scaffold paths с exact scope .02 | PASS, все пути уже перечислены | Podfile — отдельный SDK template; lock см. manifest |
| Ссылки/полный diff/whitespace .01 | Проверяются и фиксируются в карточке .01 | Только документы |
| `flutter analyze`, `flutter test`, iOS build | NOT RUN в .01 | Изменены только документы; сборка назначена .02 |
| Simulator launch, iPhone smoke, HTTPS E2E, signing/archive | NOT RUN | Runtime/online iPhone/тестовый endpoint на время аудита не подготовлены; выпуск вне .01 |

Аудит не объявляет приложение готовым, не меняет acceptance других задач и
не устанавливает `accepted`. Независимый review назначает координатор.
