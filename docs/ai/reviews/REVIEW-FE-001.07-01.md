---
id: REVIEW-FE-001.07-01
task_ids: ["TASK-FE-001.07"]
reviewer: /root/review_foundation_batch
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.07-01

## Scope

2026-10-27. Независимый reviewer `/root/review_foundation_batch`, не писавший
реализацию, завершил TASK-FE-001.07 review и разрешённую coordinator финальную
metadata/source delta проверку выбранного набора .03–.07. Единственная запись
reviewer — этот заранее зарезервированный отчёт. Source, TLS delta, итоговая
карточка/план/active-plan и интеграционные проверки завершены.

Проверены целиком `lib/core/error/app_exception.dart`, новый
`lib/core/network/api_error_mapper.dart`, новый
`test/core/network/api_error_mapper_test.dart` и delta task-карточки .07.
База — frontend HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c`, manifest
`/tmp/dictai-foundation-03-07-20261026/baseline.json` и `before/` рядом с ним.
Прочитаны полный scoped diff и новые файлы, затем TLS-исправление implementer
и новый regression test. Reviewer не менял source/tests/tasks/plan.

Контекст: AGENTS/WORKFLOW, architecture, PLAN-FE-001, текущий выбор, .06 test
fixtures, API snapshot/UX-17, текущие read-only backend handlers R03/R04/R05/U01/U05,
gateway rate-limit и worker summary lifecycle, pinned Dio IO adapter/mixin.
Интеграционная совместимость .03–.05 проверена source review; принятые .01/.02
не переоткрывались. Настройки, чужой planning diff и backend не изменялись.

## Findings

### F01 — [P2] Стандартный TLS failure попадал в invalidResponse

Файл: `lib/core/network/api_error_mapper.dart`, исходная ветка на строке 57
первого review; исправленная ветка начинается на строке 46 текущего файла.

Impact: обычный отказ PKI/handshake от default HTTP adapter из .05 объяснялся
пользователю как ошибка чтения ответа. Контекст incompleteTransfer также имел
приоритет над security failure и мог выдавать retry/replay suggestion.

Evidence: первоначально TLS распознавался только по `DioExceptionType.badCertificate`.
В pinned Dio 5.9.2 `io_adapter.dart` обрабатывает SocketException отдельно,
но стандартный dart:io HandshakeException/TlsException проходит в
`assureDioException` как unknown. badCertificate adapter создаёт только при
custom validateCertificate. Default TLS verification .05 такого callback не имеет.

Recommendation: классифицировать dart:io TlsException, включая HandshakeException,
как transportSecurity; проверять security до incompleteTransfer и не предлагать
retry/replay. Добавить regression для default-IO exception shapes и конфликтующего
recovery context.

Disposition: **fixed with evidence**. Implementer добавил `error.error is TlsException`
рядом с badCertificate перед incompleteTransfer. Новый test
`standard IO TLS failures take priority over recovery context` проверяет оба
dart:io класса для GET/POST, flags incompleteTransfer/hasRecoverableUpload и
badCertificate. Reviewer независимо прочитал delta и выполнил все 31 tests — PASS.

### F02 — [P3] Неточная атрибуция исправления test fixture .05

Файл: `docs/ai/active-plan.md:61`. Первоначальный итоговый абзац приписывал
reviewer требование заменить storage fixture .05, хотя coordinator инициировал
это после первого verdict, а reviewer независимо проверил delta. Impact:
недостоверная история происхождения review evidence. Recommendation: нейтрально
указать удаление скрытой compile-зависимости и независимую проверку.
Disposition: **fixed with evidence** — coordinator заменил формулировку на
«В .05 убрана скрытая зависимость …; … delta независимо проверена»;
reviewer перечитал текущий абзац и подтвердил соответствие.

Других actionable findings P0–P3 после исправлений нет. Открытых code или
metadata findings нет. Известный обязательный OS blocker .04 остаётся отдельно.

## Verification

Самостоятельно reviewer, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Переиспользованы принятые SDK/cache .01: Flutter 3.41.3/Dart 3.11.1,
`/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter`,
`PUB_CACHE=/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`.

| Проверка | Actual | Статус / предел |
|---|---|---|
| `flutter test --no-pub test/core/network/api_error_mapper_test.dart` после TLS delta | Все 31 tests passed, exit 0 | PASS; synthetic cases + .06 ScriptedAdapter, нет реального backend |
| `dart analyze lib/core/error/app_exception.dart lib/core/network/api_error_mapper.dart test/core/network/api_error_mapper_test.dart` | No issues found, exit 0 | PASS |
| `dart format --output=none --set-exit-if-changed lib/core/error/app_exception.dart lib/core/network/api_error_mapper.dart test/core/network/api_error_mapper_test.dart` | 3 files, 0 changed | PASS |
| Scoped tracked/new-file whitespace и полный diff | Diagnostics нет | PASS |
| Local Markdown links карточки | Все 10 paths разрешаются после создания этого отчёта | PASS |
| Текущие backend handlers + API snapshot/UX | Markers/status/actions согласованы | PASS source review; не runtime test |
| Финальный `flutter test --no-pub --reporter expanded` | Все 72 tests passed, exit 0 | PASS независимо после TLS/metadata delta; 4 logging + 14 storage/interceptor + 17 config + 6 foundation + 31 mapper |
| Global analyze | Авторский FAIL: 13 прежних info, 0 errors/warnings | Reviewer не повторял; прежний baseline не объявляется PASS |
| Live TLS/gateway/model/export, native Debug/Release/Linux | Не запускались | NOT RUN; fixture не доказывает deployment или OS storage |

### Финальная metadata/source delta набора

Reviewer перечитал итоговые карточки .03–.07, текущие разделы PLAN-FE-001 и
active-plan, отдельный полный .06 review, test-only fixtures/widget scenarios.
Разрешённое принятие .01/.02 отражено только учётными статусами; product scope
будущих задач не запущен. Scope source .03–.05 совпадает с предыдущими независимыми
проходами; последующая .07 delta добавляет exception types/mapper/tests без
изменения logging/auth/origin/storage policies. Полный suite выше независимо
подтверждает совместимость текущего набора; fakes остаются явно отделены от OS.

Независимо запущен прочитанный `check_docs.py` из временного каталога baseline
в read-only варианте: исключена только запись `final-checks.json`, исходники
check logic не менялись. PASS: 51 canonical ID, A/B/C=24/22/5;
accepted=2/review=4/blocked=6/draft=39, 0 cycles/unordered shared writers,
728 local links, 6 anchors, 14 source refs. Table/DAG/frontmatter/scopes и
selected_tasks согласованы. К исходному dirty baseline изменены ровно 19 прежних
файлов и добавлены 17 разрешённых; остальные 154 frontend и все 589 backend
файлов неизменны. BACKEND snapshots byte-identical, оба HEAD прежние, dependency
pins/settings не изменены, staging пуст. Полный `git diff --check` — PASS.
Финальная запись coordinator о таком же manifest PASS прочитана и согласована
с самостоятельным результатом reviewer.

Статусы .03/.05/.06/.07 — review, .04 — blocked, новых accepted нет.
Следующие кандидаты в плане обозначены рекомендацией после приёмки/отдельного
выбора; отсутствие зависимости от .04 у .10/.18/.21/.22/.26 сверено с DAG.

## Strengths and residual risk

- Status/transport categories локальны; закрытого enum серверных error strings
  или новых assignment/export операций нет. Возвращаются только фиксированные
  safe messages. Не копируются raw URL/headers/body/exception text, тело читается
  через проверку типов, bounded JSON/UTF-8 parsing и exact documented markers.
- 400/401/403/404/409/429/500/502/503 различаются. Document 404 требует resource
  context и `document unavailable`; artifact 503 — structured context и
  `artifact unavailable`. Generic result 404 остаётся отдельным случаем.
  Retry-After необязателен; seconds/date проверяются, плохое значение игнорируется.
- Complete 2xx/202 из forced validator не считается HTTP failure. Mapper не
  интерпретирует job DTO и не превращает failed/cancelled 202 в команду ожидания;
  настоящий handler R04 также возвращает 202 для неготового terminal transcript.
  Unknown summary_error допускается, не отражается пользователю и не создаёт
  фиктивную server regeneration/reprocess/cancel/reissue action.
- Recovery actions неизменяемы и являются предложениями. GET/HEAD retry и POST
  replay разрешаются только подходящим failure categories; upload replay требует
  явного caller knowledge о тех же bytes/metadata/idempotency key. Сам mapper не
  делает IO, retries, navigation, storage writes или server commands. Будущие
  consumers обязаны корректно передавать facts context, а не угадывать их из URL.
- Существующие AppException constructors совместимы с .04. GatewayPolicyException
  .05 распознаётся безопасно; .03 logging не менялся. Ни один feature client/DTO/UI
  пока не переключён на mapper: это явно оставленный scope .08+ и соответствующих
  API-задач. Существующие feature casts не объявляются уже исправленными.

Обязательный development-certificate/Keychain Debug/Release blocker .04 остаётся
open; этот review его не снимает. Native и Linux storage/capture не проверялись.
TLS fix проверен synthetic exceptions и source pinned adapter, без реального
сертификата/соединения. Этот отчёт не устанавливает accepted и не разрешает
commit/push/merge/release.
