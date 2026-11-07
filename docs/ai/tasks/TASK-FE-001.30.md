---
id: TASK-FE-001.30
plan: PLAN-FE-001
title: "Добавить авторизованный document/original download client"
status: review
owner: primary-agent
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.05", "TASK-FE-001.06", "TASK-FE-001.07", "TASK-FE-001.18"]
backend_tasks: ["TASK-002.14", "TASK-002.15", "TASK-002.16", "TASK-002.37"]
api_contracts: ["R05", "U04"]
blocked_by: []
scope:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/dto/document_kind.dart"
  - "test/features/results/documents_api_test.dart"
  - "docs/ai/tasks/TASK-FE-001.30.md"
planned_paths:
  - "lib/features/results/data/documents_api.dart"
  - "lib/features/results/data/dto/document_kind.dart"
  - "test/features/results/documents_api_test.dart"
delivery_stage: current
---

# TASK-FE-001.30: Добавить авторизованный document/original download client

## Goal

Четыре document kinds и original WAV с JWT и безопасным streaming-to-temp API.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** ResultsApi использует удалённые summary/transcript/audio paths и скачивает весь файл в List<int>.

**Целевое:** Четыре document kinds и original WAV с JWT и безопасным streaming-to-temp API.

**Категория A, P1.** Backend-контракт/локальный scope достаточен; FE prerequisites и подходящее окружение всё равно нужны.
FE prerequisites: [TASK-FE-001.05](TASK-FE-001.05.md), [TASK-FE-001.06](TASK-FE-001.06.md), [TASK-FE-001.07](TASK-FE-001.07.md), [TASK-FE-001.18](TASK-FE-001.18.md).
Backend traceability: TASK-002.14, TASK-002.15, TASK-002.16, TASK-002.37
API: R05, U04.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: авторизованные реальные документы/original; нет локальной замены имён.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [x] Авторизованный original предоставляется как полностью проверенный owned file для player .44; partial WAV не success, Range не предполагается. Подключение настоящего player проверяется в .44, не объявляется выполненным в .30.
- [x] Четыре существующих server documents скачиваются байт-в-байт с текущими Speaker N; нет string replace/named-export обещания.
- [x] Только documents/{transcript.txt,transcript.pdf,summary.txt,summary.pdf} и действующий original U04; optional pinned job_id сохраняется для документов.
- [x] Bytes не JSON; document404/artifact503/text error не сохраняются как PDF. Original до 1 GiB идёт потоком, partial не success.
- [x] Origin policy до JWT, никаких direct MinIO/public signed URLs/grant discovery/private API.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Уточнение зависимости — 2026-11-03

.30 переиспользует bounded WAV validator из .18 для final original verification,
поэтому добавлена явная зависимость .30→.18 вместо дублирования RIFF parser.
Проверка настоящего player wiring принадлежит последующей .44; AC уточнён,
чтобы .30 не требовала результата своего downstream. Нового API/scope нет.

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

Все команды из `/Users/verliiar/Desktop_application`, macOS 26.2, Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`; `PUB_CACHE=/Users/verliiar/.pub-cache`,
готовые dependencies, `--no-pub`. Tests/analyze имеют доступ к локальному кэшу и
тестовому порту. .18 validator к моменту final checks имеет завершённый независимый
review, явная dependency .30→.18 добавлена coordinator.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/results/documents_api_test.dart` | 30 tests passed: четыре byte-exact R05, U04 без Content-Length, generated 8 MiB stream, own-file isolation, RIFF/limits/MIME/EOF, cancel/error/cleanup, bounded error markers, first-chunk idle timeouts и общий JWT/origin | PASS | Deterministic existing HTTP fakes; не 1 GiB/native playback/live gateway |
| `.dart_tool/codex-tools/flutter/bin/flutter analyze --no-pub lib/features/results/data/documents_api.dart lib/features/results/data/dto/document_kind.dart test/features/results/documents_api_test.dart` | No issues found | PASS | Targeted analysis, не полный repo baseline |
| `.dart_tool/codex-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib/features/results/data/documents_api.dart lib/features/results/data/dto/document_kind.dart test/features/results/documents_api_test.dart` | 3 files, 0 changes | PASS | Только scope |
| Ранние test/analyze runs тех же файлов | Первая test-версия ошибочно использовала уже закрытый fake adapter в JWT test; после исправления 27/27 PASS, затем добавлен 28-й RIFF limit case. Curly-braces infos в новых if устранены; final analyze PASS | FAIL → PASS | Не скрывает исходные неуспешные проходы |
| Backend source review U04/R05 handlers/tests; Dio 5.9.2 response_stream_handler.dart и native download implementation | Current backend SHA совпадает `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; U04 chunked/late error и R05 types/markers подтверждены, Dio не передаёт pause upstream | PASS source review | Source review не runtime test; backend/pub-cache не менялись |
| Scoped full diff/new-file read/whitespace (`git diff --no-index --check /dev/null <path>`) | Новые три файла и карточка проверены, whitespace diagnostics нет | PASS | Посторонние изменения сохранены |
| Независимый review | Передан `/root/review_workspace_contracts`, зарезервирован REVIEW-FE-001.30-01 | NOT RUN | Reviewer ещё не завершил проход |
| Player .44 wiring, native responsiveness/memory at 1 GiB, real TLS/JWT/storage stream, macOS/Linux smoke | Не запускались | NOT RUN | Предоставлен файл API; player и реальные host checks в .44/.36/.37/.40 |

## Result

Добавлены `documents_api.dart`, `dto/document_kind.dart`,
`test/features/results/documents_api_test.dart`; обновлена только эта карточка.
Действующие R05 kinds и U04 используют injected общий Dio, фиксированные gateway
paths и exact optional job_id только для документов. Origin policy/AuthInterceptor
не обходятся; redirects/Range/public URLs/grant API не добавлены.

Каждая операция создаёт отдельный owned subdirectory, пишет response bytes в .part
и выдаёт DownloadedFile только после 200, MIME, EOF, необязательного Content-Length
и format checks. Original проверяется по RIFF/WAVE prefix/declared count с ранним
пределом 1 GiB, затем переиспользует полный bounded WavValidator из .18. Chunked
response без Content-Length допустим; clean EOF раньше RIFF size и stream abort
не успех. PDF проверяется по content type и %PDF- prefix, TXT не преобразуется.
Server bytes/labels не заменяются и не рендерятся локально. Caller владеет complete
file и вызывает delete после player/export/session cleanup. Ошибка/отмена удаляет
только собственный partial directory; другой download и пользовательский source
сохраняются. Ошибки локального удаления явно возвращаются безопасным сообщением.

HTTP error ResponseBody читается максимум до 16 KiB для common mapper: различимы
R05 document404 unavailable/not-found, U04 missing/expired/access и 503, raw bodies
не попадают в UI или PDF/WAV. Internal cancellation завершает текущий transfer и
не отменяет другие запросы с caller token. Configured receiveTimeout применяется к простою с первого body chunk ожидания, включая stalled error body, а не ко всей длительности длинного download. Нет retries или автоматических downloads.

Dio 5.9.2 не передаёт pause своего response controller upstream. По согласованию с
coordinator каждый входящий chunk записывается синхронными порциями до 64 KiB,
без async disk gap и накопления полного body в приложении; prefix занимает ≤12 B.
Это осознанный tradeoff: медленный диск временно блокирует event loop на запись
порции/flush. Test с generated 8 MiB проверяет функциональный streaming, но не
доказывает latency/RAM на настоящем 1 GiB/native host. TXT/PDF без Content-Length
не имеют application checksum; graceful complete HTTP EOF — граница действующего
контракта. Реальное подключение player .44, UI responsiveness и platform memory
проверяются последующими задачами, здесь не объявлены выполненными.

30 tests/targeted analyze/format PASS. Независимый review ожидается, status review,
accepted не выставлен. Providers/router/results API/UI/dependencies/platform/backend
не менялись; commit/push/merge не выполнялись.


## Исправления по независимому review — 2026-11-04

Реализация .30 сохранена. Primary-agent принимает запись exact scope для двух
узких исправлений по review. На 401 и остальных HTTP errors Dio не подписывается
на тело, пока ожидает обработку сессии. Только R05 404 требуется для bounded
распознавания `document unavailable`. Значения `.` и `..` отвергаются как audio_id
до сборки URL. Повторные 32 tests, scoped analyze, format (3 files, 0 changed) и whitespace PASS. Reviewer независимо повторил проверки и подтвердил оба исправления, [REVIEW-FE-001.30-01](../reviews/REVIEW-FE-001.30-01.md) reviewed/complete, открытых замечаний нет.
