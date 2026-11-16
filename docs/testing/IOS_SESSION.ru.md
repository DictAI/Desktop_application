# iOS session и Keychain — TASK-FE-002.03

Дата прохода: 2026-11-16. Scope реализации —
[TASK-FE-002.03](../ai/tasks/TASK-FE-002.03.md). Coordinator запускает команды
Flutter/Simulator; implementer пишет storage, назначенные тесты и документы.
Независимый functional review выполняется после проверок. Подпись физического
iPhone недоступна; Simulator evidence не заменяет physical acceptance.

## Политика хранения

[SecureStorage](../../lib/core/storage/secure_storage.dart) использует существующий
FlutterSecureStorage с явными iOS options:
`first_unlock_this_device`, `synchronizable: false`. Новые записи доступны после
первой разблокировки телефона после перезагрузки, в том числе при последующей
блокировке, если iOS позволяет процессу исполняться. Это не разрешает фоновое
исполнение само по себе; запись на фоне и AVAudioSession относятся к .06.
До первой разблокировки доступ может быть недоступен; существующие ошибки
SecureStorage закрывают session probe и не возвращают plaintext JWT.

`ThisDeviceOnly` ограничивает перенос новых записей на другое устройство;
`synchronizable: false` отключает iCloud synchronization для новых записей.
Это не обещание удаления Keychain при uninstall, переустановке или restore.
В приложении нет новой автоматической очистки при первом запуске. Поведение
на физическом iPhone после reinstall/restore требует отдельного evidence.

Pinned `flutter_secure_storage 9.2.4` на iOS читает существующие записи без
фильтра accessibility и дополнительно может найти synchronizable item.
Само чтение не меняет protection class или synchronization прежней записи.
Новая политика не объявляется ретроактивной миграцией всех retained items.
Для обычных старых non-synchronized `unlocked` items logout удаляет конкретный
ключ с `IOSOptions(accessibility: null, synchronizable: false)`: это сохраняет
service/account scope и убирает фильтр прежнего protection class. Plugin write
при несовпадении старой accessibility переcоздаёт item с новой политикой.

Исторический synchronized item автоматически не удаляется non-synchronized
delete query. Existing post-delete read verification обнаружит retained value,
операция завершится безопасной ошибкой. Credential подавляется только в текущем
Dart процессе: suppression не сохраняется на диск. После cold start retained
synchronized item может снова прочитаться и восстановить сессию, если JWT ещё
валиден. Неуспешный logout не считается гарантированной очисткой между запусками.
Универсальная миграция/очистка synchronized items не добавлена; при обнаружении
такого состояния требуется отдельное решение. iOS Runner создан впервые в этом
проходе; происхождение ранее существующего item нельзя выводить из чтения.

Источники семантики pinned plugin в pub cache:
`lib/options/apple_options.dart`, `lib/options/ios_options.dart` и
`ios/Classes/FlutterSecureStorage.swift` (`read`, `write`, `delete`). Нативные
read/write/restart smoke не измеряют OS protection attributes. Дополнительный
MethodChannel для introspection в Runner не добавлялся.

macOS/Linux options, секретные ключи, legacy migration, namespace и общий
401/session flow сохранены. iOS Keychain sharing, дополнительные entitlements,
permissions и capabilities для .03 не требуются и не добавляются.

## HTTPS и доверие CA

Используются текущие [AppConfig](../../lib/core/config/app_config.dart),
[createDio](../../lib/core/network/api_client.dart) и AuthInterceptor. API origin
задаётся существующим `API_BASE_URL`; credentials не передаются в dart-define.
TLS validation, same-origin policy и запрет redirect/replay сохранены.
ATS exceptions, `badCertificateCallback` и встроенные CA не добавлены.

Для тестового private CA оператор устанавливает профиль сертификата на нужный
iPhone и включает полное доверие в Settings → General → About → Certificate
Trust Settings. Доверие на Mac, Simulator и физическом телефоне независимо.
На Simulator CA можно добавить штатной командой
`xcrun simctl keychain "$DICTAI_IOS_SIMULATOR" add-root-cert "$DICTAI_IOS_CA_FILE"`.
Проверять fingerprint нужно по доверенному источнику оператора; CA, его локальный
путь и содержимое не входят в git. Постоянное доверие CA на Mac для этого smoke
не требуется.

Default Dio IO adapter создаёт обычный Dart HttpClient. SDK SecurityContext
использует platform trust store. Окончательное evidence — запрос из Flutter
на конкретном target, отдельно до и после установки доверия CA. Root HTTP 404
при успешном TLS подтверждает получение HTTP-ответа, но не работоспособность
маршрутов API или авторизации. Timeout/DNS/network failure не считается
успешной отрицательной проверкой сертификата.

## Host tests и native target

[ios_session_test.dart](../../test/core/storage/ios_session_test.dart) проверяет
production SecureStorage через mocked plugin MethodChannel: verified migration,
ошибки native read/write, восстановление через новый экземпляр storage,
logout всех известных account keys и fail-closed после 401 при отказе удаления.
Native Keychain в этих тестах не открывается. Plugin выбирает платформу через
`dart:io Platform`; host tests не объявляются проверкой передачи iOS options.

[ios_gateway_test.dart](../../test/core/config/ios_gateway_test.dart) проверяет
HTTPS IP origin, запрет LAN HTTP несмотря на debug loopback opt-in, безопасную
обработку TLS error без retry, downgrade или logout. TLS failure здесь scripted;
доверие сертификату проверяется отдельно в native target.

[ios_session_smoke_app.dart](../../test/core/storage/ios_session_smoke_app.dart)
— отдельный явно запускаемый target; production `main.dart` его не импортирует.
Он использует реальные plugin/SecureStorage/createDio/AuthApi/AuthNotifier и
существующий WorkspaceApi для read-only protected request. Фазы ограничены
90 секундами, сеть имеет существующие Dio timeouts. Вывод содержит фиксированные
`DICTAI_IOS_SESSION START/PASS/FAIL`, phase и checkpoint; exception strings,
JWT, email, password и response bodies не печатаются. Успех проверяют по PASS
marker ожидаемой фазы, а не по exit status самой `simctl launch`.

| Phase | Что выполняется | Предел вывода |
|---|---|---|
| `write` | Legacy synthetic fixtures мигрируют в реальный Keychain; plaintext keys исчезают после verify | Native операции и migration, не OS attributes |
| `restart` | Отдельный процесс читает сохранённые synthetic значения | Persistence между процессами Simulator |
| `legacy_delete` | Создаёт synthetic old-unlocked items, читает через production store, удаляет и проверяет отсутствие | Retained non-synchronized old policy, не synced item migration |
| `empty` | Проверяет пустой synthetic namespace через production и raw plugin read | Очистка только известных test keys |
| `https_untrusted` | HEAD корня без credentials должен завершиться HandshakeException/badCertificate | Конкретный TLS отказ; общий network failure — FAIL |
| `https` | HEAD корня без credentials получает HTTP response после доверия CA | Реальный Dio TLS на этом target, не API auth |
| `auth_register_login` | Один register/login, сохранение session, hasValidSession и protected WorkspaceApi read | Создаёт серверный тестовый аккаунт только по явному поручению |
| `auth_restart` | Новый процесс восстанавливает session и выполняет protected read | Cold process start Simulator, не physical lock/restore |
| `auth_logout` | Локальный logout очищает test account keys; protected read без JWT получает unauthorized | Не вызывает отсутствующий backend logout/account-delete endpoint |

Namespace обязан начинаться с `dictai.ios.session.smoke.` и иметь непустой
синтетический suffix. Фазы Keychain используют base namespace, credential-free
HTTPS — `.https`, actual test auth — `.auth`. Глобальный Keychain reset,
удаление пользовательских файлов или workspace creation отсутствуют.

Primary configuration — process environment `DICTAI_IOS_SMOKE_PHASE` и
`DICTAI_IOS_SMOKE_NAMESPACE`, для auth также
`DICTAI_IOS_SMOKE_CREDENTIALS_PATH`. При `simctl launch` им соответствуют host
переменные с префиксом `SIMCTL_CHILD_`. В проверенном Simulator запуске Dart
не увидел обе первые переменные, хотя helper передал их. Поэтому только test
target поддерживает fallback: файл
`getApplicationSupportDirectory()/dictai-ios-session-smoke.json` с обязательными
String `phase`, `namespace` и необязательным String `credentialsPath`.

Fallback используется, только когда обе переменные phase/namespace пусты.
Partial environment, malformed JSON, неизвестная phase или неверный namespace
закрывают запуск. Config и credential JSON ограничены 4096 bytes и 5-секундным
read timeout; configuration load ограничен 10 секундами. Config содержит только
несекретные параметры и путь к отдельному credential JSON, но не пароль/JWT.
Оператор удаляет временный config и credential copy после каждого запуска.
Production entrypoint этот файл не читает.

Для auth оператор готовит JSON `endpoint`, `email`, `password` в локальном
файле с mode 0600 вне репозитория и передаёт временную копию в app sandbox.
Endpoint сверяется с AppConfig. Копия удаляется оператором после фазы; test
credentials и сохранённые логи нельзя включать в git или общий review diff.
Повтор `auth_register_login` не является idempotent retry: зарегистрированный
аккаунт используется через последующие фазы. После logout серверный аккаунт
сохраняется для пользователя; endpoint его удаления не придумывается.

## Команды и текущее evidence

Cwd: `/Users/mxdnght/dictai-app`. Flutter3.41.3 revision48c32af034,
Dart3.11.1, Xcode26.5, macOS26.5.2 arm64, CocoaPods1.16.2.
Simulator: iPhone17 Pro / iOS26.5 build23F77. Команды исполнял координатор;
исходную реализацию подготовил ios_session, финальную интеграцию ведёт
primary-agent после завершённого handoff.

Общий prefix Flutter-команд:

```sh
CI=true FLUTTER_SWIFT_PACKAGE_MANAGER=false /Users/mxdnght/.local/share/dictai/flutter/3.41.3/bin/flutter --no-version-check
```

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| Direct Dart `format --output=none --set-exit-if-changed lib/core/storage/secure_storage.dart test/core/storage/ios_session_test.dart test/core/config/ios_gateway_test.dart test/core/storage/ios_session_smoke_app.dart` | 4 files, 0 changed, exit0 после финального fallback | PASS | Формат, не поведение |
| Prefix + `test --no-pub --reporter expanded test/core/storage/ios_session_test.dart test/core/config/ios_gateway_test.dart test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart test/features/auth/auth_api_test.dart test/features/auth/session_navigation_test.dart` | 60/60, exit0 | PASS | Host channel/HTTP fakes; не native attributes |
| Prefix + `test --no-pub --reporter expanded` | 561/561, exit0 | PASS | После этого менялся только standalone native harness, не production/host tests |
| Prefix + `analyze --no-pub --no-fatal-infos` | Initial и final после fallback: exit0, 9 прежних info, 0 errors/warnings | PASS | Финальный log отдельно |
| Prefix + `build ios --simulator --debug --no-pub --target test/core/storage/ios_session_smoke_app.dart --dart-define=API_BASE_URL=<provided-https-origin>` | Initial13s, diagnostic7.9s и final fallback6.8s: exit0; install exit0 | PASS | Native build отдельно от runtime |
| Initial `write`/`restart`; diagnostic `write` | FAIL invalid_configuration; ios=true, env phase/namespace отсутствуют | FAIL, исторический | Storage/network не начаты; устранено test-only sandbox JSON fallback, логи сохранены |
| `simctl launch --console --terminate-running-process <selected-simulator> com.dictai.app`, sequential `write`, `restart`, `legacy_delete`, `empty` с sandbox config | Все4 ожидаемых phase PASS markers; процессы раздельные | PASS | Реальный Simulator Keychain/migration/old-policy delete; OS attributes и physical lock не измеряются |
| Тот же native launch: `https_untrusted` до доверия CA | Ожидаемый TLS HandshakeException/badCertificate, PASS marker | PASS | Не произвольный network failure |
| `xcrun simctl keychain <selected-simulator> add-root-cert <provided-ca-file>`; native `https` | Add-root-cert exit0, HTTP response из общего Dio, PASS marker | PASS | CA доверен только выбранному Simulator; Mac trust/ATS не менялись |
| Native `auth_register_login` | Register/login через текущие AuthApi/AuthNotifier, Keychain session и защищённый WorkspaceApi read: PASS | PASS | Один разрешённый серверный тестовый аккаунт; UI taps не проверялись |
| Native `auth_restart` | Новый процесс восстановил session и прочитал защищённый API: PASS | PASS | Cold process start Simulator, не physical lock/restore |
| Native `auth_logout` | Session keys удалены; последующий защищённый read без JWT вернул unauthorized: PASS | PASS | Серверный аккаунт остаётся пользователю; JWT не печатался |
| Prefix + `build ios --simulator --debug --no-pub --target lib/main.dart --dart-define=API_BASE_URL=<provided-https-origin>`; install/launch/screenshot | Build exit0/17.6s, install/launch exit0; визуально проверена обычная форма входа | PASS | Main target восстановлен после smoke, UI login taps не проверялись |
| iPhone lock/unlock, unavailable storage, account switch, reinstall/restore, HTTPS/session | Подпись недоступна, не выполнялись | NOT RUN | Обязательный physical gate; .03 не verified, .04/.05 закрыты |
| Независимый [REVIEW-FE-002.03-02](../ai/reviews/REVIEW-FE-002.03-02.md) | Reviewed; F01 P3 уточнение lifetime исправлено и подтверждено delta, открытых findings нет | PASS | Не заменяет обязательный physical gate |

Запуски smoke выполнялись локальным helper вне repo: он записывает только
phase/namespace/credentialsPath в выделенный sandbox config, для auth копирует
отдельный credential JSON с mode0600 и удаляет оба временных файла после фазы.
Success определяется точным marker `DICTAI_IOS_SESSION PASS <phase>`;
`simctl launch` может вернуть exit0 при app FAIL, поэтому его одного недостаточно.

Main evidence: `/tmp/dictai-ios-session-main-build.log`,
`/tmp/dictai-ios-session-main-launch.log`, `/tmp/dictai-ios-session-main-login.png`.
После восстановления проверено отсутствие временных sandbox config/credentials;
результат `/tmp/dictai-ios-session-cleanup.log` повторно подтверждён reviewer.

Логи без credentials в `/tmp`: `dictai-ios-session-targeted-tests.log`,
`dictai-ios-session-tests.log`, `dictai-ios-session-analyze.log`,
`dictai-ios-session-final-analyze.log`, `dictai-ios-session-build.log`,
`dictai-ios-session-build-config-diagnostic.log`,
`dictai-ios-session-build-config-file.log`, `dictai-ios-session-<phase>.log`.
Исторические initial/diagnostic config failures сохранены отдельно с suffix
`initial-config-fail`/`config-diagnostic-fail`. Runtime также выводит warning о
дублирующемся FileUtils из locked file_picker; в этих phases crash не наблюдался,
пакет не обновлялся. Это не проверка Files UX из будущей .07.

Тестовый аккаунт зарегистрирован по прямому поручению пользователя. Его данные
остаются в private local file вне repo и передаются пользователю отдельно;
пароль/почта/JWT не включаются в этот документ. Logout удалил native test session,
не серверный аккаунт. CA остаётся в trust store выбранного Simulator для доступа
к стенду; глобальный reset Keychain и изменение Mac trust не выполнялись.

Физические критерии остаются обязательными. Review и Simulator PASS не дают
автоматического accepted, commit/push/merge/release или перехода к .04/.05.
