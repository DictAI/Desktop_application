---
id: TASK-FE-001.23
plan: PLAN-FE-001
title: "Перевести ordinary record/upload UX на V2"
status: draft
owner: unassigned
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

Здесь реализуется V2 pipeline и точки requestStop/confirmedFinish, без второго собственного диалога. .49 объединит финальное поведение Stop и ухода. После 202 открытие waiting/detail подключает .28; current readiness/transcript notice — .48. Назначения не входят в текущий этап, future editor routing подключит .50 после backend.

## Этап и решение — 2026-11-02

Нужна: ordinary WAV/V2 pipeline, без preview/editor/profiles.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] До Start доступны workspace/mic/system/language; активные параметры фиксированы. Вход из workspace сохраняет переданный контекст.
- [ ] V2 finish pipeline принимает явный confirmed intent: WAV finalize/validate → durable journal → один upload. Диалог/route guard реализует .49; preview отсутствует. До .49 итоговый record UX не объявляется готовым.
- [ ] Сохранены record button, device selector, workspace selector, file picker и общий visual style; профили/непустые контакты не нужны.
- [ ] Capture/pause/upload статусы блокируют конкурирующие start/mode/device/workspace changes; combined pause честно отключён, если adapter не поддерживает синхронность.
- [ ] Options выбираются до Start (для picker — до upload); validation финального WAV перед upload; progress не выдаётся за ASR progress, 202 ведёт к job tracking без обещания готового результата.
- [ ] Journal записан до запроса, accepted metadata сохранены и текущий job передан .25; abort локального запроса не объявляется server cancel.
- [ ] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [ ] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Уточнение platform capture — 2026-11-03

Выбор capture по платформе: macOS mic-only через .15 и combined через .16.
На Linux и mic-only, и combined через .17. Переход на старый record_linux file
recorder при ошибке не допускается. Кнопка Pause следует supportsPause adapter.

## Implementation notes

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Не изменять backend или BACKEND_* snapshots. Нет commit/push/merge/release разрешения.

## Verification

Cwd — корень frontend. Ниже план, а не выполненные проверки. Нужные tests/docs
могут пока отсутствовать: они указаны в planned_paths. После реализации записать
точную среду/команды/actual outcome, включая skips и внешние ограничения.

| Command / scenario | Environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `flutter test test/features/record/ordinary_flow_test.dart` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| `flutter analyze` | Совместимый SDK после .01, fake dependencies если не выбран real smoke | Acceptance criteria подтверждены, ошибки не скрыты | Не запускалось | NOT RUN | Сейчас только planning; prerequisites/среда не подтверждены |
| Ordinary flow: preselected options, confirmed intent, invalid WAV, double-send и accepted waiting state | Frontend; SDK после .01, deterministic fakes / явно указанный host | Уточнённые UX criteria и реальные границы подтверждены | Не запускалось | NOT RUN | Только planning; mock не доказывает server persistence/export |
| Полный diff, scope, формат изменённых существующих Dart-файлов и независимый review | Frontend / нужная платформа | Нет посторонних изменений/секретов/retired API | Не запускалось | NOT RUN | Удалённые файлы в format не передавать; platform checks не заменять mocks |

## Result

Не реализовано. Код, API-клиенты, DTO и dependencies этим planning-проходом
не менялись. Реальные результаты добавит выбранный implementer после исполнения.
Review плана не является review кода или PASS будущих tests.
Основание приёмки отсутствует: implemented ≠ verified ≠ accepted.
Только пользователь принимает scope/ограничения; публикация отдельно.
