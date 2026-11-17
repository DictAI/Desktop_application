---
id: "REVIEW-FE-002.09-01"
task_ids: ["TASK-FE-002.09", "TASK-FE-002.10"]
reviewer: "/root/acceptance_review"
mode: "read-only"
status: "reviewed"
completion: "complete"
---

# REVIEW-FE-002.09-01

## Scope

2026-11-17. Независимый reviewer `/root/acceptance_review` не писал реализацию,
тесты, карточки или учётные документы. Единственный write scope — этот заранее
назначенный отчёт. Автор `/root/recovery_prep` подтвердил final source/tests
freeze до независимого прогона, затем передал карточку coordinator.

База перед .09 — snapshot362
`/var/folders/nk/dn15wj451d90zxf_gxkbdgjr0000gn/T/dictai-max-stage-09-1uislbox/`:
`baseline.json`, `files/`, `HEAD`. Diff сравнивался с этим snapshot, который
уже содержит проверенную .20, а не со всем накопленным git diff.

Полностью проверены изменения/новые файлы:

- `lib/core/lifecycle/ios_lifecycle_observer.dart`;
- `lib/features/results/presentation/processing_notifier.dart`;
- `lib/shared/providers/providers.dart`;
- `lib/features/record/data/pending_upload_store.dart`;
- `test/features/record/ios_upload_recovery_test.dart`;
- карточка .09 и текущая delta .10/PLAN/active-plan с integration evidence.

Связанные неизменённые PendingJobStore, RecordNotifier, ResultsNotifier/Screen,
V2 upload/status/canonical API, auth/session и существующие tests изучены
read-only. Для .10 проверены только новая документационная integration delta,
взаимодействие с recovery и повторный host regression её iOS/desktop library.
Её предыдущая реализация не переписывалась и не объявляется физически готовой.

## Findings

Открытых actionable findings нет.

Lifecycle observer различает resumed и inactive/hidden/paused, не меняет
capture и снимается при dispose. iOS session связывает один observer с одним
tracker; desktop сохраняет прежнее поведение. Повторный foreground state
не порождает новый restore. При закрытии сессии listener снимается до отмены
tokens/очистки tracker; следующему аккаунту не передаются старые jobs.

Suspend отменяет timers/HTTP и меняет generation; поздний ответ не может
перезаписать состояние после resume. Journal restore отделён от поколения
HTTP и переживает suspend/resume, сохраняя проверки mounted/stopped/current
session и deletion tombstones. Resume читает только подходящие jobs;
terminal/401 не начинают автоматический retry. Failure count, bounded backoff
и оставшийся deadline error retry сохраняются; explicit refresh остаётся явным.

Accepted receipts восстанавливают polling без POST. Unknown pending upload
сохраняет owned WAV/options/key и восстанавливается только явным replay
того же ключа; обычному Dio не приписана бессрочная фоновая передача.
Временные FileSystemException source/metadata преобразуются в безопасную
ошибку хранения, не в необратимый source-changed/corrupt marker.

## Verification

Cwd собственных команд: `/Users/mxdnght/dictai-app`; macOS,
Flutter3.41.3/Dart3.11.1 по `/tmp/dictai-flutter-3.41.3`, prepared packages,
без pub/SDK/lock изменений. Все строки ниже выполнены самим reviewer,
кроме отдельно обозначенного evidence автора.

| Собственная проверка reviewer | Actual | Status / limitation |
|---|---|---|
| Полный stage09 diff трёх изменённых production files, содержимое двух новых Dart files, lifecycle/session/journal/results consumers | Cancellation, generation/deadline fencing, restore и same-key replay проверены | PASS, статический review |
| `/tmp/dictai-flutter-3.41.3/bin/flutter --no-version-check test --no-pub --reporter expanded test/features/record/ios_upload_recovery_test.dart test/features/results/processing_recovery_test.dart test/features/record/pending_upload_store_test.dart test/features/results/ios_results_library_test.dart test/features/results/results_library_test.dart test/features/record/ordinary_flow_test.dart test/features/record/anonymous_flow_test.dart test/features/record/record_discard_test.dart` | 122/122, exit0; log `/tmp/dictai-review-00209-tests.log` | PASS, host unit/widget/fake HTTP, включая .10 и .20 regression |
| Direct pinned `dart format --output=none --set-exit-if-changed` для пяти changed/new Dart paths из Scope | 5 files, 0 changed, exit0 | PASS |
| Inline Python SHA-256 stage09 baseline для source/test/platform/dependency/.DS_Store вне exact .09 scope | 194 protected файлов неизменны; изменены только три назначенных tracked production paths; HEAD/index сохранены | PASS, границы этого stage |
| Final Python/Ruby YAML/status/table/owner/links/scopes и scoped/new-file whitespace | YAML4/selected20/.09-.10 status-owner-table согласованы; 133 local links; scoped и 3 new-file whitespace без diagnostics | PASS, organizational delta |
| Physical iPhone airplane mode, lock/file protection, OS suspend/termination/relaunch и backend duplicate-job evidence | Не выполнялись | NOT RUN; host/POSIX не заменяют устройство или backend |

Новый suite содержит 10 осмысленных cases: регистрация/удаление binding
observer, repeated state dedupe, cancel/late response после suspend,
terminal/реальный401 response, сохранение capped retry deadline, restore race,
initial suspended session с accepted receipt, unknown outcome и same-key
replay после удаления original, transient directory/source/metadata access,
изоляция владельца и logout. POSIX case реально меняет permissions только
на synthetic owned journal files и восстанавливает их в finally;
это не проверка iOS protection attributes.

Автор отдельно сообщил full analyze PASS с семью прежними info и повтор
тех же122 tests/format5; reviewer проверил соответствующие записи карточки,
analyze повторно не запускал. Новый Simulator build в этом stage не выполнялся
и не заявляется: последний .20 build отделён от .09. Итоговая integration
сборка остаётся работой coordinator, hardware/backend gates — .18.

## Strengths and residual risk

Host scope .09 и его интеграция с существующей .10 проверены без блокирующих
findings. Текущие .09/.10 task/PLAN статусы review сохраняют physical/backend
NOT RUN и отсутствие accepted. По выбранной очереди и ADR-FE-013 это допускает
следующий implementation scope .11 после handoff единственного writer.
Симуляция lifecycle, POSIX permissions и host tests не подтверждают OS background
execution, реальные iPhone lock/kill/relaunch или уникальность серверного job.
Отчёт не принимает другие задачи и не разрешает commit/push/merge/release.
