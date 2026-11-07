---
id: REVIEW-FE-001.09-01
task_ids: ["TASK-FE-001.09"]
reviewer: /root/results_contracts
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.09-01

## Scope

2026-11-03. Независимый reviewer `/root/results_contracts`. База frontend
HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c`, рабочий diff .09. Прочитаны
auth notifier и login UI, SecureStorage и AuthInterceptor, providers,
AuthListenable и GoRouter, session/navigation tests, widget fixture и карточка.
Связанные .08 AuthApi/DTO и .04 storage failure tests прочитаны для сверки.
Единственная запись в репозитории приходится на этот зарезервированный отчёт.

Backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` использован для чтения.
Auth service выдаёт HS256 JWT с `user_id`, `iss=dictai-auth-v2`, `aud=dictai-user`
и integer `exp` на семь дней. A03 получает пользователя из проверенного JWT.
GoRouter применяет claims как локальные подсказки срока и навигации. Gateway
проверяет подпись и доступ.

## Findings

| ID / priority | File | Impact | Evidence | Recommendation | Disposition |
|---|---|---|---|---|---|
| F01 / P1 | `lib/core/storage/secure_storage.dart:151`, `lib/core/network/auth_interceptor.dart:54`, `lib/features/auth/presentation/auth_notifier.dart:136` | После неудачного logout transport продолжает использовать старый действующий bearer. Частичное удаление при текущем 401 может оставить защищённый экран без уведомления об истечении. | Изолированный probe отклонил удаление `jwt_token`. Logout сообщил ошибку и закрыл доступ через `hasValidSession`, затем AuthInterceptor приложил прежний JWT к защищённому GET. Второй probe удалил JWT и отклонил последующее удаление email. `readCredential` вернул null, `onUnauthorized` не вызывался. | В общей очереди подавить использование совпавшего credential при logout/401 до попыток физической очистки. Уведомить auth/router о совпавшем 401 и при частичной ошибке cleanup. Ошибку удаления оставить наблюдаемой. Сохранить защиту новой revision от старого 401. | fixed |
| F02 / P2 | `lib/core/storage/secure_storage.dart:128`, `lib/features/auth/presentation/auth_notifier.dart:175`, `lib/features/auth/presentation/auth_notifier.dart:241` | Отказ сохранения обновлённого JWT может остановить уже запланированное локальное истечение. | `_saveValue` увеличивает revision до write. Probe с fake clock и отказом записи в renewal сохранил прежние bytes с новой revision. После expiry исходный CAS пропустил удаление, состояние осталось `idle`, прежний JWT оставался доступен в storage. | При отказе renewal сохранить revision только для подтверждённо неизменившегося credential. При изменившемся или неподтверждённом состоянии закрыть доступ и обновить auth/router. Проверить таймер с контролируемым storage failure. | fixed |
| F03 / P2 | `lib/core/storage/secure_storage.dart:128`, `lib/features/auth/presentation/auth_notifier.dart:84` | Login может показать ошибку записи и одновременно открыть доступ с уже сохранённым JWT. | Probe записал и подтвердил JWT, затем отклонил удаление legacy key. `login` вернул `AuthStatus.error` и пропустил callback, а `hasValidSession` вернул true для того же credential. Router использует этот результат независимо от статуса формы. | Публиковать credential только после подтверждённого завершения login storage операции или подавлять частично сохранённый JWT при ошибке. Тест должен проверить и router probe, и отсутствие bearer для staged failure. | fixed |

Отдельный край жизненного цикла передан implementer для проверки. В debug
`notifyListeners` у уже уничтоженного ChangeNotifier может бросить FlutterError.
`onError` должен завершить handler и при исключении из callback уведомления.
Delta добавила регрессию с исключением callback. Dio возвращает контролируемую ошибку и завершает запрос.

## Verification

Самостоятельные проверки в `/Users/verliiar/Desktop_application`, macOS 26.2 arm64,
Flutter 3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter` и готовый pub-cache.

| Проверка | Результат | Статус / граница |
|---|---|---|
| `flutter test --no-pub --timeout 45s test/features/auth test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart test/widget_test.dart --reporter expanded` | 52 tests passed | PASS. Проверено исходное состояние до исправления findings. |
| `flutter analyze --no-pub` в девяти Dart paths карточки | No issues found | PASS, только .09 scope. |
| `dart format --output=none --set-exit-if-changed` для восьми изменённых Dart paths | 8 files, 0 changed | PASS. |
| Временный Flutter probe с текущими AuthNotifier/SecureStorage/AuthInterceptor, fake storage и scripted Dio | 4/4 probes воспроизвели отказ logout, частичное удаление 401, staged login и потерю expiry после failed renewal | PASS воспроизведения findings. Исходники и тесты репозитория reviewer не записывал. |
| Backend auth claims, router/guards и signed-out routes | Сверены real source и synthetic route tests | PASS сверки. |
| Реальный gateway, повтор native Keychain smoke .04, feature isolation .34, capture guard .49 | Не запускались | NOT RUN. |

Ключевые SHA-256 до исправления findings.

- `secure_storage.dart` `d0f23eb55c4b88c08b72d578864a42f55390a1341bececb9465a39df276a3963`
- `auth_interceptor.dart` `cb04c692d397263dab6842efb94d0e0e89247efc68678c04ef13dca0f05d4c57`
- `auth_notifier.dart` `45387df28e2d563494ce276acee3934c1d3cbb4679f37b4bd5cbf605145e121d`
- `session_navigation_test.dart` `fda81bbbae0b35a3cd7996491465996cc5f3744cfe7ec48e3850de096ba0fbb9`

## Delta review

F01 исправлен в `secure_storage.dart:183` и `auth_interceptor.dart:56`.
Очередь блокирует чтение matched credential перед попытками удаления. При ошибке
следующий запрос не получает bearer. Совпавший 401 уведомляет listener и при
частичном удалении, stale revision по-прежнему пропускается. Тест с исключением
listener подтвердил завершение Dio в отведённое время.

F02 исправлен в `secure_storage.dart:138` и `auth_notifier.dart:246`. Подтверждённо
прежний JWT сохраняет revision. Его таймер истечения срабатывает после отказа
renewal. При изменившихся или неподтверждённых bytes credential подавляется,
notifier закрывает сессию. Проверены отказ до записи и ошибка после записи.

F03 исправлен той же границей публикации. После частичной записи JWT router
не признаёт сессию. Полный успешный повтор разблокирует опубликованный token.
Существующий storage regression обновлён, чтобы проверять скрытый token до
явного повторного cleanup и нормальное удаление после устранения отказа.

Независимо повторены 75 тестов, включая 57 auth/storage/widget и 18 capture
regressions. Exact analyze по десяти Dart paths и format по девяти изменённым
Dart paths прошли. Whitespace scoped diff и отчёта без diagnostics. Новых
открытых findings по рассмотренному diff нет.

SHA-256 проверенных изменений после исправлений.

- `secure_storage.dart` `8e7b4e0e4ad8a20e3f8fef8c4635b931b4894200fb18287fa62bc74ee5a6b192`
- `auth_interceptor.dart` `2a479db53ca11805af1afa73ea793192282c7c68cb30932927ffdb301c48967f`
- `auth_notifier.dart` `ffa17971b1b58e246b7cdd495f0359babbfe6fa404b14b7a817ab3b4f40a6941`
- `session_navigation_test.dart` `643c5625ddbd26da736047b0f96775b88f1496b95d49b4f3a2fcf3a0a741e082`

## Strengths and residual risk

Очередь хранения защищает успешные replace/delete от поздних ответов по token и
revision. Исходные tests охватывают повторный вход с теми же байтами, отдельный
public 401, успешную замену и фактический GoRouter redirect после текущего 401.
Подавление после отказа OS storage действует в текущем процессе. Если физически
сохранённый действующий JWT пережил отказ и приложение перезапустили до очистки,
восстановление возможно. Native fault smoke после изменений не выполнялся.
Feature cleanup после выхода и состояние активной записи входят в .34 и .49.
Приёмка остаётся решением владельца.
