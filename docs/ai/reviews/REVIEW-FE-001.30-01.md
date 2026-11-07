---
id: REVIEW-FE-001.30-01
task_ids: ["TASK-FE-001.30"]
reviewer: /root/review_platform_clients
mode: read-only
status: reviewed
completion: complete
reviewed_at: 2026-11-04
---

# REVIEW-FE-001.30-01

## Scope

Независимая проверка [TASK-FE-001.30](../tasks/TASK-FE-001.30.md) и исправлений
после review. База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`,
backend `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. Новый Dart scope прочитан
целиком. Первоначальную реализацию написал `/root/results_contracts`,
исправления findings внёс `primary-agent` после передачи scope.

| Файл | SHA-256 итоговой проверенной версии |
|---|---|
| `lib/features/results/data/documents_api.dart` | `80ed486ca7f83623b1803be35237e6ecf7721d8a1deddc7c3e12a00026e2be34` |
| `lib/features/results/data/dto/document_kind.dart` | `6edca00a88fa4acfd4ff11f50c991758cf82bd42d4f6d17a4fd636aea3388d2e` |
| `test/features/results/documents_api_test.dart` | `3ab5cd7dc5e07a337225f8828c65c17d835b6203286da06f87699a72a9bc6d0c` |

Сверены [контракты R05 и U04](../research/BACKEND_API_CONTRACTS.ru.md), их
backend handlers, owner/revocation checks, общий Dio origin policy/AuthInterceptor,
pinned Dio 5.9.2 и использование bounded WAV validation .18. В backend U04
возвращает исходный WAV и обрывает передачу при поздней ошибке. R05 допускает
четыре точных kind и optional job_id, отличает отсутствие записи от отсутствия
документа и не выдаёт storage URL. У клиента эти границы сохранены.

## Findings

### F01 P2. Тело 401 буферизовалось до bounded reader

`lib/features/results/data/documents_api.dart:99–120,237–251`.

**Impact.** При задержке secure storage во время AuthInterceptor.onError
крупный ошибочный response мог целиком накопиться во внутреннем Dio controller
до запуска reader .30. Лимит чтения 16 KiB не ограничивал эту очередь.

**Evidence.** Pinned Dio `dio_mixin.dart:558–586` при default
`receiveDataWhenStatusError:true` создаёт `handleResponseStream` до запуска
error interceptors. `response_stream_handler.dart:23–25,70–101` сразу
подписывается на source и не передаёт pause upstream. Независимый синтетический
probe на pinned Dart/Dio удерживал async onError перед consumer. При `true`
Dio запросил 64 chunks, 8 MiB. При `false` подписки на тело не было, статус 401
сохранился. Probe находится в `/tmp/dictai-platform-review-20261104/dio_error_buffer.dart`.

**Recommendation.** Оставить общий auth pipeline, отключить тело обычных
ошибочных responses, прочитать маркер R05 404 отдельно в пределах лимита.

**Disposition.** Fixed with evidence. Перезапуск regression подтвердил ноль
подписок до и после async 401 cleanup и `ApiFailureKind.unauthorized`. R05 404
проходит непосредственно к ограниченному marker reader. Известные 401/403/404/503
и Retry-After сохраняются по HTTP status/headers. AuthInterceptor не обходится
для 401.

### F02 P3. Dot-segment идентификатор менял конечный путь

`lib/features/results/data/documents_api.dart:42–46,60–63,368–375`.

**Impact.** Значения `.` и `..` после `Uri.encodeComponent` могли нормализоваться
в другой path на том же gateway. Это выводило запрос за фиксированный U04/R05.

**Evidence.** Pinned Dio `Options.compose(...).uri.path` превратил
`/meetings/results/../documents/summary.txt` в `/meetings/documents/summary.txt`.
Отдельный probe находится в `/tmp/dictai-platform-review-20261104/dot_id.dart`.

**Recommendation.** Отклонять `.`/`..` в audio path segment до HTTP, сохранить
экранирование прочих ID и exact optional job query.

**Disposition.** Fixed with evidence. Regression проверяет оба значения на U04
и R05, zero transport calls и отсутствие временных файлов.

Открытых actionable findings в проверенном scope нет.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS 26.2 arm64. Flutter 3.41.3 / Dart
3.11.1 из `.dart_tool/codex-tools/flutter`. `PUB_CACHE=/Users/verliiar/.pub-cache`,
`CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Проверка reviewer | Фактический результат |
|---|---|
| `.dart_tool/codex-tools/flutter/bin/flutter test --no-pub test/features/results/documents_api_test.dart --reporter expanded` | PASS, исходные 30/30 и итоговые 32/32 после обоих fixes |
| Scoped Dart `analyze` по трём Dart-файлам | PASS, No issues found |
| Dart `format --output=none --set-exit-if-changed` по тем же файлам | PASS, 3 files, 0 changed |
| `git diff --check` по task card и `git diff --no-index --check /dev/null <path>` по новым Dart-файлам | PASS, whitespace diagnostics нет |
| Pinned Dio probes из `/tmp/dictai-platform-review-20261104` через Dart `--packages=.dart_tool/package_config.json` | PASS, независимо воспроизведены F01 и F02 на исходном механизме |
| Сверка backend handlers, source order, scope и dependencies | PASS, read-only source verification |
| Native playback, live gateway/Keychain, memory и latency на 1 GiB, UI/platform smoke | NOT RUN, поздние задачи .31/.36/.37/.40/.44 |

## Strengths and residual risk

Потребитель получает свой файл только после полного EOF и проверки content type,
Content-Length при наличии и структуры WAV. RIFF length отделяет чистый ранний
EOF от успешной передачи, WAV validator дополнительно проверяет формат и границы.
Ошибки, отмена и idle timeout очищают owned partial. Тесты проверяют неизменность
серверных bytes, четыре документа, точный optional job, chunked WAV, 8 MiB fixture,
404 marker, cleanup и отсутствие JWT для чужого origin.

Файловые writes ограничены порциями до 64 KiB, синхронное ожидание диска может
временно задерживать event loop. Тесты не измеряли пиковую память или latency на
реальной большой передаче. Для R05 без Content-Length проверяется успешный EOF
и доступный формат, независимой checksum wire contract не содержит. Экспорт и
player должны удалять переданный owned file в своём lifecycle. Отчёт не выставляет
`accepted` и не закрывает runtime gates.
