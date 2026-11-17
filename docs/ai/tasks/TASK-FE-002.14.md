---
id: "TASK-FE-002.14"
plan: "PLAN-FE-002"
title: "Экспортировать документы и WAV через iOS Files/share sheet"
status: "review"
owner: "/root/export_prep_finish"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.13"]
scope: ["lib/features/results/data/ios_document_export.dart", "lib/features/results/presentation/result_detail_screen.dart", "lib/features/results/presentation/results_screen.dart", "ios/Runner/DocumentExportBridge.swift", "ios/Runner/AppDelegate.swift", "test/features/results/ios_document_export_test.dart", "ios/Runner.xcodeproj/project.pbxproj", "docs/ai/tasks/TASK-FE-002.14.md", "test/features/results/ios_media_smoke_app.dart", "docs/testing/IOS_MEDIA.ru.md", "lib/shared/providers/providers.dart"]
planned_paths: ["lib/features/results/data/ios_document_export.dart", "ios/Runner/DocumentExportBridge.swift", "test/features/results/ios_document_export_test.dart"]
reuses_tasks: ["TASK-FE-001.30", "TASK-FE-001.31"]
implementation_selected: true
---

# TASK-FE-002.14: Экспортировать документы и WAV через iOS Files/share sheet

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Экспортировать документы и WAV через iOS Files/share sheet. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Историческое поручение 2026-11-16 разрешало перепланирование; текущий выбор
реализации и owner заданы выше и в актуальном active-plan.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.30](../tasks/TASK-FE-001.30.md), [TASK-FE-001.31](../tasks/TASK-FE-001.31.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Transcript TXT/PDF, summary TXT/PDF и original WAV доступны только по реальной готовности соответствующего документа.
- [ ] Авторизованный download сохраняет server bytes; временный owned file передаётся в системный share/Save to Files без публичных token URLs и macOS open/Linux xdg-open.
- [ ] Filename/MIME/cancel/provider failure корректны; файл живёт до завершения system activity, очистка не удаляет пользовательский export.
- [ ] Большие файлы не загружаются целиком в память и не выставляют контейнер приложения для общего доступа без необходимости; iPad popover anchor безопасен.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Первый вариант — узкий native bridge UIActivityViewController/документный export с обеими сторонами MethodChannel. Новый package возможен только с отдельным обоснованным scope.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push выполняет coordinator по отдельному текущему
разрешению пользователя; merge/release не поручены.

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/results/ios_document_export_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: Save to Files/share/cancel, offline download, TXT/PDF/WAV, сохранённые bytes; iPad Simulator popover smoke | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.


## Verification реализации — 2026-11-18

Cwd `/Users/mxdnght/dictai-app`; macOS arm64, закреплённый
Flutter 3.41.3 / Dart 3.11.1 (`/tmp/dictai-flutter-3.41.3`), prepared dependencies,
`--no-pub`, без обновления dependencies/SDK/подписи.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter --no-version-check test --no-pub test/features/results/ios_document_export_test.dart --reporter expanded` (pinned SDK выше) | 17/17 PASS | PASS | Новый host suite с fake sheet/HTTP и собственными synthetic bytes; не UIKit/provider |
| `flutter --no-version-check test --no-pub test/features/results/ios_document_export_test.dart test/features/results/documents_api_test.dart test/features/results/ios_result_detail_test.dart test/features/results/ios_results_library_test.dart test/features/results/ios_audio_player_test.dart --reporter expanded` | 102/102 PASS, final repeat после source freeze | PASS | `/tmp/dictai-ios-export-targeted-final.log`; .13 player/detail/library/stream regressions |
| `dart format --output=none --set-exit-if-changed lib/features/results/data/ios_document_export.dart lib/features/results/presentation/result_detail_screen.dart lib/shared/providers/providers.dart test/features/results/ios_document_export_test.dart test/features/results/ios_media_smoke_app.dart` (direct pinned Dart) | 5 files, 0 changed, exit0 | PASS | Только точный изменённый Dart scope |
| `flutter --no-version-check analyze --no-pub --no-fatal-infos` | 0 errors/warnings, 7 прежних info вне scope | PASS | `/tmp/dictai-ios-export-analyze-final.log`, repeat `/tmp/dictai-ios-export-analyze-native-fix.log`; промежуточные новые test infos исправлены, финальный запуск чист от новых diagnostics |
| Intermediate production Simulator build coordinator | PASS, Xcode8.8s | PASS, intermediate | `/tmp/dictai-task-fe-002.14-intermediate-build.log`; до final smoke/test hardening, не final evidence |
| First native export run на iPhone+iPad Simulator | FAIL до первой sheet: pinned path_provider `.temp` оказался Library/Caches, native guard принимал только NSTemp | FAIL, исправлен | Guard теперь допускает canonical native temporary/cache roots только с owned staging layout; root повторяет реальные фазы. Logs `/tmp/dictai-finish-export-iphone.log` / `-ipad.log`; исходный FAIL не объявлен PASS |
| Final native `DICTAI_IOS_MEDIA_PHASE=export`: iPhone+iPad Simulator | Выполняет coordinator/root после source freeze | NOT RUN автором | Требуются реальные presented/cancel/early-cancel markers, не один launch exit0 |
| Independent REVIEW-FE-002.14-01 | Передано `/root/media_review_finish`, source/tests frozen | IN REVIEW | Report назначен отдельному агенту, self-check его не заменяет |
| Физический iPhone, внешний Files provider Save/share, provider failure, сохранённые user bytes, VoiceOver | Не выполнялось | NOT RUN | Simulator sheet/cancel и host bytes не доказывают реальные provider writes/hardware |

## Result реализации — 2026-11-18

Изменены `lib/features/results/data/ios_document_export.dart` (новый),
`result_detail_screen.dart`, общий `providers.dart`, новый native
`ios/Runner/DocumentExportBridge.swift`, его registration в AppDelegate и
Runner project, новый `ios_document_export_test.dart`, существующий explicit
`ios_media_smoke_app.dart`, эта карточка и `docs/testing/IOS_MEDIA.ru.md`.
`results_screen.dart` из разрешённого scope не потребовал изменения: библиотека
уже открывает detail, все export controls собраны там.

На iOS detail показывает «Скачать и поделиться» с отдельными TXT/PDF transcript,
TXT/PDF summary и original WAV. Transcript и summary разрешают запрос независимо
по собственному validated status; job ID жёстко закреплён за detail. Статус
не выдаётся за готовность отдельного PDF: только успешный validated HTTP200
DocumentsApi разрешает передачу файла в system activity. При document-unavailable,
MIME/PDF/WAV/length/partial/network failure системное окно не открывается,
показывается безопасное сообщение. Original использует существующий U04 без
job query; documents — R05 с pinned job ID. Новых URL/контрактов/dependencies нет.

Exporter владеет уникальным временным root и DownloadedFile. Server bytes
сохраняются потоково неизменными; большие файлы не пересылаются через channel
и не загружаются service целиком в память. Native принимает только regular
local files в native temporary/cache roots, строго в собственном
`dictai-export-*/dictai-download-*`, с whitelist fixed filename/MIME, отдаёт URL в настоящий
UIActivityViewController. Native presenter выбран в foreground UIWindowScene;
iPad использует sourceView и in-bounds sourceRect. Публичный Files container,
macOS/Linux открытие и platform permissions не добавляются.

System activity удерживает файл до completion/dismissal. Cancel привязан к
request identity, stale cancel ничего не закрывает; cancel во время presentation
дожидается её завершения перед dismiss. Logout/session close отменяет download
или собственное system окно; даже failed native cancel не разрешает cleanup до
реального завершения activity. Новый export заблокирован до окончания предыдущего
и до успешной очистки. Cleanup failure сохраняет ownership и явный retry;
чужие файлы/сохранённые пользовательские copies не удаляются. PrepareDirectory
hook оставлен для выбранной последующей .16 file policy, сам native protection
этой задачей не заявлен.

17 новых meaningful host cases подтверждают все пять типов/bytes/MIME/filename,
отдельную readiness, unavailable404, doubletap/job mismatch, provider failure,
file lifetime до completion, cancellation/session races (включая failed cancel),
partial transfer, cleanup retry/leftover subtree и streamed20MiB. Native explicit
phase export проверяет реальные TXT/PDF/WAV sheet presentation/cancel, stale id,
early cancellation и owned cleanup; фактический native результат дописывает root.
Full physical acceptance/accepted не заявлены. Commit/push в этой сессии разрешён
пользователем отдельно; выполняет coordinator после review, автор не коммитил.


## Итог нативной проверки coordinator — 2026-11-18

Cwd frontend, pinned Flutter3.41.3/Dart3.11.1, Xcode26.5/macOS,
iPhone17Pro и iPadPro11M5 Simulator/iOS26.5. Зависимости/lock/signing сохранены.
`flutter build ios --simulator --debug --no-pub --target test/features/results/ios_media_smoke_app.dart --dart-define=DICTAI_IOS_MEDIA_PHASE=export`:
после F03 PASS9.2s, log `/tmp/dictai-finish-export-build-fixed.log`.
`simctl install`/`launch --console --terminate-running-process` на каждом:
PASS, logs `/tmp/dictai-finish-export-iphone-fixed.log` и
`/tmp/dictai-finish-export-ipad-fixed.log`. На обоих есть все четыре CHECK:
TXT/PDF/WAV real presentation + stale cancel + own cancel, early cancel во время
анимации, затем `DICTAI_IOS_MEDIA PASS export`. Файл удерживается до dismissal,
owned staging удаляется. Это реальный UIKit/iPad popover smoke с synthetic
bytes; внешний Files provider Save/write и physical iPhone не выполнялись.

Первый native run обоих FAIL на export_present_transcriptTxt из-за несовпадения
Library/Caches и NSTemporaryDirectory. F03 исправлен до push; первый FAIL не
выдаётся за успешную проверку. Native guard теперь учитывает оба принадлежащих
приложению ephemeral roots и строгое имя owned export/download directories.

Final production main `python3 /tmp/dictai_ios_max_build.py 14-final`: PASS7.8s;
установка/запуск на обоих Simulator PASS, production target/config восстановлены.
Doc checker YAML20/DAG/table/status/owner/scope/149 local links/whitespace PASS;
исходный .DS_Store сохранён вне commit.

Независимый REVIEW-FE-002.14-01 reviewed/complete: F01–F03 исправлены, открытых
findings нет. Host/Simulator gate пройден; physical/accepted не заявлены.
