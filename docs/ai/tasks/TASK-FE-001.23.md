---
id: TASK-FE-001.23
plan: PLAN-FE-001
title: "Перевести ordinary record/upload UX на V2"
status: review
owner: /root/ordinary_v2
priority: P1
readiness_category: B
phase: "2"
depends_on: ["TASK-FE-001.11", "TASK-FE-001.13", "TASK-FE-001.14", "TASK-FE-001.15", "TASK-FE-001.16", "TASK-FE-001.17", "TASK-FE-001.18", "TASK-FE-001.19", "TASK-FE-001.20", "TASK-FE-001.25"]
backend_tasks: ["TASK-002.16", "TASK-002.25", "TASK-002.37"]
api_contracts: ["U01", "R03"]
blocked_by: []
scope:
  - "lib/features/record/presentation/record_notifier.dart"
  - "lib/features/record/presentation/record_screen.dart"
  - "lib/features/record/presentation/upload_modal.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/record/ordinary_flow_test.dart"
  - "test/features/workspace/profile_free_flow_test.dart"
  - "test/features/workspace/workspace_record_start_test.dart"
  - "docs/ai/tasks/TASK-FE-001.23.md"
planned_paths:
  - "test/features/record/ordinary_flow_test.dart"
delivery_stage: current
---

# TASK-FE-001.23: Перевести ordinary record/upload UX на V2

## Goal

Workspace capture/file selection → preflight → один durable V2 upload → accepted job в общем processing flow.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Stop сразу загружает legacy WAV и показывает done по audio_id; экран допускает повторные действия во время upload.

**Целевое:** Workspace capture/file selection → preflight → один durable V2 upload → accepted job в общем processing flow.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.11](TASK-FE-001.11.md), [TASK-FE-001.13](TASK-FE-001.13.md), [TASK-FE-001.14](TASK-FE-001.14.md), [TASK-FE-001.15](TASK-FE-001.15.md), [TASK-FE-001.16](TASK-FE-001.16.md), [TASK-FE-001.17](TASK-FE-001.17.md), [TASK-FE-001.18](TASK-FE-001.18.md), [TASK-FE-001.19](TASK-FE-001.19.md), [TASK-FE-001.20](TASK-FE-001.20.md), [TASK-FE-001.25](TASK-FE-001.25.md).
Backend traceability: TASK-002.16, TASK-002.25, TASK-002.37
API: U01, R03.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Обычная запись использует одно подтверждение Stop. .49 объединит подтверждение для обоих режимов и добавит защиту при уходе с экрана. После 202 полноценный экран ожидания и результата подключит .28, уведомление о готовности подключит .48. Будущий редактор назначений подключает .50 после backend.

## Этап и решение — 2026-11-02

Нужна: ordinary WAV/V2 pipeline, без preview/editor/profiles.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] До Start доступны workspace/mic/system/language; активные параметры фиксированы. Вход из workspace сохраняет переданный контекст.
- [x] Явное подтверждение ordinary Stop запускает WAV finalize/validate → durable journal → один upload. Отмена сохраняет запись. .49 объединяет диалог для обоих режимов и защищает уход с экрана.
- [x] Сохранены record button, device selector, workspace selector, file picker и общий visual style; профили/непустые контакты не нужны.
- [x] Capture/pause/upload статусы блокируют конкурирующие start/mode/device/workspace changes; combined pause честно отключён, если adapter не поддерживает синхронность.
- [x] Options выбираются до Start (для picker — до upload); validation финального WAV перед upload; progress не выдаётся за ASR progress, 202 ведёт к job tracking без обещания готового результата.
- [x] Journal записан до запроса, accepted metadata сохранены и текущий job передан .25; abort локального запроса не объявляется server cancel.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Уточнение platform capture — 2026-11-03

Выбор capture по платформе: macOS mic-only через .15 и combined через .16.
На Linux и mic-only, и combined через .17. Переход на старый record_linux file
recorder при ошибке не допускается. Кнопка Pause следует supportsPause adapter.

## Implementation notes

Два workspace-регрессионных теста входят в scope для перехода со старых
MethodChannel и конструктора RecordNotifier на тестовые границы V2. Проверки
контекста workspace и отсутствия требования голосового профиля сохраняются.

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Backend и BACKEND_* snapshots только для сверки. После проверок и независимого review коммит и push в main выполняет координатор по поручению владельца от 2026-11-07.

## Verification

2026-11-09. Cwd `/Users/verliiar/Desktop_application`, macOS arm64, закреплённый
Flutter 3.41.3 и Dart 3.11.1 из `.dart_tool/codex-tools/flutter`.

| Проверка | Результат |
|---|---|
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter test --no-pub --reporter expanded test/features/record/ordinary_flow_test.dart test/features/workspace/profile_free_flow_test.dart test/features/workspace/workspace_record_start_test.dart` | PASS, 23 теста, включая 7 сценариев ordinary и workspace regressions |
| `PUB_CACHE=/Users/verliiar/.pub-cache .dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub` по семи Dart-файлам scope | PASS, замечаний анализатора нет |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed` по семи Dart-файлам scope | PASS, 0 changed |
| `git diff --check` по scope, сверка реальных U01 и R03 на backend SHA `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` | PASS |
| Полный `flutter test --no-pub --reporter expanded` из изолированной копии `88248be` с изменениями только .23 | PASS, 522 теста. Семь изменённых Dart-файлов совпадают с проверенной копией |
| Живой захват macOS/Linux и загрузка на тестовый gateway | NOT RUN. Платформенный smoke .36/.37 и сквозная проверка .40 отдельны |
| Независимый [REVIEW-FE-001.23-01](../reviews/REVIEW-FE-001.23-01.md) | PASS. F01/F02 исправлены, 23 независимых теста, открытых замечаний нет |

## Result

Обычная запись с workspace и импорт WAV используют готовые адаптеры и U01.
Язык, mixed, workspace, источник и ключ фиксируются до захвата или импорта.
Подтверждённый Stop ждёт незавершённую паузу, затем ровно один раз завершает
захват. Перед POST журнал проверяет скопированный WAV и сохраняет ключ и
параметры. При временном сбое кнопка повтора отправляет те же сохранённые данные.
Исходник импортированного файла остаётся у пользователя.

Общая сессия из `providers.dart` связывает журнал и tracker с владельцем.
Выход из аккаунта синхронно отменяет прежние сетевые запросы. Ответ 202
сохраняется в журнале и передаётся tracker, интерфейс показывает принятие в
обработку. Тесты подтвердили отсутствие второго POST при двойном Stop и
изоляцию позднего ответа при смене аккаунта.

Изменены RecordNotifier, RecordScreen, UploadModal, providers, добавлен
`ordinary_flow_test.dart`, адаптированы две workspace-фикстуры. Прежний
анонимный режим меняется в .24. Полный экран ожидания подключает .28, защиту
ухода добавляет .49. Платформенные smoke и live gateway остаются отдельными
проверками. Формальная приёмка ожидает владельца.
