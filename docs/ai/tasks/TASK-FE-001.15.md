---
id: TASK-FE-001.15
plan: PLAN-FE-001
title: "Выделить общий lifecycle микрофонной WAV-записи"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.04", "TASK-FE-001.06", "TASK-FE-001.07", "TASK-FE-001.18"]
backend_tasks: ["TASK-002.08", "TASK-002.16"]
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "lib/features/record/data/audio_capture.dart"
  - "lib/features/record/data/microphone_capture.dart"
  - "test/features/record/microphone_capture_test.dart"
  - "docs/ai/tasks/TASK-FE-001.15.md"
planned_paths:
  - "lib/features/record/data/audio_capture.dart"
  - "lib/features/record/data/microphone_capture.dart"
  - "test/features/record/microphone_capture_test.dart"
delivery_stage: current
---

# TASK-FE-001.15: Выделить общий lifecycle микрофонной WAV-записи

## Goal

Небольшой общий capture interface и mic adapter, используемые обоими режимами после .23/.24.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Обычный notifier пишет WAV 16 kHz mono, anonymous — opus/aac; recorder создаётся внутри notifier без injectable seam.

**Целевое:** Небольшой общий capture interface и mic adapter, используемые обоими режимами после .23/.24.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.04](TASK-FE-001.04.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md), [TASK-FE-001.18](TASK-FE-001.18.md).
Backend traceability: TASK-002.08, TASK-002.16
API: U01, U02.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Adapter не рисует диалог; .49 владеет общей Stop/leave policy двух режимов. Ошибка finalization сохраняет доступный исходник и не объявляет upload успешным.

Здесь seam проверяется синтетическими confirmed/cancel intent без готовой .49;
её поздняя реализация не prerequisite приёмки adapter. Интегрированный dialog/capture
smoke относится к .49/.36/.37, а не создаёт обратную зависимость .15 от UI.

## Этап и решение — 2026-11-02

Нужна: реальный WAV capture/lifecycle; узкий hardware seam оправдан тестированием.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Capture завершается только по явному подтверждённому finish intent от .49; отмена диалога не вызывает stop/dispose и сохраняет предыдущее recording/paused состояние.
- [ ] Оба режима могут получить finalized PCM RIFF WAV без перекодирования из M4A/OGG; формат проверяется по bytes, не суффиксу.
- [x] Permission/device/empty file/start/stop/exception/dispose обрабатываются без zombie recorder; captured file остаётся до однозначного upload outcome.
- [ ] Mic pause/resume имеет проверенную семантику; combined pause не обещается, пока все источники не синхронизированы.
- [x] Ports узкие и находятся в существующем feature/data, без общего нового domain/repository framework.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Уточнение реализации — 2026-11-03

Добавлена явная .15→.18 для переиспользования уже проверенного bounded WAV
validator при finalization: не дублировать RIFF/PCM parser и не считать суффикс
доказательством формата. .18 не зависит от capture, цикла нет. UI wiring
по-прежнему только .23/.24, native capture smoke — .36/.37.

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

2026-11-03, cwd `/Users/verliiar/Desktop_application`, macOS arm64,
`.dart_tool/codex-tools/flutter` Flutter 3.41.3/Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Команда / сценарий | Actual | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/record/microphone_capture_test.dart` | 15 tests passed | PASS: confirmed/cancelled Stop, double calls, PCM bytes, permission/device/encoder/start/stop/pause/resume/dispose failures и async disposal |
| `dart analyze lib/features/record/data/audio_capture.dart lib/features/record/data/microphone_capture.dart test/features/record/microphone_capture_test.dart` | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed` для тех же трёх файлов | Последний format: 3 files, 0 changed | PASS |
| Native mic/пауза/реальная длительная запись | Не запускались | NOT RUN, OS smoke итоговых adapters в .36/.37, fake recorder не аппаратное evidence |
| Оба режима записи используют новый adapter | Wiring ещё не выполнен | NOT RUN, следующие .23/.24; общий file-based API предоставлен |
| Global analyze | Последний общий run: 13 прежних info prefer_const_constructors вне .15 | FAIL baseline, scoped analyze чист |
| Независимый review .15-01 | Передан отдельному reviewer | Pending |

Изучены текущие ordinary/anonymous notifiers, record5.2.1 API/методы stop/pause/
resume/dispose и RecordConfig; pinned dependency не менялась. Byte проверки после
stop выполняет общий reviewed .18 WavValidator, не дублированный header parser.
Тесты подменяют только AudioRecorder и temp directory, пишут настоящие маленькие
PCM RIFF файлы. Реальный plugin остаётся default production adapter.

## Result

Добавлены AudioCapture/CaptureStatus и MicrophoneCapture: lazy recorder factory,
явный mic/WAV16k mono, выбранное устройство без fallback, последовательные команды,
Pause/Resume, cancelled finish без side effects, confirmed finish с одним stop и
строгой PCM/WAV проверкой. Повторный finish возвращает тот же файл. Сырые device/
OS errors не показываются. Dispose во время permission wait не запускает позднюю
запись; forced lifecycle cleanup не инициирует upload и не удаляет исходники.

При ошибке finalization доступный sourcePath/файл сохраняется. Неподтверждённый
release выдаёт явный отказ и сохраняет handle для cleanup retry, не создаёт второй
recorder. Новый capture очищает ссылку прошлого source, сами файлы не стирает.
Production notifiers/UI пока прежние: переключение в .23/.24, Stop dialog в .49;
combined adapters в .16/.17. Поэтому cross-task интеграционные критерии выше ещё
не отмечены выполненными. Test seam не доказывает native mic capture или Linux.

Изменены только два новых data-файла, новый тест и эта карточка. Status review,
не accepted; pending independent review .15-01. Commit/push/merge не выполнялись.


## Исправления по независимому review — 2026-11-03

[REVIEW-FE-001.15-01](../reviews/REVIEW-FE-001.15-01.md) обнаружил проблемы
завершения записи в pinned Linux и macOS drivers. Для Linux .17 отвечает за
mic-only и combined capture, включая управляемое завершение дочерних процессов.
В .15 используется поддерживаемая macOS конфигурация record plugin с прямым
публичным `RecordPlatform` API. Таймаут Stop и отдельная native команда dispose
позволяют освободить recorder при пропущенном callback. Повторный review .15-02
зарезервирован до исправления.


Повторная проверка автора: 18 tests PASS, включая Linux guard, native already-ended
recording и потерянный Stop callback. Platform dispose независимо освобождает
record id, подтверждённый WAV сохраняется. Разрешение пользователя на микрофон
ожидается отдельно от timeout обычной native команды. Dispose может отменить
ожидание permission и не начинает запись после выхода. macOS file recorder
сохраняет PCM WAV16k mono и Pause/Resume. Linux выбирает .17 и не вызывает этот
adapter. Аппаратный smoke остаётся .36/.37. F04 table/card/DAG синхронизированы.
Независимый [delta review .15-02](../reviews/REVIEW-FE-001.15-02.md) завершён. 19 tests, scoped analyze/format и whitespace PASS. Открытых замечаний нет. Native ID постоянен на экземпляр adapter, подтверждённый dispose позволяет повторно использовать channel registrations.
