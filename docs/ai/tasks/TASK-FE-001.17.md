---
id: TASK-FE-001.17
plan: PLAN-FE-001
title: "Сделать Linux system+microphone capture предсказуемым"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "2"
depends_on: ["TASK-FE-001.15"]
backend_tasks: ["TASK-002.08", "TASK-002.16"]
api_contracts: ["U01", "U02"]
blocked_by: []
scope:
  - "lib/features/record/data/linux_audio_capture.dart"
  - "test/features/record/linux_capture_test.dart"
  - "docs/development/LINUX_AUDIO.ru.md"
  - "docs/ai/tasks/TASK-FE-001.17.md"
planned_paths:
  - "lib/features/record/data/linux_audio_capture.dart"
  - "test/features/record/linux_capture_test.dart"
  - "docs/development/LINUX_AUDIO.ru.md"
delivery_stage: current
---

# TASK-FE-001.17: Сделать Linux system+microphone capture предсказуемым

## Goal

Общий Linux adapter с явными prerequisites, stop/join и RIFF validation.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Дублированные pactl/parec/ffmpeg вызовы; kill не ожидает финализации, ошибки микса тихо дают mic-only.

**Целевое:** Общий Linux adapter с явными prerequisites, stop/join и RIFF validation.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.15](TASK-FE-001.15.md).
Backend traceability: TASK-002.08, TASK-002.16
API: U01, U02.

## Requirements delta — 2026-10-26

[Окончательный UX](../research/FRONTEND_TARGET_UX.ru.md) и [backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md) уточняют планирование этой карточки. Исполнение после завершения текущего пересмотра и независимого review; будущие задачи не выбираются.

Общий UX — .49; native window interception не добавляется автоматически.

В .17 intent моделируется fake Process/capture seam, готовая .49 не требуется;
итоговый UI/process smoke — .37 после .49, без обратной зависимости на поздний UI.

## Этап и решение — 2026-11-02

Нужна: Linux capture/process lifecycle; отсутствие Linux host не заменять fake smoke.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Отмена Stop/leave dialog не завершает процессы capture; подтверждение приводит к одному terminate/join/finalized WAV, без фонового silent discard.
- [x] Проверяются exit codes/monitor source; stderr/stdout drained, terminate→wait имеет timeout и cleanup; файла не читают до finalization.
- [x] Недоступные pactl/parec/ffmpeg и failed mix дают понятную ошибку/явный выбор mic-only, а не скрытую потерю system audio.
- [x] Нет обязательной установки пакетов или shell interpolation; тесты используют fake Process seam, а живой PulseAudio/PipeWire smoke относится к .37.
- [x] Оба upload-режима получают одинаковый WAV; pause/dispose/error освобождают mic/process/temp.
- [x] Targeted checks и relevant format/analyze/platform evidence записаны; FAIL/SKIP/NOT RUN не выданы за PASS.
- [x] Независимый reviewer, не писавший implementation, проверил diff; findings и решение владельца зафиксированы.

## Уточнение platform capture — 2026-11-03

По findings F01/F02 .15 Linux adapter обслуживает mic-only и combined. Оба
режима используют контролируемый запуск, stop/join, finalization и cleanup.
Pinned record_linux file recorder не используется как fallback. Pause показывать
только если процессный adapter подтверждает безопасную pause/resume семантику.

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

2026-11-06. Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned
Flutter 3.41.3 / Dart 3.11.1, `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true FLUTTER_SUPPRESS_ANALYTICS=true`, `--no-pub`. Зависимости не менялись.

| Command / scenario | Actual | Status / limitation |
|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/record/linux_capture_test.dart --reporter expanded` | 19 tests, exit 0 | PASS, fake Process с реальными небольшими synthetic WAV |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/record/data/linux_audio_capture.dart test/features/record/linux_capture_test.dart` | No issues found после исправления двух braces diagnostics | PASS, scoped Dart |
| `.dart_tool/codex-tools/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed` по двум Dart paths | 2 files, 0 changed | PASS |
| Scope/links/new-file diff/whitespace | Проверены четыре пути карточки, новые файлы отдельно от tracked diff | PASS |
| Linux native build, pactl/parec/ffmpeg с реальными устройствами и длинной записью | Не запускалось на macOS | NOT RUN, реальный Linux smoke в .37 после .23/.24/.49 |
| Independent REVIEW-FE-001.17-01 | Передано отдельному reviewer | PASS, reviewed/complete, не приёмка пользователя |

Первая команда прошлого прохода не выполнилась из-за лимита automatic approval
review. После возобновления стандартная проверка разрешения прошла, тесты выполнены.
Изначальный parse error в новом test helper и два lint info исправлены до передачи.

## Result

Реализован общий Linux adapter для mic-only и combined, без pinned record_linux
file fallback. Pactl определяет выбранный микрофон и monitor текущего default sink.
Parec запускается аргументами без shell и пишет PCM16/16 kHz/mono. Все child pipes
читаются с момента запуска, command metadata ограничена 64 KiB. Stop ожидает exit
и завершение pipes, имеет deadline и SIGKILL fallback с явным failed outcome.

После финализации обоих входов ffmpeg пишет owned partial, общий .18 validator
проверяет входы и результат до публикации. Failed mix сохраняет исходники и удаляет
partial, successful mix удаляет только промежуточные входы. Dispose прерывает mixer,
ожидает capture и не отправляет данные. Пауза явно недоступна. Отмена Stop не меняет
запись, повторное подтверждение сериализовано и возвращает тот же готовый файл.

Изменены/созданы `linux_audio_capture.dart`, `linux_capture_test.dart`,
[LINUX_AUDIO.ru.md](../../development/LINUX_AUDIO.ru.md) и эта карточка.
Нет backend/API изменений, зависимости не добавлялись. Интеграция экранов остаётся
.23/.24, необходимый host smoke — .37. После ошибок исходники сохраняются до явной
интеграционной cleanup policy .23/.24/.34. Native несовместимость/качество на Linux
не объявлены проверенными. Independent review ожидается, accepted не присвоен.

Review .17-01 обнаружил P2 F01: auxiliary child мог теряться после неудачного join.
Исправлено автором с удержанием handles до завершения pipes и retryable cleanup.
Обе группы capture/auxiliary освобождаются даже при ошибке одной группы.
Добавлены две регрессии, теперь 19 tests PASS. Независимый delta ещё выполняется.

Независимый [REVIEW-FE-001.17-01](../reviews/REVIEW-FE-001.17-01.md) завершён 2026-11-06.
Открытых findings нет, приёмка пользователя не присваивается автоматически.
