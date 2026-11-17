---
id: "REVIEW-FE-002.16-01"
task_ids: ["TASK-FE-002.16"]
reviewer: "/root/cleanup_review_finish"
mode: "read-only"
status: "reviewed"
completion: "complete"
---

# REVIEW-FE-002.16-01

## Scope

2026-11-18. Независимый reviewer `/root/cleanup_review_finish` не писал
проверяемую реализацию, тесты, карточку, PLAN или registry. Единственный write
path reviewer в репозитории — этот отчёт. База — `3665fae`; проверены tracked
diff и четыре новых source/test файла из exact scope
[TASK-FE-002.16](../tasks/TASK-FE-002.16.md), а также её карточка и относящиеся
изменения PLAN-FE-002/active-plan. Исторический planning text отделён от текущего
Result. `.17+` и прежние implementation scopes не входят в этот review.

Проверенный source/platform/test scope — 31 путь, перечисленные в frontmatter
карточки без самой карточки: 21 существующий/новый Dart-файл, пять Swift/PBX
путей и пять удалённых legacy Dart-файлов. SHA-256 snapshot
`/tmp/dictai-task16-frozen-20261118.json` после авторского freeze совпал для всех
31 путей, включая отсутствие пяти удалённых файлов. Новые `IosFilePolicy`,
`StoragePolicyBridge`, policy tests и account cleanup tests прочитаны полностью.

Связанные неизменённые auth/session, playback/export/lifecycle, API/DTO и
upload modal consumers изучены read-only. Для уточнения R03 прочитана текущая
backend реализация `92ad6e4572a3b12a601ba3ab7e5cc385a21694ae`; backend не менялся.
Frontend `.codegraph/` отсутствует; в backend `codegraph explore` недоступен
(exit127), после чего использован source search. Secret/config bodies не читались
и не переносились в отчёт.

## Findings

### F01 — [P2] lib/features/results/presentation/processing_notifier.dart:313

Impact: В промежуточной реализации remote R03 loss вызывал только
`store.markDeleted(audioId)`. Это оставляло sibling requests/timers/canonical
в tracker, хотя audio уже было объявлено удалённым, и могло удерживать
concurrency slots до завершения старого запроса.

Evidence: Предварительный source audit выявил отличие от `removeAudio`,
отменяющего токены и таймеры всех versions. При последующем уточнении F04
граница invalidation разделена: pinned missing version получает exact-key
unavailable fence с отменой своего token/timer/deadline; подтверждённое R02 или
latest-result loss используют audio-wide `removeAudio`.

Recommendation: Согласовать tombstone с фактическим ресурсом и одновременно
отменять соответствующие requests/timers и удалять недействующий canonical.

Disposition: fixed with evidence. Независимо прошли regressions
`confirmed R02 cancels every sibling version and removes its canonical` и
`pinned R03 404 fences only the missing version and preserves a live sibling`.
Held sibling token отменяется при R02; late reply не восстанавливает state.

### F02 — [P2] lib/features/record/data/pending_upload_store.dart:404

Impact: Ранний `prepare(root dictai-pending-v1)` рекурсивно обходил все accounts
до owner lock. Повреждённая чужая subtree могла блокировать journal текущего
владельца; параллельный обход гонялся с metadata rename/cleanup.

Evidence: В final `StoragePolicyBridge.swift:39` общий journal container
защищается только по своим metadata; recursive policy ограничена выбранным
owner. Dart выполняет её после получения process queue и filesystem lock.
Native `testSharedJournalContainerDoesNotTraverseOtherOwners` подтверждает, что
broken symlink в другом owner не блокирует здоровый journal и не меняет sentinel.

Recommendation: Защищать общий root без обхода accounts; рекурсивную проверку
selected owner сериализовать с его же journal writes.

Disposition: fixed with evidence. Независимо прошёл Dart regression
`recursive per-owner protection is serialized by the journal lock`;
native regression входит в прочитанный final XCTest log 9/9 PASS.

### F03 — [P2] lib/features/record/presentation/record_notifier.dart:703

Impact: Failed capture event/start/finish cleanup освобождал и обнулял capture,
не сохраняя его sourcePath. После этого logout не знал точный owned WAV и мог
оставить его на диске.

Evidence: Final `_releaseCapture` сохраняет путь до и после native disposal.
`_revokeCapture` ждёт release/durable prepare и удаляет только известные regular
files, не рекурсивный parent и не внешние Files originals. Matching late native
response сохраняет первый путь для cleanup, не возвращая status после dispose.

Recommendation: Сохранять ownership на всех error/release путях до окончательной
очистки; проверить failure → release → logout и поздние callbacks.

Disposition: fixed with evidence. Независимо прошли failed-capture→logout,
logout/401 при held native disposal, late finish и late matching capture reply
regressions. Проверяются отсутствие POST и сохранность unrelated source.

### F04 — [P2] lib/features/results/data/pending_job_store.dart:47

Impact: Pinned R03 `job_id=B` 404 сначала ошибочно становился audio-wide
tombstone и закрывал живые sibling jobs A, включая list/detail/player/cache.

Evidence: Backend `services/results-service/internal/presentation/handlers/`
`speech_handler.go` фильтрует `($3='' OR j.job_id=$3)` и возвращает 404 при
отсутствии выбранной version. Это не доказывает отсутствие всего audio.
Final store имеет отдельные exact-key `markUnavailable` listeners; consumers
закрывают только соответствующий key. Latest R03 без job_id и R02 остаются
audio-wide. U03 TTL и canonical artifact errors не создают audio tombstone.

Recommendation: Различать version loss и подтверждённое audio loss без нового
API-контракта; закрепить valid sibling survival и запрет revival missing key.

Disposition: fixed with evidence. Независимо прошли processing sibling
canonical test, account-cleanup sibling cache lease test и изменённый
`ios_ready_notice_test`: missing key не делает новый GET/notice после 404;
другой valid key получает notice, R02 убирает обе версии. Прежнее ожидание
revival 404→200 заменено конкретными проверками этой семантики, не пустым assert.

Открытых actionable findings в выбранном diff после исправлений нет.

## Verification

Reviewer cwd `/Users/mxdnght/dictai-app`, macOS arm64, подготовленные locked
dependencies, pinned Flutter3.41.3/Dart3.11.1 `/tmp/dictai-flutter-3.41.3`.
Reviewer не запускал pub get, SDK/lock updates или platform builds.

| Самостоятельная проверка reviewer | Actual | Status / limitation |
|---|---|---|
| `flutter --no-version-check test --no-pub test/features/results/ios_account_cleanup_test.dart test/features/results/processing_recovery_test.dart test/features/record/record_discard_test.dart test/features/record/ios_audio_capture_test.dart test/core/storage/ios_file_policy_test.dart test/features/results/ios_ready_notice_test.dart test/features/results/documents_api_test.dart test/features/record/ios_wav_import_test.dart --reporter expanded` | 168/168 PASS, 3s, `/tmp/dictai-review-00216-focused.log` | PASS; fake HTTP/native/Keychain, реальные private synthetic files |
| Direct pinned `dart format --output=none --set-exit-if-changed` всех существующих changed/untracked Dart paths | 21 files, 0 changed, exit0; `/tmp/dictai-review-00216-format.log` | PASS |
| SHA-256 final frozen scope, including deleted paths | Все 31 path совпадают со snapshot coordinator | PASS |
| `rg` retired filenames/classes в `lib test` | References не найдены | PASS, exit1 — ожидаемое отсутствие matches |
| `git diff --check`; source/native/project/full diff inspection | Whitespace ошибок нет; source membership/channel registration согласованы | PASS |
| Ruby YAML и Python link/status/scope checks карточки/PLAN/registry/этого отчёта | Проверены final docs и ссылки | PASS; организационная проверка отдельно от runtime |
| Самостоятельные hardware/backend/native runs | Не выполнялись | NOT RUN; прочитанное evidence автора/coordinator ниже отдельно |

Прочитанное evidence, не самостоятельные runs reviewer:

- Author final13 suites: 262/262 PASS4s,
  `/tmp/dictai-cleanup-final-targeted2.log`; analyze no issues/exit0 сообщён
  автором, scoped19 format дополняется полным reviewer format21.
- Native writer final9 XCTest PASS27.8s,
  `/tmp/dictai-filepolicy-xctest-review-f02-20261118.log`: реальные backup
  attributes, containment, symlink/hardlink guards и selected-owner isolation.
  На Simulator log явно содержит `protectionVerified=false` и
  `backupExclusionVerified=true`. Это не PASS iPhone Data Protection.
- Root media capture build27.4s и smoke
  `/tmp/dictai-finish-20261118-capture-smoke.log` содержат оба CHECK и PASS capture.
  Явно собранная export phase build8.0s и
  `/tmp/dictai-finish-20261118-export-smoke-final.log` содержат START export,
  четыре CHECK и PASS export. Ранний env override повторил capture и не
  учитывается как export evidence.
- Root production main Simulator build PASS7.2s,
  `/tmp/dictai-task-fe-002.16-final-build.log`; install/launch PASS отражены в
  task. Unsigned device compile PASS26.0s,
  `/tmp/dictai-finish-20261118-unsigned-device-build.log`: строгая device branch
  компилируется, signed install/device runtime не выполнялись.

Начальные native positive tests FAIL установили отсутствие protection attribute
в Simulator, после чего добавлен честный compile-time capability result. Неверное
ненулевое protection значение и отсутствие backup exclusion по-прежнему ошибки;
физическая device branch не имеет fallback. Первый targeted run с прежним notice
revival expectation FAIL сохранён в истории; final262 и independent168 проверяют
исправленный diff. Эти FAIL не представлены успешными проверками.

## Strengths and residual risk

Deletion fences синхронны; async cleanup уважает lease/native sheet ownership.
Pending/unknown upload остаётся owner-bound для явного same-key recovery,
без автоматического POST после login/restart. Квоты journal/cache/download
явные; policy failure до/после записи закрывает операцию и сохраняет только
разрешённую recovery ownership. Пользовательские Files source/export сохранены
регрессиями. Зависимости, wire format, auth policy, permissions/entitlements и
desktop platform files не менялись.

Actual iPhone first unlock/lock, background/interruption, native data protection,
delete/logout при реальном playback/upload, Files provider write и backend E2E
остаются NOT RUN. Simulator filesystem capability и unsigned device compile
их не заменяют. OS-denied stop/delete не считается cleanup PASS; owned paths
сохраняются для повтора, process death может оставить private staging до OS
cleanup. Durable pending retention после logout — явная recovery политика.

Полный независимый review выбранного host/Simulator implementation scope
завершён. Отчёт не устанавливает `accepted`, не снимает physical criteria и не
является разрешением на Store публикацию.

## Final organizational delta — 2026-11-18

Reviewer повторно прочитал окончательные task/PLAN/active-plan записи: .16
остаётся review с owner `/root/cleanup_prep_finish`; .16-01 имеет created,
reviewed/complete и ссылку из Result. Summary сохраняет final main7.2s,
unsigned device26.0s, native9 и physical NOT RUN; `accepted` не назначен.
`python3 /tmp/dictai-finish-20261118-doc-check.py` — PASS20 task YAML/DAG/table/
status/owner/scope/152 local links, исходный `.DS_Store` сохранён. Все frozen31
source/test/platform hashes повторно совпали. Новых изменений реализации или
findings нет; независимый review завершён.
