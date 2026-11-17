---
id: "TASK-FE-002.16"
plan: "PLAN-FE-002"
title: "Завершить удаление, account isolation и cleanup iOS flow"
status: "draft"
owner: "unassigned"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.15"]
scope: ["lib/features/results/presentation/results_notifier.dart", "lib/features/results/presentation/result_detail_notifier.dart", "lib/features/results/data/original_audio_cache.dart", "lib/features/record/data/pending_upload_store.dart", "lib/features/results/data/pending_job_store.dart", "lib/shared/providers/providers.dart", "lib/features/record/presentation/anonymous_record_notifier.dart", "lib/features/record/presentation/label_speakers_modal.dart", "lib/features/record/data/audio_ingest_api.dart", "lib/features/record/data/anonymous_session_api.dart", "test/features/results/ios_account_cleanup_test.dart", "docs/ai/tasks/TASK-FE-002.16.md", "lib/core/storage/ios_file_policy.dart", "ios/Runner/StoragePolicyBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_file_policy_test.dart", "ios/RunnerTests/RunnerTests.swift", "lib/features/record/data/dto/anonymous_session_dto.dart", "lib/features/record/data/ios_wav_import.dart", "test/features/record/ios_wav_import_test.dart", "lib/features/record/presentation/record_notifier.dart", "test/features/record/record_discard_test.dart"]
planned_paths: ["lib/features/results/presentation/result_detail_notifier.dart", "lib/features/results/data/original_audio_cache.dart", "test/features/results/ios_account_cleanup_test.dart", "lib/core/storage/ios_file_policy.dart", "ios/Runner/StoragePolicyBridge.swift", "ios/Runner/AppDelegate.swift", "ios/Runner.xcodeproj/project.pbxproj", "test/core/storage/ios_file_policy_test.dart", "ios/RunnerTests/RunnerTests.swift"]
reuses_tasks: ["TASK-FE-001.32", "TASK-FE-001.33", "TASK-FE-001.34"]
implementation_selected: true
---

# TASK-FE-002.16: Завершить удаление, account isolation и cleanup iOS flow

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Завершить удаление, account isolation и cleanup iOS flow. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.32](../tasks/TASK-FE-001.32.md), [TASK-FE-001.33](../tasks/TASK-FE-001.33.md), [TASK-FE-001.34](../tasks/TASK-FE-001.34.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] R02 delete инвалидирует список/detail/polls/player/cache/notice; tombstone/404 не возвращает старый результат через late response.
- [ ] Logout/401/account A→B освобождают capture/audio session, requests/listeners/timers и UI; B не видит файлы/labels/jobs A.
- [ ] Удаляются только принадлежащие приложению копии с явной политикой pending recovery и disk quota/backup exclusion/file protection; пользовательские Files originals/exports сохранены. Нативная file policy проверяет реальные resource/protection attributes, а не наличие Dart-флага.
- [ ] Legacy anonymous/voice/confirm consumers удалены после проверки импортов/тестов; desktop platform files не удаляются попутно и новые architecture layers не создаются.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Для file protection/backup exclusion добавить узкий StoragePolicyBridge с Dart-обёрткой и включением Swift в Runner; проверить реальные iOS attributes и поведение при блокировке, без новых packages. Перед удалением legacy расширить exact scope лишь для найденных потребителей внутри выбранного retirement; при внешнем scope сообщить finding, не удалять код вслепую. Старые desktop hardware adapters не становятся iOS runtime.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/results/ios_account_cleanup_test.dart test/core/storage/ios_file_policy_test.dart; scoped format; flutter analyze; поиск всех импортов удаляемых файлов | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: delete во время playback/poll/download, logout во время recording/upload, A→B, relaunch и lock | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
