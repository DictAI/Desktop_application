# Manifest iOS Runner — TASK-FE-002.01 → TASK-FE-002.02

## Текущее исполнение .02 на установленном Simulator

2026-11-16: actual build Flutter3.41.3 PASS (exit0, Xcode193.9s) на runtime
iOS26.5 build23F77. `Runner.app` установлен и запущен на iPhone17 Pro Simulator,
визуально подтверждена существующая форма входа. Native source manifest прежний:
42 файла, включая Podfile/Podfile.lock; Flutter migration provenance `.metadata`
сохраняет исходную генерацию3.44. В этом проходе source/config не менялись.
Команда и ограничения — [карточка .02](../ai/tasks/TASK-FE-002.02.md) и
[baseline](IOS_BASELINE.ru.md). Независимый REVIEW-FE-002.02-03 завершён без findings; gate .03 открыт.
Simulator launch не доказывает backend login, Dio HTTPS, Keychain или iPhone.
Следующие разделы сохраняют историю до установки runtime; утверждения об его
отсутствии относятся только к тем проходам.

## Предыдущее исполнение .02 с Flutter3.44 — 2026-11-16

Owner `.02`: `/root/ios_runner`, после checks и независимого
`REVIEW-FE-002.01-02` зависимости `.01`. Для CocoaPods выполнена повторная
генерация тем же SDK с process-local флагом, без изменения глобальной настройки
Flutter или pubspec:

```sh
CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check create --platforms=ios --project-name dict_ai --org com.dictai --no-pub /tmp/dictai-ios-scaffold-00202-cocoapods
```

Команда координатора: PASS, exit 0, 52 файла всего, те же 40 путей `ios/`.
Этот вариант шаблона не содержит SwiftPM references; исходный `.01` scaffold
содержал их из-за нового default SDK. Все 40 путей ниже перенесены из варианта
CocoaPods. Дополнительно создан `ios/Podfile` из SDK template с явным iOS 13.0.
В `Flutter/Debug.xcconfig` и `Flutter/Release.xcconfig` добавлены optional
`Pods-Runner.debug/release.xcconfig` includes по реализации SDK
`CocoaPods.addPodsDependencyToFlutterXcconfig` (`src/macos/cocoapods.dart`):
это штатный шаг CocoaPods setup, который также выполняется Flutter при build.
Plugin registrants не редактировались.
`ios/Podfile.lock` должен сохраняться после native dependency installation; его
путь согласован координатором до генерации. На том проходе он ещё не был создан: enforced pub
завершился exit 65 из-за SDK-owned dependency pins. Все пути входят в exact scope
`.02`; фактический новый native manifest на том проходе состоял из 41 файла.

`Info.plist` задаёт видимое имя и CFBundleName `DictAI`, bundle IDs во всех трёх
конфигурациях — `com.dictai.app` и `com.dictai.app.RunnerTests`. Внутренние SDK
target/product `Runner` сохранены для согласованности scheme и test host.
Minimum target проекта и Podfile — 13.0. Team, entitlements, ATS exceptions,
микрофон и background capabilities не добавлены.

Для `.metadata` использован Dart API установленного Flutter SDK
`FlutterProjectMetadata` на отдельной копии в `/tmp`: только generated iOS
`MigratePlatformConfig` добавлен в разобранный исходный metadata, затем вызван
SDK `writeFile()`. В репозиторий перенесён проверенный результат: ровно три новые
строки iOS, исходные version/root/macOS revisions и unmanaged paths сохранены.
Временный helper: `/tmp/dictai-ios-metadata-00202.dart`; его запуск direct Dart
3.12 с SDK package configuration завершился exit 0. Полная перезапись metadata
командой `flutter create` не применялась к репозиторию.

Первая Flutter-команда implementer получила sandbox `Operation not permitted`
на записи SDK cache и не создала scaffold; координатор повторил её с доступом
и получил PASS. Дальнейшие Flutter/pub/build команды выполняет координатор.
`plutil -lint`, `ruby -c ios/Podfile` и
`python3 /tmp/check_dictai_ios_runner_00202.py` — PASS: синтаксис plist/project,
native XML и assets, exact 40 paths, iOS 13.0, identity и отсутствие неназначенных
capabilities проверены. Это статическая проверка, без runtime утверждений.

`pub get --enforce-lockfile` — FAIL: Flutter 3.44 требует изменить три locked
test dependencies. `pubspec.yaml`/`pubspec.lock` сохранены. CocoaPods install,
simulator build и launch — NOT RUN; task `.02` blocked. Детали exact commands,
evidence и внешних ограничений записаны в карточке и IOS_BASELINE. Несогласованная
package configuration не используется для обхода через `--no-pub`.

Координатор дополнительно проверил отдельную временную копию с предложенным
lock. В ней CocoaPods install PASS и создал `Podfile.lock`, а build FAIL из-за
отсутствующего Simulator runtime; изменились только candidate project/workspace
integration. Ничего из candidate native output не перенесено в actual Runner.
Candidate regression: 550/552 tests PASS, два FAIL; analyze PASS с 9 info.
Подробные команды, полный lock delta и ограничения приведены в IOS_BASELINE.
Этот опыт не закрывает verification `.02` и не разрешает обновление actual lock.

Дата: 2026-11-16. Owner аудита: `/root/ios_baseline`. Основание:
[IOS_BASELINE.ru.md](IOS_BASELINE.ru.md), Flutter 3.44.0 stable revision
`559ffa3f75e7402d65a8def9c28389a9b2e6fe42`, minimum iOS 13.0.

## Исполнение с разрешённым Flutter3.41.3

Пользователь разрешил отдельный SDK3.41.3; команды и actual Verification
приведены в [baseline](IOS_BASELINE.ru.md). Исходный scaffold по-прежнему создан
Flutter3.44, его `.metadata` provenance не переписывается. AppDelegate,
SceneDelegate и framework plist совпадают с templates3.41.3; минимальный iOS13
и product identity сохраняются.

После `pub get --enforce-lockfile` на3.41.3 actual CocoaPods installation
создала разрешённый `ios/Podfile.lock` и интеграцию Pods в project.pbxproj и
Runner.xcworkspace. Теперь native manifest42 files:40 template files ниже,
`ios/Podfile` и `ios/Podfile.lock`. Native lock сохранён для воспроизводимости;
project `pubspec.yaml`/`pubspec.lock` неизменны. Бизнес-исходники не менялись.

Actual tests552/552 и analyze (0errors/0warnings/9info) PASS. Flutter simulator
build FAIL: Xcode не нашёл destination, Simulator runtime отсутствует. Эти
проверки не доказывают native linking или запуск. .02 остаётся blocked на
platform/launch gate. История исполнения3.44 сохранена выше; инвентаризация
исходного шаблона и CocoaPods generation route приведены ниже. Исполняемые
команды с выбранным3.41.3 берутся из текущего baseline.

## Воспроизводимая инвентаризация

Координатор выполнил из корня frontend в новом временном каталоге:

```sh
CI=true flutter --no-version-check create --platforms=ios --project-name dict_ai --org com.dictai --no-pub /tmp/dictai-ios-scaffold-00201
```

Exit 0. Flutter сообщил 52 созданных файла. На диске внутри `ios/` проверены
ровно 40 файлов, перечисленных ниже. `--no-pub` исключает разрешение dependency
версий проекта при инвентаризации; scaffold не переносился в приложение в .01.
Команда использует уже установленный SDK, не выполняет upgrade.

При исполнении .02 команда уточнена флагом CocoaPods выше. Для повторного
переноса следует генерировать в новом временном каталоге, затем
переносить только перечисленные `ios/` файлы. Генерация поверх корня рабочего
репозитория не нужна: она может затронуть README, pubspec, main и тесты.
Зафиксированный manifest полностью входит в текущие scope/planned_paths .02.
Все новые пути вне списка требуют уточнения карточки координатором до записи.

```text
ios/.gitignore
ios/Flutter/AppFrameworkInfo.plist
ios/Flutter/Debug.xcconfig
ios/Flutter/Release.xcconfig
ios/Runner/AppDelegate.swift
ios/Runner/SceneDelegate.swift
ios/Runner/Runner-Bridging-Header.h
ios/Runner/Info.plist
ios/Runner/Base.lproj/LaunchScreen.storyboard
ios/Runner/Base.lproj/Main.storyboard
ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png
ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png
ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
ios/Runner.xcodeproj/project.pbxproj
ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata
ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
ios/Runner.xcworkspace/contents.xcworkspacedata
ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
ios/RunnerTests/RunnerTests.swift
```

В шаблоне Flutter 3.44 есть UIScene `SceneDelegate.swift` и implicit engine
registration в AppDelegate. Сохраняются обе стороны шаблона; не подменять их
старыми AppDelegate-примерами. RunnerTests — шаблон, не evidence проверки DictAI.
App icons/LaunchImage в этом manifest — штатные placeholder assets SDK, не
готовое оформление Store candidate.

## Дополнительные разрешённые файлы .02

| Путь | Происхождение / действие |
|---|---|
| `ios/Podfile` | При CocoaPods integration копировать текущий SDK `packages/flutter_tools/templates/cocoapods/Podfile-ios`, установить `platform :ios, '13.0'`; не брать устаревший Podfile из сети. Базовый `create --no-pub` его не создаёт |
| `ios/Podfile.lock` | Координатор добавил в scope/planned_paths .02 до CocoaPods integration. Сохранить полученный native lock вместе с platform diff для воспроизводимости dependency graph |
| `.metadata` | Обновить средствами Flutter для добавления iOS platform, сохранив существующий macOS/root migration baseline и unmanaged files; проверить полный diff. Не заменять целиком temporary metadata с потерей macOS |
| `docs/testing/IOS_BASELINE.ru.md` | Дополнить реальными результатами .02; не превращать NOT RUN в PASS без команды |
| `docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md` | Зафиксировать фактический final manifest и отклонения после .02 |
| `docs/ai/tasks/TASK-FE-002.02.md` | Реальные Verification/Result и статус .02 |

`ios/Podfile.lock` не создаётся командой `create --no-pub`; в исходной карточке
.02 его не было. Координатор согласовал этот путь и добавил в оба списка
scope/planned_paths до CocoaPods integration. Его генерация и сохранение теперь
входят в exact scope .02. Не менять проектный `pubspec.lock` ради его получения.
Аналогично новые tracked SPM lock
paths согласуются до записи; ephemeral packages не становятся исходниками.

В `.02` Runner/RunnerTests build settings должны согласовать min iOS 13.0,
продуктовое имя DictAI и bundle identifier `com.dictai.app` из существующей
macOS конфигурации (test target — suffix `.RunnerTests`). Development team
не угадывается. Ни mic/background permissions, ни Keychain sharing, ни ATS
исключения не требуются для самого scaffold.

## Не переносить из temporary scaffold

Корневые `.gitignore`, README, pubspec, pubspec.lock, `lib/main.dart`,
`test/widget_test.dart`, `.idea/**`, `*.iml` исключены из переноса. Runtime
артефакты остаются игнорируемыми: `ios/Pods/`, `.symlinks/`, `Flutter/ephemeral/`,
`Flutter/Generated.xcconfig`, `Flutter/flutter_export_environment.sh`,
`Runner/GeneratedPluginRegistrant.*`, `xcuserdata/`, DerivedData и build output.
Generated registrants вручную не редактируются. Проверить итоговый
`git status --short --untracked-files=all`, включая бинарные новые файлы.

## Исторический план verification до установки runtime

После подготовки pinned dependencies — `flutter build ios --simulator --debug`
(с `CI=true` и глобальным `--no-version-check`, если нужна та же offline version
check политика). Для `--no-pub` сначала должна существовать согласованная
package configuration; на время аудита .01 её не было. `API_BASE_URL` подаётся только разрешённой
тестовой конфигурацией, без копирования приватных значений в отчёты.

Нужно отдельно подтвердить запуск/вход в существующее приложение. Runtime
Simulator пока отсутствует, пользователь готовит iPhone и тестовый HTTPS endpoint;
успешный compile сам по себе не закрывает launch или device smoke. Signing,
микрофон, Files и release gates описаны в соответствующих карточках.
