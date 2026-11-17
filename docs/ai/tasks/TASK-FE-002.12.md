---
id: "TASK-FE-002.12"
plan: "PLAN-FE-002"
title: "Показать большой транскрипт с говорящими и таймкодами"
status: "review"
owner: "/root/detail_prep"
priority: "P1"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.11"]
scope: ["lib/features/results/presentation/transcript_view.dart", "lib/features/results/presentation/result_detail_screen.dart", "test/features/results/ios_transcript_test.dart", "docs/ai/tasks/TASK-FE-002.12.md"]
planned_paths: ["lib/features/results/presentation/transcript_view.dart", "test/features/results/ios_transcript_test.dart"]
reuses_tasks: ["TASK-FE-001.29"]
implementation_selected: true
---

# TASK-FE-002.12: Показать большой транскрипт с говорящими и таймкодами

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Показать большой транскрипт с говорящими и таймкодами. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.29](../tasks/TASK-FE-001.29.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Показаны исходные backend Speaker ID/labels, UNKNOWN, порядок, overlap и timings из integer microseconds; имена не выдумываются.
- [ ] Lazy UI и ограниченное потребление памяти выдерживают canonical до существующего artifact limit 50 MiB; масштабирование текста, scroll/selection и VoiceOver остаются пригодны на iPhone.
- [x] No_speech — успешное пустое состояние; отсутствие/некорректный timing не подменяется нулём или выдуманным временем.
- [x] Нет rename/contact assignment/canonical merge/split или зависимости от будущего names API.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Сохранить DTO и пределы API; fixture stress не доказывает качество модели или работу backend.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification реализации — 2026-11-17

Cwd `/Users/mxdnght/dictai-app`; macOS arm64; pinned Flutter 3.41.3 / Dart 3.11.1
по `/tmp/dictai-flutter-3.41.3`, зависимости подготовлены, без pub/lock/SDK updates.
Baseline этапа `/var/folders/nk/dn15wj451d90zxf_gxkbdgjr0000gn/T/dictai-max-stage-12-xgw0n5k9/`.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `/tmp/dictai-flutter-3.41.3/bin/flutter test --no-pub test/features/results/ios_transcript_test.dart test/features/results/ios_result_detail_test.dart test/features/results/canonical_api_test.dart --reporter expanded` | 103/103 PASS; 11 новых viewer tests, existing detail/canonical regression, лог `/tmp/dictai-transcript-12-targeted.log` | PASS | Host fixtures/widgets, не модель/backend/device |
| Exact 50 MiB canonical single-segment stress | 52,428,800 UTF-8 JSON bytes реально сериализованы/декодированы существующим DTO; после layout <10 SelectableText, каждый ≤4097 UTF-16 units, всего <40960 visible units | PASS в финальном полном прогоне | Проверка UI bound, не peak RAM/FPS на iPhone; исходный JSON/DTO по-прежнему полностью декодируется API |
| 10000 segments, jump/scroll to end | Начальная/конечная реплика доступны, mounted SelectableText <20 на обоих концах | PASS в финальном полном прогоне | Дальний jump в host debug занимает около 22–27s, не benchmark релизного устройства; обычный scroll lazy |
| Metadata/Unicode/selection | Raw Speaker IDs и labels/UNKNOWN, nested overlaps A0–10/B1–2/C3–4, точный maxTimeUs, суррогатная пара на границе, исходный clipboard text, no_speech и invalid timing rejection | PASS в финальном combined прогоне | Selection/copy у отдельной реплики/части длинной реплики, full-document copy-all не добавлен |
| `/tmp/dictai-flutter-3.41.3/bin/flutter analyze --no-pub --no-fatal-infos` | exit0, 7 прежних info в legacy files, без новых diagnostics | PASS | Полный Dart анализ |
| `/tmp/dictai-flutter-3.41.3/bin/dart format --output=none --set-exit-if-changed lib/features/results/presentation/transcript_view.dart lib/features/results/presentation/result_detail_screen.dart test/features/results/ios_transcript_test.dart`; `git diff --check` | 3 файла, 0 format changes; whitespace diagnostics нет | PASS | Только три .12 Dart файла/текущий diff |
| iPhone large canonical memory/scroll, VoiceOver, реальный backend transcript | Не выполнялось implementer | NOT RUN | Physical acceptance/peak RAM/FPS не заявлены; Simulator build выполняет root |

Initial test drafts FAIL относились к fixture SemanticsHandle lifetime и
неоднозначному Scrollable finder (SelectableText имеет свой scrollable);
исправлены закрытием handle до Flutter invariants и выбором outer scrollable.
Production renderer по этим failures не менялся. Независимый
[REVIEW-FE-002.12-01](../reviews/REVIEW-FE-002.12-01.md) выполняет acceptance_review;
его финальные completion/findings фиксируются в отчёте.

## Result реализации — 2026-11-17

Созданы `transcript_view.dart` и `ios_transcript_test.dart`; detail screen
использует новый sliver; обновлена эта карточка. Providers/notifier/API/DTO,
backend, native, dependencies и прежние tests не менялись. Из planned_paths
удалён уже созданный в .11 detail screen, его write scope сохранён.

Viewer сохраняет исходный порядок, Speaker ID/labels, UNKNOWN и integer-us
диапазоны с шестью знаками микросекунд. Перекрытие считается по maximum end
всех предыдущих реплик, включая вложенные; текст не сортируется/не сливается.
No_speech показывает успешное пустое состояние; DTO validation отказывает
invalid/missing timings, нулевые времена/имена не выдумываются.

Lazy sliver создаёт только нужный viewport layout. Длинная одиночная реплика
представлена частями до 4096(+1 для полной пары) UTF-16 units без полного
копирования текста в UI index; соседние границы сохраняют каждую code point,
metadata continuation использует исходный interval без вычисления новых timings.
Lookup labels, prefix row counts и overlap flags вычисляются один раз при
смене immutable DTO, бинарный поиск связывает lazy row с исходной репликой.
Text selection копирует исходный текст без metadata, controls редактирования
говорящих/контактов отсутствуют.

Host scale2 проверен на 320×568 и 430×320 landscape; metadata переносится,
semantics содержит исходную identity/time/overlap. Physical VoiceOver/память
и качество реального transcript остаются NOT RUN; большой артефакт в host
не объявляется доказательством аппаратной готовности. Status implemented,
независимый review впереди; accepted/commit/push/release не назначены.

## Историческая Verification планирования

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter test test/features/results/ios_transcript_test.dart; scoped format; flutter analyze | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| iPhone: synthetic large canonical memory/scroll, text scale/VoiceOver; реальный transcript проверяется в .18 | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Исторический Result планирования

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.


## Coordinator handoff — 2026-11-17

Source/tests/card автора frozen; status review, coordinator принимает только
учётную delta. Последняя полная интеграция до viewer:704 host tests и main
Simulator build12.8s PASS (.11), не выдана за новый прогон .12. Для нового
Dart viewer выполнены103 targeted/regression tests/format3/analyze PASS
(7 прежних info); independent rerun/report выполняет отдельный reviewer.
Новая native build .12 NOT RUN: платформенный код не менялся, следующий
общий Simulator build входит в native .13. Physical50MiB scroll/peakRAM/
VoiceOver NOT RUN. Hostdebug farjump22–27s не является phone performance PASS.
