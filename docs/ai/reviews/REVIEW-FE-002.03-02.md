---
id: REVIEW-FE-002.03-02
task_ids: ["TASK-FE-002.03", "TASK-FE-002.04", "TASK-FE-002.05"]
reviewer: /root/ios_sdk3413_review
mode: read-only
status: reviewed
---

# REVIEW-FE-002.03-02

## Scope

2026-11-16. Независимый reviewer `/root/ios_sdk3413_review` не писал
проверяемую реализацию, тесты, session-документацию или координационные записи.
Единственный write scope этого прохода — данный отчёт. Основной проход и
независимый delta по F01 завершены; приёмка пользователя и полная verification
задачи этим не устанавливаются.

База: HEAD `260b1493066ba4e99aa52f8283fd5b0e2da3e4a3` и snapshot перед .03
`/tmp/dictai-ios-session-baseline.json` (335 файлов, SHA-256
`31749e1bf88face0e083e0987218938c3b82f7c62559b1b290307eb4d2f00778`).
Immutable handoff: `/tmp/dictai-ios-session-review-freeze.json` (338 файлов,
SHA-256 `887760a6a39de2adea7d08a33d6ec2814fd4a0b54588019a8cfdc18a13e18c06`).
На старте review все 338 текущих хешей совпали с freeze. `.DS_Store` исключён из
freeze, существующий сторонний файл сохранён. HEAD не менялся, staging пуст.

Проверены tracked production diff, полное содержимое четырёх новых файлов
и документационная согласованность следующего scope:

- `lib/core/storage/secure_storage.dart`;
- `test/core/storage/ios_session_test.dart`;
- `test/core/config/ios_gateway_test.dart`;
- `test/core/storage/ios_session_smoke_app.dart`;
- `docs/testing/IOS_SESSION.ru.md`;
- `docs/ai/tasks/TASK-FE-002.03.md`;
- только blocker-документация `docs/ai/tasks/TASK-FE-002.04.md` и
  `docs/ai/tasks/TASK-FE-002.05.md`;
- текущий учёт .03 и закрытых gates .04/.05 в `docs/ai/active-plan.md` и
  `docs/ai/plans/PLAN-FE-002.md`.

Связанные существующие SecureStorage migration/credential guards, AppConfig,
createDio/AuthInterceptor, AuthApi/AuthNotifier/AuthListenable и auth regression
tests изучены read-only. Семантика опций сверена с фактическим pinned
`flutter_secure_storage 9.2.4` в pub cache. Native/.metadata/pubspec/lock,
auth/router/providers и workspace sources неизменны относительно baseline335.
Функциональная реализация .04/.05 исключена из этого review и не начиналась.
Ранее проверенные .01/.02 не пересматривались; механическое обновление отчёта
другого reviewer `.02-03` вне .03 scope отмечено при сравнении manifest.

## Findings

[F01, P3] `docs/testing/IOS_SESSION.ru.md:35`;
связанная формулировка `docs/ai/tasks/TASK-FE-002.03.md:99`.

Impact: Без указания срока действия suppression описание failed cleanup
исторического synchronized item можно прочитать как гарантию для следующего
cold start. Retained JWT на новом процессе может снова стать читаемым.

Evidence: Документ обещает, что credential «останется подавленным для будущих
запросов». `_suppressedCredentials` в `secure_storage.dart:79` — static Dart Set;
он не переживает завершение процесса. Pinned native read может вернуть
synchronized item, а non-synchronized delete его не удаляет. Production code
этого scope не создаёт synchronized items; это уточнение границ документации.

Recommendation: Явно ограничить suppression текущим Dart-процессом и указать,
что cold start может снова прочитать retained item. Синхронизировать Result .03;
изменение поведения или новая cleanup/migration в этот finding не входят.

Disposition: **fixed with evidence**, 2026-11-16. Координатор уточнил только
IOS_SESSION и Result .03. Reviewer повторно прочитал оба изменённых абзаца:
теперь явно указаны срок suppression, отсутствие его сохранения на диск и
возможное восстановление retained synchronized JWT после cold start.
Source/tests не менялись. Открытых actionable findings нет.

Обязательные physical iPhone checks остаются **NOT RUN** и блокируют завершение
.03 и передачу functional gates .04/.05. Это известное ограничение окружения,
которое карточки и план отражают явно; отсутствие findings его не устраняет.

## Verification

Cwd всех собственных команд: `/Users/mxdnght/dictai-app`, macOS host,
Python 3 stdlib/Ruby Psych/Git. `.codegraph/` отсутствует. Reviewer не запускал
Flutter/pub/tests/build/native smoke и не менял Simulator. Единственная
собственная simctl-команда — read-only `get_app_container` для проверки cleanup.
Private account JSON и его содержимое reviewer не читал.

| Собственная проверка reviewer | Результат | Status / предел |
|---|---|---|
| `git status --short --untracked-files=all`; `git diff -- lib/core/storage/secure_storage.dart`; полный read новых файлов | Единственное production-изменение — explicit iOS storage options и keyed delete; посторонний diff сохранён | PASS, source review |
| Inline `python3` с `json`/`hashlib`, baseline335 → freeze338 → текущие файлы; `git rev-parse HEAD`, `git diff --cached`, `git ls-files --cached --others --exclude-standard` | Все338 хешей совпали; неожиданных путей нет; HEAD прежний, staging пуст; 42 iOS-файла и указанные выше protected groups совпали с baseline | PASS, границы handoff |
| `git diff --check`; `git diff --no-index --check /dev/null <new-file>` для каждого из четырёх новых файлов | Whitespace diagnostics отсутствуют; no-index exit1 отражает новый файл | PASS |
| Ruby `YAML.safe_load` frontmatter .03/.04/.05/PLAN; inline Python resolve локальных Markdown links шести документов | YAML валиден, 180 относительных ссылок существуют; owners/dependencies/status/unchecked physical criteria согласованы | PASS, документация |
| Чтение pinned plugin Dart/Swift и существующего production session stack | iOS dispatch, write/delete queries, legacy migration, verification и credential suppression согласованы с документацией | PASS, статический аудит |
| Чтение host tests и standalone native target, локального `/tmp/run_dictai_ios_session_smoke.py` | Девять новых host cases; native phase allowlist, namespace, bounded config/credential reads, generic output, точный PASS check и cleanup проверены | PASS, source review; helper не запускался |
| Inline Python: `xcrun simctl get_app_container <selected-simulator> com.dictai.app data`, затем `Path.exists` только для двух известных временных путей | `Library/Application Support/dictai-ios-session-smoke.json` и `tmp/dictai-ios-smoke-credentials.json` отсутствуют | PASS, независимо повторённый read-only cleanup check |
| Чтение `/tmp/dictai-ios-session-cleanup.log` | Producer также подтвердил cleanup и сохранение локального account file с mode0600 | Evidence автора; account file reviewer не открывал |
| Чтение log summaries/точных phase markers и `/tmp/dictai-ios-session-main-login.png` | Ниже отделено от собственных runtime-проверок | PASS, аудит evidence; повторного runtime-прогона нет |

Проверено evidence координатора на Flutter3.41.3/Dart3.11.1, Xcode26.5,
iPhone17 Pro Simulator/iOS26.5 build23F77:

| Команда / scenario автора | Проверенное evidence | Предел вывода |
|---|---|---|
| Scoped format четырёх Dart-файлов | В handoff зафиксировано 4 files / 0 changed | Reviewer форматирование не повторял |
| Targeted `flutter test --no-pub --reporter expanded` | `dictai-ios-session-targeted-tests.log`: `+60: All tests passed!` | Host mocks/fakes, не native Keychain attributes |
| Full `flutter test --no-pub --reporter expanded` | `dictai-ios-session-tests.log`: `+561: All tests passed!` | После запуска изменялся только standalone native harness |
| Initial/final `flutter analyze --no-pub --no-fatal-infos` | Оба лога содержат 9 info, 0 warnings/errors | Проверка analyzer, не поведения устройства |
| Native smoke builds | Initial13.0s, diagnostic7.9s, final fallback6.8s: `Built build/ios/iphonesimulator/Runner.app` | Сборки отдельно от runtime |
| Старые write/restart/diagnostic attempts | Initial/diagnostic logs содержат `FAIL invalid_configuration`; diagnostic подтверждает ios=true и отсутствие env phase/namespace | Исторический FAIL сохранён, storage/network тогда не начаты |
| Final `write`, `restart`, `legacy_delete`, `empty` | В каждом отдельном phase log ровно ожидаемые START/PASS строки, неожиданных session markers нет | Native migration/persistence/keyed cleanup на Simulator; без introspection OS attributes |
| `https_untrusted`, затем `https` после штатного add-root-cert | Ожидаемые START/PASS в обоих логах; source допускает negative PASS только при badCertificate/HandshakeException, positive требует HTTP response | TLS из общего Dio на данном Simulator; trust mutation самостоятельно не повторял |
| `auth_register_login`, `auth_restart`, `auth_logout` | Три ожидаемых PASS markers; assertions используют текущие AuthApi/AuthNotifier, native storage, protected WorkspaceApi read и unauthorized read после logout | Реальная test auth session на Simulator; не UI taps и не physical lock/restore |
| Восстановление `lib/main.dart`, build/install/launch/render | Main build log:17.6s и Built Runner.app; launch log существует; screenshot визуально показывает обычную форму входа | Production entrypoint не импортирует smoke; screenshot не доказывает отправку формы |
| Physical iPhone checks | Evidence отсутствует, signing недоступна по handoff/карточке | NOT RUN; mandatory gate сохранён |

Пути логов и полные команды автора сохранены в
[IOS_SESSION.ru.md](../../testing/IOS_SESSION.ru.md). Для native phases
проверялись точные `DICTAI_IOS_SESSION PASS <phase>`, а не только exit status
`simctl launch`. В прочитанных native auth/TLS logs не найдены JWT/email-like
значения; actual-secret matching checker относится к evidence координатора,
reviewer реальные секреты для сравнения не получал.

Delta F01: повторное inline Python `json`/`hashlib` сравнение с freeze обнаружило
изменение ровно `docs/testing/IOS_SESSION.ru.md` и `docs/ai/tasks/TASK-FE-002.03.md`;
прочитаны исправленные строки35–43 и99–105 соответственно. `git diff --check`
для обоих путей не дал diagnostics, HEAD/staging сохранены. Doc-only уточнение
не меняет применимость ранее прочитанного code/runtime evidence. Flutter/tests
повторно NOT RUN: source/tests не менялись.

Финальный accounting delta, 2026-11-16: после reviewed координатор обновил
только шесть уже проверяемых документов — active-plan, PLAN, TASK .03/.04/.05
и IOS_SESSION, включая F01. Повторное сравнение всех338 freeze paths подтвердило
неизменность source/tests/native/dependencies и остальных файлов. Review rows
теперь PASS, резерв отчёта created, последний организационный AC .03 checked;
три физических AC .03 и все функциональные AC .04/.05 остаются unchecked.
PLAN и .03/.04/.05 сохраняют blocked. Текущие записи согласованы с этим отчётом,
прежние snapshots обозначены историей. YAML пяти файлов разобран без ошибок,
183 локальные ссылки существуют, `git diff --check` чист, HEAD/staging прежние.
Новых findings нет; повторные Flutter/native проверки для этого doc-only delta
NOT RUN как нерелевантные.

## Strengths and residual risk

Новые iOS writes явно используют `first_unlock_this_device` и
`synchronizable:false`. `accessibility:null` у keyed delete опускает
accessibility filter, сохраняя service/account и non-synchronized scope. Это
сверено с `AppleOptions.toMap` и native `baseQuery`/`delete`; native smoke также
проверяет удаление созданных default-unlocked test items. Desktop options
остаются прежними: pinned Dart plugin выбирает их через `dart:io Platform`.

Native `read` игнорирует запрошенную accessibility и может прочитать retained
synchronized item; сама успешная операция не измеряет protection attributes.
Эта граница честно описана. При retained synchronized item существующая
post-delete verify может завершиться ошибкой, подавляя credential в текущем
процессе. Подавление не является доказательством удаления или сохранения этого
состояния после restart. Массовая очистка/Keychain sharing не добавлены.

Standalone target изолирует synthetic, public TLS и actual auth namespaces.
Config/credential reads ограничены размером и timeout, endpoint сверяется с
AppConfig, partial environment не подменяется stale fallback. Вывод не включает
исключения, JWT, email, password или response bodies. Единственная предусмотренная
серверная запись — явно разрешённая регистрация test account; helper удаляет
временные sandbox-файлы, а серверный аккаунт сохраняется пользователю.
Политики origin/redirect/TLS и текущий auth wire сохранены; ATS exceptions,
TLS bypass, встроенный CA, новые dependencies/permissions/entitlements отсутствуют.

Cold process persistence, login/logout и HTTPS на Simulator подтверждены
прочитанным evidence. Physical lock/unlock, недоступный Keychain, смена аккаунта,
reinstall/restore, iPhone HTTPS/auth и фактические OS protection attributes этим
не подтверждены. CA остаётся доверенным только выбранному Simulator по evidence
координатора. Микрофон/background capture/Files UX не входили в этот проход.

Независимый review переданного scope завершён. F01 P3 исправлен и проверен,
открытых actionable findings нет. TASK-FE-002.03 сохраняет status blocked до
mandatory physical evidence; functional gates .04/.05 закрыты,
accepted/commit/push/merge/release не назначены.
