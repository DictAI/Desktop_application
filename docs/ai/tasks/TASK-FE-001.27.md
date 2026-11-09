---
id: TASK-FE-001.27
plan: PLAN-FE-001
title: "Адаптировать библиотеку результатов и фильтры"
status: review
owner: /root/results_library
priority: P1
readiness_category: B
phase: "3"
depends_on: ["TASK-FE-001.23", "TASK-FE-001.25", "TASK-FE-001.26"]
backend_tasks: ["TASK-002.15", "TASK-002.20"]
api_contracts: ["R01", "R03"]
blocked_by: []
scope:
  - "lib/features/record/data/pending_upload_store.dart"
  - "lib/features/results/presentation/results_notifier.dart"
  - "lib/features/results/presentation/results_screen.dart"
  - "test/features/results/results_library_test.dart"
  - "docs/ai/tasks/TASK-FE-001.27.md"
planned_paths:
  - "test/features/results/results_library_test.dart"
delivery_stage: current
---

# TASK-FE-001.27: Адаптировать библиотеку результатов и фильтры

## Goal

Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Экран показывает карточки и PDF buttons по isDone; polling загружает первую страницу без текущих фильтров.

**Целевое:** Latest V2 library с устойчивыми filters/page, refresh, empty/failure и переходом к записи.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.23](TASK-FE-001.23.md) для общей сессии и журнала,
[TASK-FE-001.25](TASK-FE-001.25.md), [TASK-FE-001.26](TASK-FE-001.26.md).
Backend traceability: TASK-002.15, TASK-002.20
API: R01, R03.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: библиотека/пагинация/незавершённые отправки; нет Назначить участников.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Results различает server accepted jobs и local pending uploads до 202; восстановление через .20 показывает реальную причину/доступное действие.
- [x] Open передаёт точные audio ID и job ID в callback. Production-маршрут
  подключается в .28. После restart доступны реальные результаты и сохранённые
  отправки. Нет назначения, переименования или сохранения Speaker.
- [x] Сохранены карточки/date filters и server pagination; обновление не сбрасывает page/filter и не повторяет load бесконечно.
- [x] List pending/done/failed не определяет summary/download availability; anonymous без фиктивного workspace.
- [x] Library строится на R01/known IDs, без meetings detail/workspace meetings новых endpoints, заглушек вместо доступного delete или mock data production.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Scope .20 journal расширен узко для .27: публичная классификация известных
локальных ошибок replay отличает постоянный отказ от временного busy. Формат
журнала, wire, синхронизация файлов и поведение отправки не меняются.

Scope/planned_paths в frontmatter — точные разрешаемые пути будущей реализации,
включая эту карточку. Пока отсутствующие пути явно planned; некоторые создаются
зависимостью раньше. Удалённый prerequisite retired файл не воссоздавать.
Общие файлы — один writer; порядок DAG и координация PLAN-FE-001 обязательны.
Owner назначается при выборе задачи, не агентом задним числом после изменений.

Сохранять Riverpod/GoRouter/Dio и ручные DTO. Не добавлять неуказанные endpoints,
новые dependencies/permissions/deployment behavior либо «попутные» исправления.
Если проверки обнаружат проблему вне scope, сохранить evidence и предложить отдельное решение владельцу.
Backend и BACKEND_* snapshots используются для сверки. Коммит и push в main
выполняет координатор после проверки и независимого review.

## Verification

Cwd `/Users/verliiar/Desktop_application`, 2026-11-09, macOS arm64,
pinned SDK `.dart_tool/codex-tools/flutter` (Flutter 3.41.3 / Dart 3.11.1),
`PUB_CACHE=/Users/verliiar/.pub-cache`. Транспорт подменён в тестах,
журнал читает и пишет временные локальные WAV и receipts.

| Проверка | Результат |
|---|---|
| `flutter test --no-pub test/features/results test/features/record/pending_upload_store_test.dart --reporter expanded` | PASS, 202 теста, включая 14 .27. Проверены R01 page/date/retry, поздний ответ, повторный вход, явный replay тех же bytes/key, отсутствие WAV, временный busy, quota cleanup, restart R03 после prune, сохранение U03 receipt и fallback при ошибке журнала, logout и R02. Тест fixture-маршрута проверяет Open с точным job ID при 503 статуса. |
| `flutter analyze --no-pub` по четырём Dart-файлам scope | PASS, No issues found. |
| `dart format --output=none --set-exit-if-changed` по тем же Dart-файлам | PASS, 4 files, 0 changed. |
| `git diff --check` по tracked scope и no-index check нового теста | PASS, whitespace diagnostics отсутствуют. |
| Сверка R01/R02/R03 с backend `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` | PASS, реальный owner-only latest job, inclusive date bounds, пагинация, идентичность audio/job и tombstone. |
| Первый запуск Flutter test в стандартном sandbox | NOT RUN, локальный сокет тестового runner недоступен. Повтор с разрешённым сокетом прошёл. |
| Живой gateway, platform smoke | NOT RUN. Проверяются в .36/.37/.40. |
| Полный `flutter test --no-pub --reporter expanded` из снимка `c66017f` с изменениями только .27 | PASS, 536 тестов. Проверены четыре изменённых Dart-файла в составе этого снимка. |
| Независимый [REVIEW-FE-001.27-01](../reviews/REVIEW-FE-001.27-01.md) | PASS, 202 независимых теста. F01–F03 исправлены, открытых замечаний нет. |

## Result

Results получает R01 с выбранным периодом и страницей. Ручное обновление, retry
и повторный вход сохраняют этот выбор. Устаревший ответ не перезаписывает новый
фильтр, а завершение сессии отменяет запросы. При исчезновении текущей страницы
выполняется один запрос к последней доступной. R02 сохраняет существующее удаление
и скрывает возвращённую поздним ответом запись после 204.

Журнал читается отдельно от R01. Неподтверждённая отправка повторяется явно
с сохранёнными bytes/options/key. Утрата или изменение WAV прекращают повторы,
временный busy допускает явный повтор, 409 отображается как конфликт. После
сохранённого 202 восстанавливается только проверка статуса job. Accepted receipt
освобождает место при точном совпадении owner/audio/job с R01. Pending/conflict
сохраняются. Для anonymous pending/unknown receipt хранит U03 session ID,
которого нет в R01. После удаления receipt или ошибки чтения журнала tracker
получает серверный pending job по точным идентификаторам R01.

Результаты без workspace показывают фактический контекст. Статус списка не
используется как признак наличия summary или файлов экспорта. Экран передаёт
audio/job IDs через типизированный Open callback, доступный при временной ошибке
статуса. Рабочий маршрут появится в .28.
Подключение detail/export и финальная очистка owned файлов относятся к .28/.31/.32.

Файлы: `pending_upload_store.dart`, `results_notifier.dart`, `results_screen.dart`,
`test/features/results/results_library_test.dart` и эта карточка. Проверки
реального стенда и ручная приёмка остаются отдельными этапами.
