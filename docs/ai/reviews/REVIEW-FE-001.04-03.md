---
id: REVIEW-FE-001.04-03
task_ids: ["TASK-FE-001.04"]
reviewer: /root/review_keychain_finish
mode: read-only
status: open
completion: partial
---

# REVIEW-FE-001.04-03

## Scope

2026-10-30. Независимый reviewer `/root/review_keychain_finish` не участвовал в
создании реализации и меняет только этот предварительно назначенный отчёт.
Проверяется завершение TASK-FE-001.04 и итоговый состав публикации foundation
.03–.07 с ранее подготовленной UX/планировочной документацией.

База frontend HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c`; текущий dirty baseline
зафиксирован coordinator в `/tmp/dictai-fe04-finish-20261030/baseline.json`
(190 frontend и 589 backend-файлов). В нём уже содержатся прежние foundation и
planning изменения; они не приписываются новой delta. Принятые .01/.02 не
реализуются и не перепроверяются. Содержимое личного `.vscode/settings.json`
не читалось; сохранность проверяется только по hash.

Прочитаны AGENTS/WORKFLOW, architecture, REVIEW_TEMPLATE, актуальные карточка .04,
PLAN-FE-001/active-plan и независимые отчёты .03-01/.04-02/.05-01/.06-01/.07-01.
Проверены весь native harness, SecureStorage/AuthInterceptor и оба entitlements;
действующие plugin Dart options/Swift Security API/error forwarding использованы
для сверки настоящего отрицательного OS-сценария.

Текущая source delta — `test/core/storage/keychain_smoke_app.dart`: runtime phase
override, фазы native denial/retry/stale/empty и точный индикатор сохранения legacy.
Управление подписью, keychain и публикацией выполняет coordinator; reviewer их
не меняет. Личные Xcode project/scheme и settings исключаются из commit.

## Findings

### F01 — [P3] Неверный индикатор legacy preservation в новой denied-фазе

Файл: `test/core/storage/keychain_smoke_app.dart:82`, первоначальная delta.

Impact: catch вычислял `phase != 'write' || ...`, поэтому для новой denied-фазы
печатал `legacy_preserved=true` даже при FAIL из-за отсутствующих legacy values.
Общий smoke всё равно завершался FAIL; проблема делала диагностическое evidence
недостоверным, а не разрешала plaintext fallback в production.

Evidence: source review показал безусловное true для denied/stale и других фаз.
Recommendation: проверять реальные ожидаемые значения для write/denied/stale,
в прочих случаях печатать `not_applicable`.

Disposition: **fixed with source evidence**. Coordinator добавил `expectsLegacy`,
сравнение fixture/stale values и nullable результат с `not_applicable`. Reviewer
перечитал изменённый catch; raw exceptions/credentials в output не добавлены.

Иных actionable source findings на текущем этапе нет. Вердикт остаётся partial
до native Debug/Release evidence, итоговой metadata и проверки staged diff.
Прежний **B01 OS smoke blocker остаётся open**; отсутствие source findings не
снимает обязательный критерий настоящего Keychain.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64. Собственные проверки
reviewer отделены от evidence coordinator и прежних исторических отчётов.
Повторные Dart checks используют восстановленный pinned Flutter 3.41.3/Dart 3.11.1
из `/tmp/dictai-fe04-finish-20261030/sdk/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`FLUTTER_SUPPRESS_ANALYTICS=true CI=true`; .01 не переоткрывалась, pins не менялись.

| Проверка reviewer | Результат | Статус/граница |
|---|---|---|
| Source review harness и pinned macOS plugin | Group опция идёт в `kSecAttrAccessGroup`; native OSStatus передаётся в PlatformException.details; expected -34018 проверяется явно | PASS source review, не OS run |
| Production storage/interceptor и оба entitlements к текущему baseline | Эти четыре файла не менялись в проходе; сохраняют прежний reviewed scope | PASS hash/source |
| SHA-256 190 frontend/589 backend к baseline текущего прохода | Изменены только harness/active-plan; остальные исходные файлы сохранены | PASS на момент промежуточной проверки |
| Первый промежуточный SHA-256 settings, project.pbxproj, Runner.xcscheme, pubspec.yaml/lock, Podfile.lock | Все шесть совпадали с текущим baseline до native build attempts | PASS исторический; личный settings только hash |
| `flutter test --no-pub test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart --reporter expanded` | Все 14 tests passed, exit 0 | PASS; localhost runner с разрешённым доступом, storage/HTTP fakes |
| `dart analyze lib/core/storage/secure_storage.dart lib/core/network/auth_interceptor.dart test/core/storage test/core/network/storage_interceptor_test.dart` | No issues found, exit 0 | PASS; включая новый native harness |
| `dart format --output=none --set-exit-if-changed` для тех же paths | 5 files, 0 changed, exit 0 | PASS; исходники не записывались |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements`; `git diff --check` | Оба plist OK, whitespace diagnostics нет | PASS syntax/diff; не OS security |
| Предварительный audit candidate-paths.json, 78 paths до добавления этого отчёта | Все существуют; credential/conflict patterns не найдены; нет settings/Xcode personal files, certificates/private keys, logs/SDK/build artifacts | PASS предварительный; не заменяет staged audit |
| Реальные Debug/Release Keychain write/restart/delete, denied/retry/stale/empty и applied entitlements | Ожидается coordinator evidence | NOT RUN пока; B01 open |
| Итоговая карточка/план/реестр, staged publication diff и credential/artifact scan | Состав ещё не staged | NOT RUN пока |

Прочитанное coordinator evidence, не собственный повтор native:
`debug-build.log` — FAIL, отсутствует Mac App Development provisioning profile
для текущего bundle ID. `debug-provision-build.log` — FAIL при
`-allowProvisioningUpdates`: Xcode сообщает No Accounts и недоступные credentials
в keychain (`missing Xcode-Username`), профиль не получен. `probe-sign.log` — FAIL,
`errSecInternalComponent`. Это конкретные signing/account/host blockers; код
Keychain приложения и runtime сценарии этими сборками не исполнялись.
Прежнюю формулировку «нет development certificate» следует уточнить, если blocker
сохранится: установка certificate/intermediate сама по себе ещё не подтверждает
подпись Runner и доступ к OS-хранилищу. Авторский `tests.log` содержит 72 PASS;
независимые 14 scope tests reviewer приведены отдельно выше.

Последующий собственный hash audit после native attempts обнаружил generated
delta в `macos/Runner.xcodeproj/project.pbxproj` и `macos/Podfile.lock` к user
baseline. Coordinator уведомлён: до публикации требуется восстановить только
появившуюся build/tool delta из сохранённого снимка, не удаляя пользовательскую
настройку Team. Settings, Runner.xcscheme и pubspec.yaml/lock сохранились.
Reviewer эти файлы не изменяет; окончательная сохранность и staged audit пока
не подтверждены. В candidate manifest оба изменившихся platform пути отсутствуют.

## Strengths and residual risk

Harness не меняет production options или entitlements ради отрицательной проверки.
`_DeniedWrites` использует настоящий plugin: read — обычную группу, write — группу,
отсутствующую в entitlements. Успех denied требует одновременно safe AppException,
native OSStatus -34018, сохранения всех synthetic legacy values и отсутствия OS JWT.
Следующий отдельный процесс должен подтвердить нормальную повторную миграцию.

Все ключи имеют проверяемый smoke prefix; cleanup ограничен namespace. Фаза empty
читает JWT напрямую, поэтому fail-closed bool `hasToken` не может скрыть OS failure.
Фазы stale/restart позволяют проверить приоритет существующего OS значения и
переживание перезапуска без повторного seed. Контролируемые fixtures не являются
реальными токенами, email или данными пользователя.

На этом промежуточном этапе macOS build/runtime и полнота будущей публикации не
подтверждены reviewer. Linux, capture, live backend и deployment вне scope; данный
отчёт не устанавливает accepted и сам не выполняет commit/push/merge/release.
