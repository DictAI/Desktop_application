---
id: REVIEW-FE-001.04-02
task_ids: ["TASK-FE-001.04"]
reviewer: /root/review_foundation_batch
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.04-02

## Scope

2026-10-27. Независимый reviewer `/root/review_foundation_batch`, не писавший
реализацию, завершил review TASK-FE-001.04. Единственный write path reviewer —
этот предварительно зарезервированный отчёт.

Проверены целиком `lib/core/storage/secure_storage.dart`,
`lib/core/network/auth_interceptor.dart`, оба `macos/Runner/*.entitlements`,
новые `test/core/storage/secure_storage_test.dart`,
`test/core/storage/keychain_smoke_app.dart`,
`test/core/network/storage_interceptor_test.dart` и delta карточки .04.
База — frontend HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c` и snapshot
`/tmp/dictai-foundation-03-07-20261026/before/` с manifest `baseline.json`.
Полный tracked diff, содержимое новых файлов и whitespace новых файлов проверены.

Прочитаны AGENTS/WORKFLOW, architecture, актуальный выбор и резервирование в
active-plan, относящиеся положения PLAN-FE-001; существующие consumers storage,
AppException, Xcode mapping и pinned plugin README/Dart options/Swift обработчики
использованы как контекст. Изменения .05–.07, прежнее планирование, принятые .01/.02,
settings и backend не входят в этот review. Реализация и учётные документы
reviewer не менялись.

## Findings

Новых actionable code/documentation findings P0–P3 в назначенном scope нет.
Известный обязательный OS verification blocker остаётся открытым и приведён ниже
отдельно; отсутствие code findings его не закрывает.

Подтверждено по текущему коду:

- Production adapter использует объявленный FlutterSecureStorage. Plaintext
  чтение служит только миграции; credential возвращается из secret store.
  Прежние три ключа удаляются из preferences после подтверждённого OS write/read.
  Существующее OS значение имеет приоритет над stale plaintext. Отказы write/read
  и удаления дают фиксированный безопасный AppException, без raw platform detail.
- Очередь по namespace общая между экземплярами, ошибки не отравляют её.
  Успешный logout сначала подтверждает удаление legacy, затем удаляет и проверяет
  OS значения JWT/email/provider key; последующая миграция их не восстанавливает.
  Неудачный logout явно завершается ошибкой и не объявляется успешным.
- Методы существующих consumers сохранены. `hasToken` возвращает false при
  storage failure; email не используется для авторизации. Изолированный namespace
  и интерфейсы позволяют тестировать миграцию без платформенного доступа.
- Добавление узкой обработки AppException в AuthInterceptor необходимо для
  завершения async Dio handler при новом явном отказе storage. Regression tests
  подтверждают завершение future на read/delete failure и отсутствие HTTP при
  read failure. Refresh/routes/session generation из .09 не добавлены.
- В обоих entitlements добавлен только пустой `keychain-access-groups` согласно
  README pinned flutter_secure_storage 9.2.4. Пакет macOS 3.1.3 использует Security
  Keychain API; defaults Dart/Swift согласованы: groupId отсутствует, synchronizable
  false, доступ when unlocked, data-protection keychain true. Прежние capabilities
  и Xcode Debug/Profile/Release mapping сохранены; project/signing не менялись.
- Native harness использует настоящий storage/plugin, synthetic fixtures и
  префиксованный namespace. Фазы write/restart/delete разделены, выводят только
  результат; cleanup ограничен fixture keys. Это entry point для ручного OS smoke,
  не unit-подтверждение работы Keychain.

## Verification

Самостоятельно reviewer, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Переиспользованы принятые SDK/cache .01: Flutter 3.41.3/Dart 3.11.1,
`/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`,
`PUB_CACHE=/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`.
Toolchain/dependency checks принятых .01/.02 не переоткрывались.

| Проверка | Actual | Статус / предел |
|---|---|---|
| `flutter test --no-pub test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart` | Все 14 tests passed, exit 0 | PASS; storage/HTTP fakes, loopback runner с разрешённым доступом |
| `dart analyze lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart test/core/storage test/core/network/storage_interceptor_test.dart` | No issues found, exit 0 | PASS; только .04 source/tests/harness |
| `dart format --output=none --set-exit-if-changed lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart test/core/storage test/core/network/storage_interceptor_test.dart` | 5 files, 0 changed | PASS |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements` | Оба OK | PASS; syntax, не OS security |
| Сравнение plist к snapshot, README/options/native source и Xcode mapping | В обоих plist только один новый ключ; прежние значения идентичны | PASS; source review |
| SHA-256 к baseline: pubspec.yaml/lock, macos/Podfile.lock, project.pbxproj, Info.plist | Все пять совпадают | PASS; зависимости/подпись/Info.plist не изменены |
| Full diff, tracked и new-file whitespace, ссылки карточки | Diagnostics нет, 7 local links разрешаются после создания этого отчёта | PASS |
| Debug native build | Автор зафиксировал `Runner has entitlements that require signing with a development certificate` после разрешённого доступа к Xcode | FAIL по evidence автора; reviewer не повторял заведомо заблокированную сборку |
| Реальный Debug/Release Keychain write/restart/read/delete, retry/migration, controlled OS failure и applied entitlements | Не запускались | NOT RUN; обязательный blocker |
| Global flutter analyze | Автор зафиксировал 13 прежних info, 0 errors/warnings | FAIL baseline по evidence автора; reviewer не повторял |

## Strengths and residual risk

Fakes содержательно проверяют preservation при write/read failure, silently lost
write, безопасные errors, приоритет OS значения, retry, успешный/неуспешный logout,
сериализацию между экземплярами и namespace isolation. Они не доказывают реальный
Keychain или Linux secret service.

**B01 — известный обязательный OS blocker, open**, карточка
`docs/ai/tasks/TASK-FE-001.04.md:79` и Verification native build/smoke.
Impact: .04 нельзя объявлять verified/accepted; реальное сохранение, перезапуск,
удаление и platform failure ещё не доказаны. Evidence: доступная локальная подпись
не позволила собрать Runner с entitlements; Debug/Release plugin calls не выполнены.
Recommendation: после согласованной development signing identity пройти обе
конфигурации с изолированными fixtures и cleanup, проверить фактически применённые
entitlements. Повторить migration/retry; controlled OS failure воспроизвести
безопасно либо сохранить отдельный NOT RUN с причиной. Harness имеет нормальные
write/restart/delete фазы; отдельного автоматического режима управляемого отказа
Keychain в нём нет. Fake failure и поздние .36/.37 не заменяют этот evidence.

Status blocked в карточке соответствует фактическому результату. Review завершён
для имеющегося diff, task остаётся blocked. Этот отчёт не устанавливает accepted,
не разрешает смену signing/team/profile и не подтверждает deployment. Commit,
push, merge или release не выполнялись.
