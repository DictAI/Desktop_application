# iOS batch regression — TASK-FE-002.17

Это host regression и opt-in ручной harness. Синтетический HTTP adapter,
временные app-owned directories, mock SecureStorage и fake capture/decoder/share
не обращаются к API, Keychain, микрофону или Files providers. Эти результаты
не доказывают качество модели, запись при блокировке или права на backend.

## Подготовка host

Из корня frontend используйте согласованный Flutter/Dart, соответствующий
pubspec и lock. Текущее подготовленное окружение: Flutter3.41.3/Dart3.11.1,
`/tmp/dictai-flutter-3.41.3`. Не обновляйте SDK/dependencies ради проверки.

```sh
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub test/features/ios_batch_regression_test.dart --reporter expanded
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded
/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check analyze --no-pub
```

Format проверяется pinned Dart только по изменённым Dart paths. Полный набор
включает существующие host tests; opt-in `*_smoke_app.dart` автоматически не
запускаются как hardware E2E. Подробные фактические команды и результаты — в
карточке TASK-FE-002.17; запуск команд выше сам по себе не является PASS.

## Матрица автоматизированных границ

| Поведение | Evidence suite | Предел |
|---|---|---|
| Login/workspace→Files или mic→WAV→202→canonical→player/export→delete/logout | `test/features/ios_batch_regression_test.dart` | Реальные Dart controllers/API/journals, заменены I/O boundaries |
| Permission denial, permission-prompt cancellation, interruption, manual resume | `test/features/record/ios_audio_capture_test.dart`, `record_discard_test.dart` | Host event/channel fakes, без реального AVAudioSession |
| Suspend/resume, network failure, unknown outcome, durable replay, account switch | `test/features/record/ios_upload_recovery_test.dart`, `ios_batch_regression_test.dart` | Session/filesystem/HTTP adapter; без background URLSession |
| Canonical readiness и independent summary, artifact errors, stale responses | `test/features/results/processing_recovery_test.dart`, `ios_result_detail_test.dart` | Contract fixtures, не модель |
| Cache quotas/leases, decoding failure, interruption, export lifetime | `test/features/results/ios_audio_player_test.dart`, `ios_document_export_test.dart` | Fake decoder/sheet; UIKit smoke отдельно |
| Delete, logout/401, account isolation, native policy contract | `test/features/results/ios_account_cleanup_test.dart`, `test/core/storage/ios_file_policy_test.dart` | Host assertions; native resource attributes/platform evidence отдельно |
| Tabs/auth/record guard/layout | `test/core/router/ios_navigation_test.dart`, `test/features/record/ios_record_flow_test.dart` | Flutter widgets, physical VoiceOver отдельно |

## Opt-in iPhone/backend harness

Не запускается обычным `flutter test`. До начала нужны разрешённые HTTPS
test-origin, backend/operator, два специальных аккаунта A/B и disposable
workspace/recordings, физический iPhone, рабочие device services и signing/team.
Не используйте production recordings. Секреты, raw API bodies с личными данными,
UDID, Keychain dump и реальные аудиозаписи в Git не сохраняйте. Для gateway
проверить текущие контракты существующих маршрутов; новый endpoint не требуется.

1. Зафиксировать дату, frontend/backend SHA, iPhone model/iOS, Xcode/SDK,
   version/build, bundle ID, public config source, signing owner и install method.
   Проверить TLS через общий Dio без ATS exceptions. Подготовить evidence table
   ниже и согласовать оператору cleanup созданных disposable записей.
2. Войти A. Проверить workspace list/open/contact selection и выбранный workspace
   при возврате в Record. Проверить вход с неверным паролем без раскрытия деталей.
   Использовать WAV с известной синтетической речью и отдельный no-speech WAV;
   не выдавать fixture или UI readiness за оценку модели.
3. На clean permission state отказать в микрофоне. Убедиться, что видна полезная
   ошибка и запись/upload не стартовали. Разрешить микрофон в Settings вручную;
   Start→Pause→Resume→Pause→«Отправить». Отмена discard/exit сохраняет запись,
   подтверждённый discard удаляет только текущую app-owned копию без POST.
4. Повторить запись с lock/background, реальным interruption и route change.
   Записать длительность до/после, отсутствие автоматического resume после
   interruption, отправку после паузы и валидность WAV. Force quit не обещает запись.
5. Импортировать WAV через реальный Files provider. Проверить cancel, недоступный
   provider, MP3/M4A/повреждённый WAV; исходник во Files должен сохраниться.
   Для рабочего WAV сверить language/mixed/workspace и один POST U01 либо U02,
   HTTP202 с существующими audio/job/version (и session для anonymous).
6. Отключить сеть до POST, во время передачи и после server acceptance до
   ответа. Не делать новый POST автоматически. После relaunch/возврата сети
   открыть явный same-key replay; оператор подтверждает idempotency без
   дубликата. Проверить suspend/resume polling, отсутствие циклов запросов.
7. Дождаться R03/R04: 202/pending не готовность; готовность только при валидном
   canonical200 нужного owner/audio/job/version. Проверить no_speech и
   неизвестное/ошибочное состояние; summary может быть pending/failed независимо.
   Готовое in-app notice не сбрасывает текущую запись и соблюдает exit guard.
8. Открыть detail, сверить transcript/segments/timecodes, summary, scroll/large
   text/VoiceOver; включить original player, pause/seek, затем capture. Проверить
   реальную native stop/ACK последовательность, interruption/route change.
9. Экспортировать TXT/PDF/original через системный share и Save to Files, затем
   открыть результат внешним viewer. Проверить iPad anchor при доступном iPad,
   cancel/ошибку provider, logout во время sheet. Пользовательский export остаётся;
   app-owned staging удаляется после system activity completion.
10. Удалить disposable R02 результат во время poll/download/playback. Старые
    detail/list/notice не возвращают запись после late response/refresh/relaunch;
    original во Files и прежние пользовательские exports сохранены.
11. Выйти A при recording/upload/открытом detail. Войти B: нет labels/jobs/files
    A, playback/capture прекращены, поздний ответ A не попадает B. Войти A снова:
    pending recovery только A и по explicit same-key replay. Проверить matched401
    отдельно; старый401 до смены credential не должен отзывать новую сессию.
12. Записать peak memory/длительность длинного transcript и playback, crash logs
    без секретов, остаточные ограничения и operator cleanup. Результаты
    permission/lock/Keychain/Files/реального backend заносятся отдельно от Simulator.

## Evidence

| Case | SHA/build/device | Command/steps + expected | Actual | PASS/FAIL/NOT RUN | Limitation/evidence reference |
|---|---|---|---|---|---|
| TLS/login/workspace/Keychain | Заполняет оператор | Шаги1–2 | Не выполнено | NOT RUN | Нужны разрешённые test environment/accounts |
| Mic/permissions/lifecycle/route | Заполняет оператор | Шаги3–4 | Не выполнено | NOT RUN | Нужен физический iPhone/signing |
| Files/WAV/202/recovery | Заполняет оператор | Шаги5–6 | Не выполнено | NOT RUN | Нужны provider и реальный backend |
| Canonical/summary/notice/player | Заполняет оператор | Шаги7–8 | Не выполнено | NOT RUN | Host fixtures не заменяют качество/устройство |
| Export/delete/account isolation | Заполняет оператор | Шаги9–11 | Не выполнено | NOT RUN | Нужны A/B и disposable resources |
| Memory/duration/cleanup | Заполняет оператор | Шаг12 | Не выполнено | NOT RUN | Прикрепить sanitized evidence |

Readiness и release gates ведутся отдельно в TASK-FE-002.18/.19. Наличие harness
или host PASS не устанавливает accepted и не разрешает публикацию в Store.
