---
id: REVIEW-FE-001.21-01
task_ids: ["TASK-FE-001.21"]
reviewer: /root/review_workspace_contracts
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.21-01

## Scope

2026-11-03. Независимый reviewer `/root/review_workspace_contracts`, не писавший
реализацию, завершил review TASK-FE-001.21 и delta после F01. Единственная запись
reviewer — этот заранее зарезервированный отчёт. Код, tests, карточки, план,
реестр и backend reviewer не менял.

Проверено полное содержимое `lib/features/results/data/speech_status_api.dart`,
`lib/features/results/data/dto/speech_status_dto.dart`,
`lib/features/record/data/dto/v2_session_dto.dart`,
`test/features/results/speech_status_api_test.dart` и карточки .21. Файлы новые
относительно HEAD `80959cc10eacabf45fbf461dbe596030e4e7277c`; начатые до коррекции
плана drafts учитываются по baseline текущей фазы
`/tmp/dictai-current-implementation-20261102/baseline.json`, не выдаются за уже
проверенный результат. Прочитаны все строки source/test и scoped new-file diff.

Контекст: AGENTS/WORKFLOW/architecture, актуальные PLAN/active/current границы,
API R03/U03, общий mapper и test adapter. Реальный backend HEAD
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` подтверждён; самостоятельно прочитаны
SpeechHandler.load/Status/Structured и V2 Session handler/repository. Принятые
.01/.02 не переоткрывались. Future naming/contact assignments/mock business UI
не входят в текущий scope и не добавлены этим diff.

## Findings

### F01 — [P2] Неизвестный summary status блокировал transcript polling

Файл: `lib/features/results/data/dto/speech_status_dto.dart:67`.

Impact: при известном running/completed job и pending transcript новое неизвестное
значение summary_status давало shouldPollTranscript=false. Состояние независимой
summary тем самым прекращало ожидание transcript, хотя его контракт и обработка
были понятны клиенту. Это нарушало принцип «summary не gate».

Evidence: первый вариант getter использовал `!hasUnknownStatus`; этот общий
diagnostic flag включает summaryStatus. Reviewer прочитал реализацию и передал
замечание автору и coordinator до завершения review.

Recommendation: останавливать transcript polling при неизвестном job/transcript,
terminal failure/cancel или готовом transcript; неизвестную summary сохранить
как отдельную диагностику. Добавить regression для running/pending/unknown summary.

Disposition: **fixed with evidence**. Автор ограничил unknown guard состояниями
job/transcript, сохранив общий diagnostic flag. Reviewer независимо прочитал
исправление и повторил 13 tests, включая новый
`unknown summary does not gate a known pending transcript`: transcript остаётся
pending, summary — unknown, shouldPollTranscript=true. Никакого ложного ready
или synthetic progress исправление не создаёт.

Других actionable code/documentation findings P0–P3 в назначенном scope нет;
открытых findings после delta нет.

## Verification

Самостоятельно reviewer, cwd `/Users/verliiar/Desktop_application`, macOS arm64.
Принятый Flutter 3.41.3/Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `FLUTTER_SUPPRESS_ANALYTICS=true CI=true`.
SDK/dependency pins не переоценивались и не менялись.

| Проверка | Actual | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/results/speech_status_api_test.dart --reporter expanded` после F01 | 13 tests passed, exit 0 | PASS; изолированный HTTP adapter, localhost runner с разрешённым доступом |
| `flutter analyze --no-pub lib/features/results/data/speech_status_api.dart lib/features/results/data/dto/speech_status_dto.dart lib/features/record/data/dto/v2_session_dto.dart test/features/results/speech_status_api_test.dart` | No issues found, exit 0 | PASS; targeted scope |
| `dart format --output=none --set-exit-if-changed` для тех же четырёх файлов | 4 files, 0 changed, exit 0 | PASS, source не записывался |
| Полный source/test/new-file diff, `git diff --no-index --check /dev/null <file>` для всех четырёх новых файлов | Whitespace diagnostics отсутствуют | PASS; code 1 no-index означает ожидаемый diff |
| Локальные Markdown targets карточки | Отсутствующих targets нет | PASS |
| Backend source R03/U03, nullable keys, states, pinned query, terminal/summary semantics | Соответствуют snapshot и текущей реализации | PASS source review, не live API test |
| Live gateway/JWT, OS storage, macOS/Linux app builds, общий suite/global analyze | Reviewer не запускал | NOT RUN; data-only fixtures не deployment/platform evidence |

## Strengths and residual risk

R03 сохраняет все семь обязательных полей, в том числе явные nullable
workspace_id/summary_error. Job/transcript/summary парсятся отдельно; completed
job с pending projection не становится ready автоматически. Open summary_error
не превращён в закрытый enum и помечен как небезопасный для прямого UI вывода.
Неизвестные статусы сохраняют raw значение для диагностической обработки, не
выдаются за completed. Terminal failure/cancel прекращает ожидание transcript.

U03 использует существующий V2 route, все шесть состояний, явно требует
confirm_required=false и не содержит speakers/fragments/confirmation flow.
Session ready не объявляется доказательством доступного canonical artifact.
Запрос pinned job_id сохраняет точный query; отсутствие query — latest, не история.
Ответ другого pinned job/session отвергается. Пустой pinned ID не превращается
неявно в latest. Экранирование пути проверено на клиентском уровне, без утверждения
об end-to-end нормализации реальным gateway.

Malformed/неполные payloads, неверный HTTP status и несовпадение identity дают
безопасный ApiFailure вместо TypeError/raw technical detail. Общие HTTP/transport
значения и safe local auth/storage errors сохраняются. Клиент получает injected
Dio и не добавляет polling, retries, provider/router wiring или новых endpoints.
Тесты обходят настоящий AuthInterceptor/сетевой backend; их результат этого не
подменяет. Fake HTTP fixtures относятся только к действующему API.

Review завершён для текущего .21 diff и F01 delta. Он не устанавливает accepted,
не закрывает native .04 или backend/host gates и не разрешает commit/push/merge.
