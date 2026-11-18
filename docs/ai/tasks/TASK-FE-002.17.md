---
id: "TASK-FE-002.17"
plan: "PLAN-FE-002"
title: "Закрепить iOS batch-сценарий регрессионными проверками"
status: "review"
owner: "/root"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.16"]
scope: ["test/features/ios_batch_regression_test.dart", "test/support/fakes.dart", "docs/testing/IOS_REGRESSION.ru.md", "docs/ai/tasks/TASK-FE-002.17.md"]
planned_paths: ["test/features/ios_batch_regression_test.dart", "docs/testing/IOS_REGRESSION.ru.md"]
reuses_tasks: ["TASK-FE-001.06", "TASK-FE-001.35", "TASK-FE-001.38"]
implementation_selected: true
---

# TASK-FE-002.17: Закрепить iOS batch-сценарий регрессионными проверками

## Реализация — 2026-11-18

Продолжено прямое поручение пользователя закончить прежнюю очередь и push.
Dependency .16 прошла checks/independent review и отправлена в origin/main
commit `8da7b55`. Автор `/root/batch_regression` подготовил пять joined tests и
первый targeted PASS, затем его turn остановлен quota. Coordinator `/root`
принял sole write, проверил готовые файлы, завершил full regression и docs;
owner передан до записи в active-plan. Production source .16 не менялся.

Новый `test/features/ios_batch_regression_test.dart` использует реальные
AuthApi/AuthNotifier/AuthInterceptor, workspace API, IosWavImporter/WavValidator,
RecordNotifier/BatchSession/journal/processing/detail/notice, original cache,
ResultAudioController, exporter и ResultsNotifier. Подменены только HTTP,
Keychain storage и native capture/decoder/share boundaries. Нет sockets,
настоящего микрофона, Keychain или runtime demo mocks.

Пять сценариев: Files и microphone полные flow (два tests), invalid Files и
permission refusal, suspend/late A response после login B, unknown upload outcome
с restart/A→B→A и явным same-key replay. Проверяются bearer/workspace/options/key,
owner/audio/job/version canonical, decoded/exported bytes, сохранность user Files,
R02 fences для detail/notice/tracker/list и отсутствие лишнего POST. Отдельные
existing suites покрывают permission prompt, interruption, route changes и 401;
матрица и opt-in harness находятся в
[IOS_REGRESSION.ru.md](../../testing/IOS_REGRESSION.ru.md).

## Verification реализации

Cwd `/Users/mxdnght/dictai-app`, macOS26.5.2 arm64, pinned
Flutter3.41.3/Dart3.11.1 из `/tmp/dictai-flutter-3.41.3`, prepared locked packages.
SDK/dependencies/lock не обновлялись, `pub get` не выполнялся.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `flutter --no-version-check test --no-pub test/features/ios_batch_regression_test.dart --reporter expanded` | Author5/5 PASS; `/tmp/dictai-fe00217-targeted-initial.log` | PASS | Fake native/HTTP/Keychain boundaries |
| `flutter --no-version-check test --no-pub --reporter expanded` | Coordinator803/803 PASS34s; `/tmp/dictai-finish-20261118-full-regression.log` | PASS | Все host unit/widget suites; не device E2E |
| `flutter --no-version-check analyze --no-pub` | No issues, exit0; `/tmp/dictai-finish-20261118-analyze.log` | PASS | Production/test Dart, не hardware |
| Direct pinned `dart format --output=none --set-exit-if-changed test/features/ios_batch_regression_test.dart` | 1 file/0 changed, exit0 | PASS | Изменённый Dart scope |
| Direct pinned `dart format --output=none --set-exit-if-changed lib test` | 125 files,5 would change, exit1; `/tmp/dictai-finish-20261118-full-format.log` | FAIL baseline | app_colors/app_theme/anthropic_service/chat_panel/main уже такими в initial snapshot; hashes всех5 совпадают, посторонний scope не форматировался |
| YAML/DAG/table/status/owner/scope/links/whitespace/full tracked+untracked diff | Coordinator/reviewer PASS, review .17-01 reviewed/complete | PASS | Только docs/source integrity |
| .16 production main Simulator7.2s/install/launch и unsigned device26.0s | PASS до test/doc-only .17 diff; runtime sources frozen в `8da7b55` | PASS reused source evidence | Повторный native build не требуется для test/docs; не hardware PASS |
| Opt-in iPhone/backend harness, physical permissions/lock/Files/Keychain/model/peak RAM | Не запускался | NOT RUN | Signing/device services/operator/accounts отсутствуют; .18 blocked |
| Независимые reports .17-01/.18-01/.19-01 | Reviewed/complete, actionable findings нет; targeted5/format1 повторены reviewer | PASS | Review не присваивает accepted |

## Result реализации

Добавлены новый integration regression test и IOS_REGRESSION.ru.md, обновлена
эта карточка. `test/support/fakes.dart` сохранён без изменений; новые packages,
production source, backend и platform permissions не менялись. Пять новых
сценариев и весь803 host suite PASS, analyze no issues. Полная форматная команда
сохраняет пять подтверждённых baseline failures вне scope; изменённый файл clean.
Harness отделяет synthetic assertions от opt-in hardware/backend evidence и
согласован с [device шагами](../../testing/IOS_DEVICE_E2E.ru.md) /
[backend gate](../../testing/IOS_BACKEND_GATE.ru.md). Невыполненные physical
сценарии не объявлены PASS, user acceptance отсутствует. Status review до
пользовательской приёмки. Независимый [REVIEW-FE-002.17-01](../reviews/REVIEW-FE-002.17-01.md)
reviewed/complete, actionable findings нет; reviewer5 tests/format1 PASS.

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Закрепить iOS batch-сценарий регрессионными проверками. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.06](../tasks/TASK-FE-001.06.md), [TASK-FE-001.35](../tasks/TASK-FE-001.35.md), [TASK-FE-001.38](../tasks/TASK-FE-001.38.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Набор покрывает login/workspace→mic или Files→WAV validation→upload/202→canonical→player/export→delete/logout по существующим контрактам.
- [x] Проверены permission refusal/interruption/suspend/network failure/unknown upload outcome/restart/account change; нет пустых tests и runtime demo mocks.
- [x] Fixtures синтетические, virtual timers/fakes не читают настоящий Keychain/микрофон/API; unit/widget и opt-in device E2E разделены.
- [x] Подготовлен opt-in ручной device/backend harness с точными шагами, предусловиями и evidence для .18; автоматизированный unit/widget regression не зависит от новых packages.
- [x] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Существующий flutter_test используется для регрессии, device/backend сценарии фиксируются как воспроизводимый ручной opt-in harness. Новая зависимость integration_test и pubspec/lock изменения в этот scope не входят. Переход к автоматизации device E2E возможен отдельным выбранным расширением, не является скрытым prerequisite.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification planning baseline

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test --no-pub; flutter analyze --no-pub; dart format --output=none --set-exit-if-changed lib test — подготовленные зависимости | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Сверка ручного IOS_REGRESSION device/backend harness с каждым критерием .18 и действующими API | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result planning baseline

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
