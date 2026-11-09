---
id: TASK-FE-001.24
plan: PLAN-FE-001
title: "Заменить anonymous confirm на owner-only V2 batch UX"
status: review
owner: /root/ordinary_v2
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.23"]
backend_tasks: ["TASK-002.16", "TASK-002.25", "TASK-002.30"]
api_contracts: ["U02", "U03", "R03", "R04"]
blocked_by: []
scope:
  - "lib/features/record/presentation/anonymous_record_notifier.dart"
  - "lib/features/record/presentation/record_notifier.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/features/record/presentation/upload_modal.dart"
  - "lib/features/record/presentation/label_speakers_modal.dart"
  - "lib/shared/providers/providers.dart"
  - "lib/features/workspace/presentation/workspace_detail_screen.dart"
  - "test/features/workspace/workspace_record_start_test.dart"
  - "test/features/record/anonymous_flow_test.dart"
  - "docs/ai/tasks/TASK-FE-001.24.md"
planned_paths:
  - "test/features/record/anonymous_flow_test.dart"
delivery_stage: current
---

# TASK-FE-001.24: Заменить anonymous confirm на owner-only V2 batch UX

## Goal

Авторизованная запись и отправка WAV без workspace через общий capture, журнал и
трекер задач. Трекер получает canonical transcript с исходными метками спикеров.
Маршрут и отображение результата входят в [TASK-FE-001.28](TASK-FE-001.28.md).

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Anon пишет M4A/OGG; открывает недismissible LabelSpeakersModal, collects name/email и confirm создаёт workspace.

**Целевое:** Авторизованная отправка WAV без workspace в существующий U02 с
сохранением 202 receipt и отслеживанием готовности canonical transcript.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.23](TASK-FE-001.23.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.30
API: U02, U03, R03, R04.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: owner-only anonymous V2, сразу к результату без confirm/назначений.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Без workspace действуют общий snapshot до Start и подтверждение Stop с
  отправкой WAV. Предупреждение при уходе входит в [TASK-FE-001.49](TASK-FE-001.49.md).
- [x] После 202 запускается tracking, R04 возвращает canonical transcript с
  backend Speaker N независимо от summary. Маршрут и UI результата входят в .28,
  навигация по готовности входит в [TASK-FE-001.48](TASK-FE-001.48.md).
- [x] Оба режима используют существующие macOS/Linux mic/system WAV adapters.
  U02 не отправляет `workspace_id`, accepted job/session сохранены в журнале.
- [x] `failed`, `cancelled` и `expired` терминальны. Двойные Stop/Upload и смена
  режима во время активной операции блокируются. U02 авторизуется по JWT.
- [x] Активный сценарий отключён от legacy fragments/confirm/LabelSpeakersModal.
  Workspace, контакты, профили и имена из owner-only flow не создаются.
  Физическое удаление legacy-файлов входит в [TASK-FE-001.33](TASK-FE-001.33.md).
- [x] Результаты релевантных проверок и ограничения записаны в Verification.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Уточнение platform capture — 2026-11-03

Anonymous использует тот же platform capture: .15/.16 на macOS и .17 в обоих
режимах на Linux. Нет fallback на pinned record_linux file recorder. UI Pause
зависит от supportsPause выбранного adapter.

## Implementation notes

2026-11-09. Общий recorder .23 принимает оба режима. Workspace detail и его
регрессионный тест переходят на единственный guard, чтобы не удерживать
неиспользуемый legacy recorder. .24 переключает runtime с confirm/fragments на
U02 и общий job tracker. Файлы legacy API и прежнего диалога удаляются в .33,
а экран результата и маршрут подключаются в .28.

Backend SHA подтверждён по исходникам U02/U03 `audio-ingest-service` и R03/R04
`results-service`. Публикацию отдельного коммита в main после проверки ведёт
координатор по поручению пользователя от 2026-11-09. Приёмка фиксируется отдельно.

## Verification

2026-11-09. Cwd `/Users/verliiar/Desktop_application`, macOS, Flutter и Dart из
`.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`. Тесты
используют локальный журнал и синтетические ответы действующих API без сетевых запросов.

| Command / scenario | Expected | Actual / status / граница |
|---|---|---|
| `flutter test --no-pub --reporter expanded test/features/record/{ordinary_flow_test,anonymous_flow_test,v2_upload_api_test}.dart test/features/workspace/{workspace_record_start_test,profile_free_flow_test}.dart test/features/results/{processing_recovery_test,speech_status_api_test,canonical_api_test}.dart` | U02/U03/R03/R04, Stop, logout, WAV, workspace regression | PASS, 189 тестов, из них 8 новых для owner-only |
| `flutter analyze --no-pub lib/features/record/presentation/{record_notifier,record_screen,upload_modal}.dart lib/features/workspace/presentation/workspace_detail_screen.dart test/features/workspace/workspace_record_start_test.dart test/features/record/anonymous_flow_test.dart` | Нет issues в изменённых Dart-файлах | PASS, 6 файлов, 0 issues |
| `dart format --output=none --set-exit-if-changed` на этих 6 Dart-файлах, `git diff --check` на scope .24 | Формат и whitespace | PASS |
| `flutter test --no-pub --reporter expanded`, cwd `/tmp/dictai-task-publish-20261107/snapshot-24-candidate`, тот же SDK | Полный прогон на `ee6d064` с замороженным diff .24 | PASS, 544 теста; SHA-256 шести Dart-файлов совпали с review |
| `rg -n 'anonRecordNotifierProvider\|LabelSpeakersModal\|anonymousSessionApiProvider' lib test` | Ссылки только в отключённом legacy-коде и его lazy provider | PASS |
| Реальный захват mic/system и live gateway | macOS/Linux и развёрнутый backend | NOT RUN, проверки [macOS .36](TASK-FE-001.36.md), [Linux .37](TASK-FE-001.37.md) и [live .40](TASK-FE-001.40.md) |

## Result

RecordNotifier хранит режим вместе с параметрами захвата и использует общий
подтверждённый Stop, WAV journal и `BatchSession.submit`. RecordScreen и UploadModal
подключены к одному сценарию. WorkspaceDetailScreen проверяет общий guard. В
`workspace_record_start_test.dart` сохранены проверки блокировки для обоих режимов,
а `anonymous_flow_test.dart` покрывает U02, восстановимость при logout и результат
R04 с `Speaker 1`.

Реализация и scoped verification завершены. Независимый проход
[REVIEW-FE-001.24-01](../reviews/REVIEW-FE-001.24-01.md) завершён без замечаний,
74 теста reviewer прошли. Приёмка владельцем ожидается.
