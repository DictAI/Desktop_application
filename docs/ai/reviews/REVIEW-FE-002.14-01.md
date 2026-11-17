---
id: "REVIEW-FE-002.14-01"
task_ids: ["TASK-FE-002.14"]
reviewer: "/root/media_review_finish"
mode: "read-only"
status: "reviewed"
completion: "complete"
---

# REVIEW-FE-002.14-01

## Scope

2026-11-18. Независимый reviewer `/root/media_review_finish` не писал реализацию,
tests, task/plan/registry. Sole write path — этот заранее назначенный отчёт.
База `33a1fb3`, новый .14 source/tests и относящаяся документация; посторонний
`.DS_Store` исключён. Source review начат после author freeze; после native
failure freeze снят coordinator только для назначенного implementer.

Проверяются новые `lib/features/results/data/ios_document_export.dart`,
`ios/Runner/DocumentExportBridge.swift`, `test/features/results/ios_document_export_test.dart`,
diff detail screen/shared providers/AppDelegate/Runner project/native smoke,
`TASK-FE-002.14.md`, `IOS_MEDIA.ru.md` и .14 записи active-plan/PLAN.
`results_screen.dart` в разрешённом scope не изменён: вход из библиотеки ведёт
в detail. API/DTO/download implementation, lifecycle/session consumers,
Info.plist/deployment target прочитаны read-only. Frontend `.codegraph/` нет.

R05 и U04 сверены по текущим backend handlers read-only на HEAD `92ad6e4`
(`/Users/mxdnght/dictai`), без runtime API/write. TXT/PDF готовы независимо:
`summary_status=ready` и canonical не гарантируют R05 PDF bytes; export UI
разрешает попытку чтения, только validated200 разрешает system activity.
Source .15+ и отдельные задачи не входят в review.

## Findings

### F01 — [P2] lib/features/results/data/ios_document_export.dart:309

Impact: В ранней версии close мог удалить input активной system activity, если
native cancel бросал AppException: общий try пропускал await original operation
и переходил сразу к cleanup. Ошибка отмены не доказывает освобождение файла.

Evidence: Ранняя read-only проверка до freeze выявила общий try для cancel и
operation. Reviewer передал finding implementer/coordinator. Финальный код
разделяет эти ожидания и даже после failed cancel ждёт original sheet settlement.

Recommendation: Сохранять input и ownership до actual activity completion.

Disposition: fixed with evidence. Новый meaningful regression
`failed native cancel on session close keeps input until real completion`
подтверждает pending close/file exists до completion, затем cancelled outcome
и cleanup. Независимый targeted run102 PASS включает этот case.

### F02 — [P2] lib/features/results/data/ios_document_export.dart:287

Impact: Ранний non-recursive delete exclusive root не мог убрать собственный
оставшийся download subtree, если DocumentsApi бросал до возврата DownloadedFile;
retryCleanup повторял бы удаление непустой папки без прогресса.

Evidence: Reviewer передал ранний source corner implementer. Финальный cleanup
удаляет только созданный exporter createTemp root рекурсивно, после settlement.
Новый adverse test оставляет owned partial subtree до prepare failure.

Recommendation: Очищать exclusive owned residue, сохраняя чужие paths/copies.

Disposition: fixed with evidence. Независимый targeted102 PASS включает
`prepare failure removes even an owned leftover partial subtree`; bytes saved
user copy проверяются отдельными всеми пятью kind cases.

### F03 — [P2] ios/Runner/DocumentExportBridge.swift:51

Impact: Первоначальный native whitelist разрешал только NSTemporaryDirectory,
тогда как стандартный Dart temporary provider создаёт файлы в Library/Caches.
Реальная system activity не открывалась для обычного iOS export.

Evidence: Root native smoke после первоначального freeze FAIL на iPhone и iPad
в `export_present_transcriptTxt`, без presented/CHECK markers. Reviewer сверил
закреплённый `path_provider_foundation 2.5.1` PathProviderPlugin.swift:63–64:
`case .temp` возвращает `FileManager.SearchPathDirectory.cachesDirectory`.
Dart exporter использует resultTemporaryDirectoryProvider/getTemporaryDirectory,
Swift до исправления проверял только NSTemporaryDirectory. Host fake sheet не
мог выявить это платформенное несовпадение.

Recommendation: Согласовать owned staging locations по обе стороны bridge,
ограничив разрешённые temporary/cache roots и формы принадлежащих exporter
подкаталогов; повторить настоящий native iPhone/iPad smoke.

Disposition: fixed with evidence. Native guard теперь принимает canonical
NSTemporaryDirectory и FileManager cachesDirectory, одновременно требует
`dictai-export-* / dictai-download-* / fixedName`, MIME whitelist и regular file.
Оба настоящих iPhone/iPad Simulator export smoke после исправления PASS с
четырьмя CHECK и итоговым PASS export. Reviewer independently прочитал source
delta и оба root log; native запуск выполнял coordinator.

## Verification

Собственные команды reviewer: cwd `/Users/mxdnght/dictai-app`, macOS arm64,
Flutter3.41.3/Dart3.11.1 из `/tmp/dictai-flutter-3.41.3`, prepared dependencies,
без pub/SDK/lock/platform permission изменений.

| Проверка reviewer | Actual | Status / limitation |
|---|---|---|
| `flutter --no-version-check test --no-pub test/features/results/ios_document_export_test.dart test/features/results/documents_api_test.dart test/features/results/ios_result_detail_test.dart test/features/results/ios_results_library_test.dart test/features/results/ios_audio_player_test.dart --reporter expanded` | 102/102 PASS, exit0, `/tmp/dictai-review-00214-tests.log` | PASS, первоначальный freeze до native F03 fix; host HTTP/sheet/player fakes |
| Pinned `dart format --output=none --set-exit-if-changed` exporter/detail/providers/export tests/native smoke | 5 files, 0 changed, exit0 | PASS, первоначальный freeze |
| Source/native/project/full new tests review; current backend handlers; pinned path_provider native source | Readiness, streamed bytes, file lifetime/cancellation, identity, cleanup и actual Caches/temp mismatch изучены | PASS source review с findings выше |
| `git diff --check` | Whitespace diagnostics нет | PASS, до final delta |
| Native Simulator iPhone/iPad export smoke | Root сообщил FAIL, reviewer прочитал оба log: checkpoint export_present_transcriptTxt, CHECK/PASS отсутствуют | FAIL evidence coordinator, `/tmp/dictai-finish-export-iphone.log`, `/tmp/dictai-finish-export-ipad.log` |
| Собственные native/provider/device/backend E2E | Не запускались | NOT RUN; reviewer не выдаёт host fake за UIKit |

Author102 tests/format5/analyze PASS7 старых info прочитаны в карточке;
самостоятельный reviewer targeted102/format5 указан отдельно выше. Final native
build и production restoration coordinator выполняет после F03 fix.

## Strengths and residual risk

Потоковый DocumentsApi сохраняет реальные авторизованные server bytes, в channel
идут только id/path/MIME. TXT/PDF readiness не выводится из общей done/canonical.
Сервис привязан к session/result, late/stale session не открывает activity.
Native identity fencing защищает новое окно, ранний cancel ждёт окончания
presentation animation; large bytes не копируются в Flutter channel.
Cleanup сохраняет ownership/retry при ошибке и не удаляет пользовательские copies.

Открытых actionable findings нет, независимый review завершён. Physical iPhone,
Save to Files/provider writes, сторонние share apps, реальные provider failure,
VoiceOver и signed device E2E NOT RUN. Native sheet/cancel smoke их не заменяет.
Отчёт не присваивает accepted; commit/push разрешены отдельным поручением
пользователя и выполняются coordinator после review gate.


## Final delta — 2026-11-18

После F03 изменились только `DocumentExportBridge.swift` и test-only native
smoke. Dart exporter/UI/providers/host tests остались побайтово прежними, поэтому
независимый host102 PASS сохраняется; лишний полный повтор не запускался.
Reviewer повторно прочитал исправленный native guard, test-only safe known-code
diagnostics/foreground wait, task/IOS_MEDIA и актуальные PLAN/active-plan.
После refreeze hash8 source/test paths совпадают. Task review/owner, таблица
плана и review registry created/owner согласованы; planned_paths только новые.
Исторические FAIL сохранены отдельно, physical/provider-write NOT RUN не закрыты.

| Самостоятельная delta-проверка reviewer | Actual | Status / limitation |
|---|---|---|
| Пinned `dart format --output=none --set-exit-if-changed` для пяти изменённых Dart paths | 5 files, 0 changed, exit0 | PASS |
| `plutil -lint ios/Runner.xcodeproj/project.pbxproj` | OK | PASS |
| Python frozen8 SHA-256, Ruby YAML task/PLAN, локальные Markdown links task/PLAN/active/IOS_MEDIA/review; `git diff --check` | Freeze сохранён, YAML/status/owner корректны, broken links=0, whitespace diagnostics нет | PASS |
| Прочитанные root native logs `/tmp/dictai-finish-export-iphone-fixed.log`, `/tmp/dictai-finish-export-ipad-fixed.log` | В каждом transcriptTXT/summaryPDF/original presentation-cancel, stale identity, early cancel CHECK; затем `DICTAI_IOS_MEDIA PASS export` | PASS evidence coordinator, не самостоятельный native run |
| Прочитанный root build `/tmp/dictai-finish-export-build-fixed.log` | Export target PASS9.2s | PASS evidence coordinator |
| Прочитанный root `/tmp/dictai-task-fe-002.14-final-build.log` | Production main PASS7.8s после F03 | PASS build evidence coordinator; install/launch отражает coordinator отдельно |

Native environment coordinator: macOS/Xcode26.5, Flutter3.41.3/Dart3.11.1,
iPhone17Pro и iPadPro11M5 Simulator/iOS26.5. Во всех native случаях synthetic
bytes, без backend/account/external provider writes. Реальный UIKit popover
проверен на iPad, но Save to Files/внешние providers, подписанный physical device,
accessibility/VoiceOver и реальные provider failures остаются NOT RUN.
Независимый source/host/Simulator review gate .14 пройден. accepted не выставлен;
последующие native file protection/cleanup требования .16 не приписываются .14.
