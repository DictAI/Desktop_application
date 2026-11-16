---
id: "TASK-FE-002.02"
plan: "PLAN-FE-002"
title: "Добавить iOS Runner и воспроизводимую simulator-сборку"
status: "review"
owner: "primary-agent"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.01"]
scope: ["ios/.gitignore", "ios/Podfile", "ios/Podfile.lock", "ios/Flutter/AppFrameworkInfo.plist", "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig", "ios/Runner/AppDelegate.swift", "ios/Runner/SceneDelegate.swift", "ios/Runner/Runner-Bridging-Header.h", "ios/Runner/Info.plist", "ios/Runner/Base.lproj/LaunchScreen.storyboard", "ios/Runner/Base.lproj/Main.storyboard", "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme", "ios/Runner.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/RunnerTests/RunnerTests.swift", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md", ".metadata", "docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", "docs/ai/tasks/TASK-FE-002.02.md"]
planned_paths: ["ios/.gitignore", "ios/Podfile", "ios/Podfile.lock", "ios/Flutter/AppFrameworkInfo.plist", "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig", "ios/Runner/AppDelegate.swift", "ios/Runner/SceneDelegate.swift", "ios/Runner/Runner-Bridging-Header.h", "ios/Runner/Info.plist", "ios/Runner/Base.lproj/LaunchScreen.storyboard", "ios/Runner/Base.lproj/Main.storyboard", "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme", "ios/Runner.xcworkspace/contents.xcworkspacedata", "ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist", "ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings", "ios/RunnerTests/RunnerTests.swift", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png", "ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md", "docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"]
reuses_tasks: ["TASK-FE-001.01", "TASK-FE-001.05", "TASK-FE-001.36"]
implementation_selected: true
---

# TASK-FE-002.02: Добавить iOS Runner и воспроизводимую simulator-сборку

## Goal

Добавить iOS Runner и воспроизводимую simulator-сборку. Один завершённый этап iOS/iPhone очереди.

## Context

Текущий проход: пользователь установил Simulator, runtime iOS26.5 build23F77
подтверждён. Повторяем build/launch существующего приложения на Flutter3.41.3;
новый независимый review REVIEW-FE-002.02-03. Baseline334 files сохранён в
`/tmp/dictai-ios-simulator-baseline.json`. Предыдущие результаты ниже — история.


Возобновление: пользователь явно разрешил отдельный Flutter 3.41.3. Текущий
owner primary-agent принимает exact scope после завершённого handoff ios_runner.
Проверки повторяются на текущем diff с неизменным pubspec/lock; ниже сохраняется
история Flutter3.44 и его конкретных blockers. Новый review: REVIEW-FE-002.02-02.


[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Последующее поручение 2026-11-16 выбрало реализацию .01–.05 пятью агентами.
Write gate и owner назначены в active-plan; зависимости проверяются до записи.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.01](../tasks/TASK-FE-001.01.md), [TASK-FE-001.05](../tasks/TASK-FE-001.05.md), [TASK-FE-001.36](../tasks/TASK-FE-001.36.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Runner создан pinned Flutter SDK с deployment target из .01; есть воспроизводимая команда сборки и проверенный вход в существующее приложение.
- [x] Перед генерацией .01 уточняет полный exact manifest .02: перечисленные здесь пути — кандидаты шаблона, лишние не создаются; новые пути сначала документируются. Generated registrants вручную не редактируются.
- [x] Обоснованы bundle identifier, capabilities и plist; нет широких ATS exceptions, лишних permission prompts или встроенных секретов. Команда/подпись владельца не подменены случайными значениями.
- [x] flutter build ios --simulator --debug выполнен либо записан конкретный внешний blocker; сборка не объявляется работающим микрофоном или backend E2E.
- [x] Назначенный owner реализовал scaffold в exact scope, записал фактические результаты проверок и получил внутренний независимый review; существенных source/doc findings нет, незавершённые обязательные проверки оставлены blockers, `accepted` не выставлен автоматически.

## Implementation notes

Платформенный scaffold; бизнес-экраны остаются для следующих задач. Если сборка требует изменения lock/dependencies, сначала зафиксировать конкретную необходимость в scope и получить решение, не обновлять всё автоматически.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification — установленный Simulator, 2026-11-16

Cwd `/Users/mxdnght/dictai-app`, macOS26.5.2 arm64, Xcode26.5,
CocoaPods1.16.2. Выполняемый SDK:
`/Users/mxdnght/.local/share/dictai/flutter/3.41.3`, tag3.41.3,
revision `48c32af0345e9ad5747f78ddce828c7f795f7159`, Dart3.11.1.
Simulator: iPhone17 Pro, iOS26.5 build23F77. Текущий baseline334 files:
`/tmp/dictai-ios-simulator-baseline.json`; предыдущий diff сохранён.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `xcrun simctl list runtimes`; `xcrun simctl list devices available` | Runtime iOS26.5 (23F77), доступный iPhone17 Pro | PASS | Инвентаризация окружения |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /Users/mxdnght/.local/share/dictai/flutter/3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | Exit0; Xcode build193.9s; Built build/ios/iphonesimulator/Runner.app | PASS | Native Simulator compile/link; не device signing/audio/backend E2E |
| `xcrun simctl boot <selected-simulator>`; `xcrun simctl bootstatus <selected-simulator> -b` | Exit0; первая системная миграция завершена за96s | PASS | Один выбранный Simulator, без сброса чужих устройств |
| `xcrun simctl install <selected-simulator> build/ios/iphonesimulator/Runner.app`; `xcrun simctl launch <selected-simulator> com.dictai.app` | Exit0; процесс Runner остаётся запущен | PASS | Сам process launch проверен отдельно от UI |
| `xcrun simctl io <selected-simulator> screenshot /tmp/dictai-ios-simulator-login.png`; визуальная проверка | После начального launch screen отрисовалась существующая форма Sign In/Sign Up с Email/Password | PASS | Подтверждён вход в приложение; учётных данных нет, login/backend не проверены |
| `python3 /tmp/check_dictai_ios_runner_00202.py` | PASS40 scaffold paths, XML/assets/iOS13/identity, CocoaPods/no team/ATS/audio capability | PASS | Статика, дополняет actual build |
| Независимый [REVIEW-FE-002.02-03](../reviews/REVIEW-FE-002.02-03.md) | Reviewed/complete, actionable findings нет; source/artifact/runtime/screenshot проверены независимо | PASS | Не закрывает physical/auth/Keychain/HTTPS .03 |

Логи: `/tmp/dictai-ios-simulator-build.log`,
`/tmp/dictai-ios-simulator-launch.log`; screenshot указан выше. Артефакты не
добавляются в Git. Предыдущие552 tests и analyze PASS относятся к тем же
Dart/lock файлам на том же SDK; повтор после установки runtime не нужен.

## Result — текущий проход Simulator

Runner реально собран и запущен на установленном runtime. Проверена отрисовка
существующего экрана входа, первый acceptance criterion закрыт. Прежний внешний
blocker отсутствующего Simulator устранён. Native source, `.metadata`, pubspec
и lock в этом проходе не менялись; обновляются evidence и учётные документы.
Scaffold создан3.44, выполнен3.41.3; provenance `.metadata` сохранён.

Статус review, не accepted. Независимый REVIEW-FE-002.02-03 завершён без
findings; обязательные checks .02 пройдены, dependency gate следующей выбранной
.03 открыт без повторного запроса пользователю. Simulator не доказывает auth/Keychain,
iPhone, microphone или HTTPS из Dio. Подпись iPhone ранее подтверждена
недоступной; это ограничение следующей .03, не Simulator scaffold .02.

## Предыдущая Verification: SDK3.41.3 без runtime


Cwd `/Users/mxdnght/dictai-app`, macOS26.5.2 arm64 / Xcode26.5 / CocoaPods1.16.2.
SDK `/Users/mxdnght/.local/share/dictai/flutter/3.41.3`
(alias `/tmp/dictai-flutter-3.41.3`): official tag3.41.3, HEAD48c32af034,
Dart3.11.1. Baseline текущего прохода:332 files в
`/tmp/dictai-ios-sdk3413-baseline.json`; предыдущий diff сохранён.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check --version` и git tag/HEAD | Version3.41.3, revision48c32af034, Dart3.11.1, channel user-branch у shallow tag checkout | PASS | Это отдельный local SDK, не stable branch pin-файл проекта |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check pub get --enforce-lockfile` | Exit0, Got dependencies; package config создана | PASS | Pubspec/lock SHA-256 прежние |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded` | Exit0, 552 tests passed | PASS | Unit/widget, не iPhone/Simulator smoke |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit0, 9info, errors/warnings нет | PASS | Native code не компилирует |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | Pod install PASS759ms; build exit1, no generic iOS Simulator destination, iOS26.5 platform/runtime не установлен | FAIL | Compile/link/launch не подтверждены |
| `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -arch arm64 -derivedDataPath /tmp/dictai-ios-native-sdk3413 CODE_SIGNING_ALLOWED=NO build` | Exit70, Found no destinations for Runner/action build | FAIL | Тот же platform blocker, не ошибка Dart tests |
| `xcodebuild -checkFirstLaunchStatus`; `xcrun simctl list runtimes` | First launch status exit0, runtimes0 | PASS для inventory | Simulator/iPhone launch NOT RUN |
| SHA protected lib/test/macOS/Linux/pubspec/lock/rules/architecture | 142 файла без изменений относительно fresh baseline | PASS | .DS_Store внешний; native integration в разрешённом scope |
| Независимый [REVIEW-FE-002.02-02](../reviews/REVIEW-FE-002.02-02.md) | Reviewed/complete, F01 P3 fixed with delta evidence, открытых findings нет | PASS | Source/doc/native lock review; build/launch blocker не устраняет |

## Предыдущий Result: SDK3.41.3 без runtime

Выбор SDK/lock разрешён пользователем и выполнен через отдельный3.41.3 без
изменения project dependencies: blocker несовпадающих pins устранён. Все552
existing теста прошли на actual проекте, два прежних Flutter3.44 ListTile
failures не воспроизвелись; исходники UploadModal и тесты не исправлялись.
Создан actual `ios/Podfile.lock`, CocoaPods штатно обновил project.pbxproj и
workspace в заранее согласованном .02 scope. После переноса того же SDK
в постоянный каталог повторены version/enforced pub (PASS0) и simulator build
(FAIL1, pod615ms PASS); generated configs используют постоянный путь. Это не
новое изменение code/lock и не native compile PASS. Логи двух проходов
разделены в IOS_BASELINE. `.metadata` сохранила исходную
генерацию3.44 и root/macOS историю. Native manifest42files; остальные изменения
этого прохода — baseline/manifest, эта карточка и общие записи координатора.

Задача остаётся blocked: текущая сборка реально запускалась, но Xcode не имеет
подходящего Simulator destination/runtime; compile/link/launch не доказаны.
Подпись для iPhone ранее подтверждена недоступной. Первый AC входа в приложение
не закрыт, .03 functional gate не открыт, accepted не выставлен. Независимый
review текущего delta REVIEW-FE-002.02-02 завершён: reviewed/complete, F01 P3
исправлен и повторно проверен, открытых findings нет. Этот review не закрывает
platform/launch gate. Ниже сохранён предыдущий
проход Flutter3.44; его pubFAIL/buildNOTRUN не являются текущими результатами.

## Предыдущая Verification: Flutter3.44

Cwd: `/Users/mxdnght/dictai-app`, кроме isolated scaffold/helper в `/tmp`.
Host macOS 26.5.2 arm64, Xcode 26.5, Flutter 3.44.0 revision
`559ffa3f75e7402d65a8def9c28389a9b2e6fe42`, Dart 3.12.0, CocoaPods 1.16.2.
Команды Flutter выполнял координатор: sandbox implementer запрещает SDK cache.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check create --platforms=ios --project-name dict_ai --org com.dictai --no-pub /tmp/dictai-ios-scaffold-00202-cocoapods` | frontend, root access / SDK выше | SDK CocoaPods scaffold без обновления dependencies | Координатор: exit 0, 52 файла всего / 40 ios paths; перенесены только exact 40 | PASS | Первая попытка implementer FAIL: sandbox SDK cache `Operation not permitted`; успешный повтор координатора |
| Direct Dart SDK с SDK package config: `/tmp/dictai-ios-metadata-00202.dart <isolated-existing-metadata> <generated-metadata>` | `/tmp`, Dart 3.12.0 / FlutterProjectMetadata SDK API | Добавлена только iOS registration | Exit 0, diff ровно +3 строки iOS; root/macOS revisions/unmanaged сохранены | PASS | Helper временный; full metadata заменой isolated scaffold не переносилась |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check pub get --enforce-lockfile` | frontend, координатор / SDK выше | Согласованные locked dependencies без изменения lock | Exit 65: would change matcher 0.12.18→0.12.19, meta 1.17.0→1.18.0, test_api 0.7.9→0.7.11; Unable to satisfy pubspec.yaml using pubspec.lock | FAIL | Flutter 3.44 flutter_test требует иные exact версии; SDK/lock update не разрешён |
| SHA-256 `pubspec.yaml`/`pubspec.lock` против `/tmp/dictai-ios-five-baseline.json` | frontend / Python 3 | Оба файла сохранены | Оба hash совпадают | PASS | Не доказывает успешный dependency resolution |
| `plutil -lint ios/Runner/Info.plist ios/Flutter/AppFrameworkInfo.plist ios/Runner.xcodeproj/project.pbxproj` | frontend / Xcode tools | Валидные plist/project | 3 OK | PASS | Статический синтаксис |
| `python3 /tmp/check_dictai_ios_runner_00202.py`; `ruby -c ios/Podfile` | frontend / Python 3, Ruby | Manifest/scope, native XML/assets/target/identity без неназначенных capabilities | Exact 40 scaffold paths, iOS 13.0, bundle 3+3 configurations, no team/SPM/ATS/audio capabilities; Syntax OK | PASS | Статика, не native link/runtime |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | frontend / macOS, simulator SDK 26.5 | Native simulator build | Не запускалась после failed enforced pub; согласованной package config нет | NOT RUN | Concrete blocker: SDK-owned exact dependencies не совпадают с lock; несогласованный --no-pub не применяется |
| Matching iOS 26.5 arm64 runtime download / Simulator launch | Host Xcode / координатор | Installed runtime и запуск существующего приложения | Download 8.52 GB отменён координатором после медленной передачи около 27 MB: Download was cancelled; runtime не установлен; launch не выполнялся | NOT RUN | Cancellation не PASS; SDK для compile есть, runtime для launch отсутствует |
| iPhone launch/login; signing/candidate | Device / owner signing | Реальный запуск приложения, отдельно от simulator compile | Не выполнялись; пользователь сообщил, что signing сейчас недоступна | NOT RUN | Team/profiles не назначены; device/session checks не доказаны |
| Flutter analyze/tests | frontend | Проверки изменённого Dart поведения | Dart-код не менялся, согласованные packages не подготовлены | NOT RUN | Пустой template RunnerTests не используется как evidence |
| Полный diff, native manifest/metadata invariants, ссылки и whitespace | frontend / Git, Python, Ruby | Exact scope; без посторонних правок implementer | Итоговый self-check выполнен; подробности в Result | PASS | Самопроверка автора; независимый проход указан ниже |
| Независимый source/documentation review [REVIEW-FE-002.02-01](../reviews/REVIEW-FE-002.02-01.md) | frontend / `/root/ios_independent_review` | Полный реализованный diff и документация проверены другим агентом | reviewed/complete, actionable findings нет | PASS | Только source/doc review; actual pub FAIL65, build/launch NOT RUN и status blocked сохраняются |

### Дополнительный candidate evidence координатора

Actual repository результаты выше не заменяются этим исследованием. Cwd:
`/var/folders/nk/dn15wj451d90zxf_gxkbdgjr0000gn/T/dictai-ios-lock-proposal-_m_ssbgg`;
тот же Flutter 3.44 / Xcode 26.5. Candidate source — копия, actual файлы `.02`
заморожены (`/tmp/dictai-ios-runner-source-freeze.json`). Ни lock, ни native
integration из candidate в actual не переносились.

| Candidate command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check pub get` | Exit 0; proposed lock меняет три версии+SHA и lock Flutter floor | PASS | Временная копия, не actual enforced pub |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check build ios --simulator --debug --no-pub --dart-define=API_BASE_URL=<approved-https-origin>` | CocoaPods install PASS 138.1 s; общий build exit 1: Unable to find a destination matching {generic:1,platform:iOS Simulator}, iOS 26.5 platform не установлена | FAIL | Candidate Podfile.lock и project/workspace integration не перенесены; compile/launch не подтверждены |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check test --no-pub --reporter expanded` | Exit 1, 550 PASS / 2 FAIL из 552 | FAIL | Новый Flutter 3.44 ListTile assertion в existing UploadModal, вне `.02` |
| `CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false flutter --no-version-check analyze --no-pub --no-fatal-infos` | Exit 0, 9 info | PASS | Только candidate; не закрывает native/runtime/test blockers |
| Source tagged Flutter 3.41.3 flutter_test pubspec | Три exact pins совпали с actual lock | PASS | SDK 3.41.3 не установлен: его pub/build/tests NOT RUN |

Полный proposed lock delta: matcher 0.12.18→0.12.19, meta 1.17.0→1.18.0,
test_api 0.7.9→0.7.11 и их SHA-256; sdks.flutter >=3.35.6→>=3.41.3
(последний минимум уже задан pubspec). Patch `/tmp/dictai-ios-lock-proposal.patch`.
Два failing tests: `test/features/record/anonymous_flow_test.dart`
(owner-only shared WAV) и `test/features/workspace/profile_free_flow_test.dart`
(empty workspace WAV). Assertion `background color or ink splashes may be
invisible` относится к CheckboxListTile под decorated Container в existing
`lib/features/record/presentation/upload_modal.dart:90–100,371–381`.
Этот scope не исправлялся; три lock updates сами по себе не являются полностью
проверенным решением. Logs: `/tmp/dictai-ios-lock-proposal-tests.log` и
`/tmp/dictai-ios-lock-proposal-analyze.log`. Персональные device данные не сохранены
в карточке. Подробности candidate/actual разделения — в IOS_BASELINE.

## Предыдущий Result: Flutter3.44

2026-11-16: scaffold реализован, задача **blocked**, проверка сборки и запуска
не завершена. Write gate получен после checks и независимого
[REVIEW-FE-002.01-02](../reviews/REVIEW-FE-002.01-02.md) задачи .01.
В [manifest](../../testing/IOS_SCAFFOLD_MANIFEST.ru.md) зафиксированы точные
40 template paths, команды и safe transfer. Изменены `.metadata`, 40 новых
scaffold paths `ios/`, новый `ios/Podfile`, два документа baseline/manifest и эта
карточка. Bundle `com.dictai.app`, display/CFBundleName `DictAI`, iOS 13.0;
внутренний SDK target/product Runner сохранён. Team, signing, entitlements,
ATS exceptions, микрофон/background capabilities не добавлены.
В Debug/Release xcconfig включены standard optional Pods configuration includes
по реализации SDK CocoaPods setup; generated registrants вручную не менялись.

`ios/Podfile.lock` согласован в scope до генерации, но **не создан**: enforced
pub не подготовил согласованные project packages; CocoaPods installation и
native build не запускались. Native lock не выдуман. Исходные `pubspec.yaml`
и `pubspec.lock` побайтово сохранены. Конкретный blocker: SDK Flutter 3.44.0
требует три другие версии SDK-owned test dependencies; минимальные constraints
из .01 не подтверждали совместимость полного locked graph. Требуется отдельное
решение по согласованному SDK/lock, без автоматического обновления в этой задаче.
Runtime Simulator отсутствует после отменённой загрузки, signing сейчас
недоступна. Candidate lock исследован отдельно: build FAIL из-за runtime,
550/552 tests PASS при двух existing UploadModal failures, analyze PASS/9 info;
это не actual verification и не разрешение на изменение dependencies. Проверенный вход в приложение остаётся незакрытым acceptance criterion.

Self-check: прочитан полный native scaffold, XML/plist/project/assets и Podfile;
точные paths сверены с scope, metadata diff сохраняет прежние root/macOS entries.
Полный tracked/untracked diff и whitespace проверены отдельно, включая PNG
assets и новые документы. `.DS_Store`, уже изменённый к началу .02, сохранён как
внешний diff; shared план/реестр и карточки других задач implementer не менял.

Независимый source/documentation
[REVIEW-FE-002.02-01](../reviews/REVIEW-FE-002.02-01.md) завершён агентом
`/root/ios_independent_review`: reviewed/complete, actionable findings нет.
Это PASS review реализованного scaffold и документации; actual enforced pub
остаётся FAIL65, build/launch NOT RUN. Обязательные checks не выполнены, поэтому
status .02 остаётся blocked, готовность .02 и write gate .03 не утверждаются.
`accepted` не выставлен, commit/push/merge/release не выполнялись.
