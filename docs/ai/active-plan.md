# Снимок frontend для main — 2026-11-07

Владелец поручил завершить уже начатые .03 (test delta), .13, .16 и .25 и
отправить проверенный текущий снимок в `origin/main`. Новые implementation задачи
в этом проходе не запускаются. Сохраняются границы current/future из PLAN-FE-001.
Обычный commit и push разрешены этим поручением. Приёмка задач остаётся отдельной.

| Review ID | Owner | Write scope | Резерв |
|---|---|---|---|
| REVIEW-FE-001.03-02 | /root/review_snapshot_ui | docs/ai/reviews/REVIEW-FE-001.03-02.md | created |
| REVIEW-FE-001.13-01 | /root/review_snapshot_ui | docs/ai/reviews/REVIEW-FE-001.13-01.md | created |
| REVIEW-FE-001.16-02 | /root/review_snapshot_platform | docs/ai/reviews/REVIEW-FE-001.16-02.md | created |
| REVIEW-FE-001.25-02 | /root/review_snapshot_platform | docs/ai/reviews/REVIEW-FE-001.25-02.md | created |

Реализация .13 сохранена от /root/workspace12_resume. Coordinator принимает
карточку и узкие исправления при findings. Независимые reviews .03/.13/.16/.25 завершены. Старые partial .16-01/.25-01 сохранены как первый проход.

P2 .16-02 о delegate didStopWithError передан /root/finish_native_teardown.
Только exact .16 paths, coordinator не пишет её source. .13/.25 fixes пишет
primary-agent, затем независимый delta у ранее назначенных reviewers.

Проверки снимка 2026-11-07.

- PASS 515 Flutter tests, `flutter test --no-pub --reporter expanded`.
- PASS `flutter analyze --no-pub --no-fatal-infos`, 9 прежних info,
  ошибок и предупреждений нет.
- PASS macOS Debug build и 13 независимо повторённых synthetic native XCTest.
  Реальный macOS/Linux захват остаётся в .36/.37, живой gateway в .39/.40.
- PASS 51 карточка, зависимости без циклов, публикационный scope и whitespace.
  Backend, зависимости, локальные настройки редактора, подписи и generated Pods
  оставлены в исходном состоянии. Тестовые маркеры и URL используют синтетические
  fixtures. Секреты и аудиофайлы в снимок не включены.

Статусы tasks разделяют review и принятие. Открыты следующие этапы подключения
экранов записи, Results и экспорта к подготовленным V2 компонентам.

# Возобновление current реализации — 2026-11-06

Поручение пользователя «доделывай» сохраняет весь current scope и запрет публикации.
Прежние workers больше не активны. Их partial diff сохраняется, владение передаётся
последовательно: .12 — /root/workspace12_resume, .16 — /root/macos16_resume,
.17 и узкий F01 fix .20 — primary-agent. Общие учётные файлы пишет координатор.

Для нового независимого прохода .20 зарезервирован REVIEW-FE-001.20-02,
`docs/ai/reviews/REVIEW-FE-001.20-02.md`, owner /root/review20_resume, created.
Предыдущий .20-01 остаётся историческим partial review, не переписывается.
После .20 новый reviewer получает .17-01 и .16-01, не участвуя в реализации.
Предыдущие reserved .12-01/.16-01/.17-01 сохраняют ID. .17-01 и .16-01
переданы /root/review20_resume, только отчёты. .12-01 назначается после handoff.
Команда создания Linux tests и их запуска в прошлом проходе не выполнялась из-за
лимита automatic approval review. Результат этой команды не считается PASS.

2026-11-06: .20-02 reviewed/complete, F01 fixed, 112 tests PASS. .17 реализована,
17 tests PASS, scoped analyze/format PASS, передана на независимый .17-01.
Root начинает .14 exact card scope после .11-01, providers пишет только root.
Зарезервирован REVIEW-FE-001.14-01, будущий
`docs/ai/reviews/REVIEW-FE-001.14-01.md`, owner /root/review20_resume, created.

2026-11-06: .17-01 и .14-01 reviewed/complete, findings исправлены/отсутствуют.
Root начинает .25 после checks/review .09/.14/.20/.21/.22. Providers и два read API
пишет только root согласно уточнённому scope .25. Зарезервирован
REVIEW-FE-001.25-01, будущий `docs/ai/reviews/REVIEW-FE-001.25-01.md`,
owner /root/review20_resume, reserved. .12-01 передан /root/review20_resume
после handoff автора, scope отчёта, без writes в source.

2026-11-06: .16 source frozen и передан .16-01 reviewer /root/review20_resume.
.12-01 выявил два P2, implementer /root/workspace12_resume исправляет свой scope.
Независимый .25-01 передан /root/macos16_resume после handoff root, только report.

2026-11-06: .25 source frozen, 107 tests PASS, scoped analyze/format PASS.
Передана /root/macos16_resume на независимый .25-01. .12 исправляет два findings,
.16 проходит независимый .16-01. Общие providers до review .25 не изменяются.

2026-11-06: независимый .16-01 выявил P2 native teardown retention. Исправление
вернулось /root/macos16_resume в exact .16 scope, .16-01 остаётся отдельному
review20_resume. Незавершённый .25 review передан /root/review20_resume до записи
report .25-01. /root/macos16_resume не автор .25, но её source не меняет.
.12 source frozen после F01/F02 fix, 68 tests PASS, ожидает delta .12-01.

2026-11-06: .12-01 reviewed/complete, F01/F02 fixed. /root/workspace12_resume
начинает .13 exact card scope. Зарезервирован REVIEW-FE-001.13-01, будущий
`docs/ai/reviews/REVIEW-FE-001.13-01.md`, owner /root/macos16_resume, reserved
(после handoff собственного .16 fix). .13 не пишет Record/router/providers.

2026-11-06: общий unit run обнаружил три ошибки fixture .03 logging test —
после .04 тест не подменял OS Keychain для защищённого запроса. Primary-agent
исправляет только test setup в прежнем exact .03 scope, production не меняет.
Зарезервирован REVIEW-FE-001.03-02, будущий
`docs/ai/reviews/REVIEW-FE-001.03-02.md`, owner /root/macos16_resume, reserved.

# Продолжение current реализации — 2026-11-03

Пользователь поручил продолжить с места исчерпания лимитов. Выбран прежний весь
current scope PLAN-FE-001; future .43/.45/.46/.47/.50/.51 исключены. .01/.02 не
переоткрываются. Commit/push/merge/release запрещены. Backend read-only.
Baseline возобновления: `/tmp/dictai-resume-20261103/baseline.json` (201 файл).

Текущие writers: primary-agent .04 (harness/card; передана на review), .26 (реализована, review), затем .08 (exact scope карточки) и общие coordinator записи;
/root/record_data .18 (review complete, source frozen), затем .19 exact scope/card; /root/results_contracts .21/.22 (review, source frozen), затем .30 exact scope/card. Reviewer
/root/review_workspace_contracts — только reserved .04-04/.18-01/.21-01/.22-01 reports.
Порядок перехода — checks + independent review, accepted автоматически не ставится.

.04: actual Debug/Release builds, strict/deep подписи/applied entitlements и 24/24
отдельных native фаз PASS, 14 unit tests/targeted analyze/format/plist PASS.
B01 native timeout снят; итоговая карточка review; независимый REVIEW-FE-001.04-04 подтвердил все 24 native фазы и checks, открытых findings нет.
.18/.21 ещё в работе/review, их окончательные findings учитываются до перехода.
SDK `.dart_tool/codex-tools/flutter` 3.41.3/Dart3.11.1,
PUB_CACHE `/Users/verliiar/.pub-cache`; зависимости не обновляются.

Зарезервирован REVIEW-FE-001.19-01: будущий `docs/ai/reviews/REVIEW-FE-001.19-01.md`,
reviewer /root/results_contracts, только отчёт.

Зарезервирован REVIEW-FE-001.30-01: будущий `docs/ai/reviews/REVIEW-FE-001.30-01.md`,
reviewer /root/review_platform_clients, только отчёт. Предыдущий reviewer достиг лимита до записи.

Зарезервирован REVIEW-FE-001.08-01: будущий `docs/ai/reviews/REVIEW-FE-001.08-01.md`,
reviewer /root/review_workspace_contracts, только отчёт.

Зарезервирован REVIEW-FE-001.26-01: будущий `docs/ai/reviews/REVIEW-FE-001.26-01.md`,
reviewer /root/review_workspace_contracts, только отчёт.

Текущие уточнения зависимостей: .22→.21 для R04 202 SpeechStatusDto (review22 F01);
.30→.18 для проверки original WAV. Plan/table/DAG/cards согласуются, циклов нет.

Root начинает .15 exact card scope после завершённых .04/.18 checks/review,
с явной .15→.18 для общего WAV parser. Зарезервирован REVIEW-FE-001.15-01, будущий
`docs/ai/reviews/REVIEW-FE-001.15-01.md`, reviewer /root/record_data.

Review очередь разделена 2026-11-03: независимый /root/results_contracts проверяет
.19 (не писал её), /root/record_data проверяет .15 (не писал её). Exact write scopes
только .19-01 и .15-01 reports соответственно. /root/review_workspace_contracts
продолжает только .30-01; передачи сообщены до начала записи отчётов.

Root выполняет .09 после независимого review .08, exact scope в карточке.
SecureStorage использует прежнюю очередь для атомарной защиты от stale 401/refresh.
Зарезервирован REVIEW-FE-001.09-01, будущий `docs/ai/reviews/REVIEW-FE-001.09-01.md`,
reviewer /root/results_contracts (передан до начала review).

TASK-FE-001.19 завершила независимый delta review (F01/F02 fixed).
/root/record_data начинает .20, только её exact scope/card. Зарезервирован
REVIEW-FE-001.20-01, будущий `docs/ai/reviews/REVIEW-FE-001.20-01.md`,
reviewer /root/results_contracts.

Root исправляет .15 по review15-01 в её exact scope. Зарезервирован
REVIEW-FE-001.15-02, будущий `docs/ai/reviews/REVIEW-FE-001.15-02.md`,
reviewer /root/review_platform_clients. Linux mic-only принадлежит .17.

2026-11-04: .09 independent review complete, F01–F03 fixed.
/root/results_contracts начинает .11 после .09/.10, exact card scope.
Зарезервирован REVIEW-FE-001.11-01, будущий `docs/ai/reviews/REVIEW-FE-001.11-01.md`,
reviewer /root/record_data, передан до начала review.

2026-11-04: root принял .30 только для исправления двух findings,
source автора сохранён. /root/results_contracts продолжает .11.

2026-11-04: .20 source/tests сохранены после лимита, owner завершил evidence.
.20-01 остаётся /root/results_contracts. Параллельно /root/record_data проверит
.11-01 после готовности автора. Только зарезервированные reports.

2026-11-04: .15-02 завершён независимо, 19 tests PASS, F01–F05 fixed.
.16 назначена /root/review_platform_clients после записи .30-01.
Зарезервирован REVIEW-FE-001.16-01, будущий `docs/ai/reviews/REVIEW-FE-001.16-01.md`,
reviewer /root/record_data (не автор). Только exact .16 scope.

2026-11-05: root начал .17 после .15-02. .16 и .17 имеют независимые scopes.
Зарезервирован REVIEW-FE-001.17-01, будущий `docs/ai/reviews/REVIEW-FE-001.17-01.md`,
reviewer /root/results_contracts после .20-01. .30-01 завершён.

2026-11-05: .11-01 reviewed/complete, /root/record_data начинает .12.
Зарезервирован REVIEW-FE-001.12-01, будущий `docs/ai/reviews/REVIEW-FE-001.12-01.md`,
reviewer /root/results_contracts. Exact .12 scope, root не пишет общие с .12 файлы.

2026-11-05: root принял .20 для узкого stale-session F01 fix.
Автор первоначального .20 продолжает .12, текущий reviewer .20-01 остаётся
/root/results_contracts. Переход зависимых задач после delta.

Ниже сохранён журнал завершённой коррекции и прежних поручений; старые statuses/
разрешения не заменяют актуальные карточки и последний запрет публикации.

# Текущий этап: коррекция на существующий backend — 2026-11-02

Последнее решение владельца заменяет прежний mock-ready milestone: current —
полноценный frontend на реально существующих API; future naming сохраняется,
но не разрабатывается до backend. Сейчас только planning docs и независимый review.
После этого пользователь прямо поручил сразу продолжить **current** задачи до конца
по DAG. Нового запроса на выбор не нужно; automatic accepted не выставляется.
Commit/push/merge последним поручением запрещены, прежнее разрешение публикации
не действует. Backend/dependencies/функциональный код во время коррекции read-only.

**45 current задач:** .01–.42, .44/.48/.49. **6 future C blocked:**
.43/.45/.46/.47/.50/.51. Категории A/B/C=27/18/6. Статусы: accepted=2,
review=5, in_progress=3, blocked=10, draft=31; future draft переведены в blocked,
другие statuses сохранены. .39/.40/.42 current category A blocked по среде/evidence,
а не из-за отсутствующего names API. Ни один current prerequisite не ведёт в future.

.44 — настоящий полный player, .48 — готовность→transcript/notice/Results;
будущий editor routing перенесён в .50. .29 не ждёт .43; текущий export/delete/
isolation/tests/E2E/приёмка не требуют .50/.51. Contact CRUD .13 сохраняется.
Вместо будущих имён показываются backend Speaker labels, без fake controls/store/
mock repository/Save/Skip. Test fakes существующих API/оборудования разрешены.
Новых task ID нет. Нормативные документы: PLAN-FE-001, UX/BR и ADR-FE-008.

## Сохранённая работа и агенты

.01/.02 accepted read-only. .03/.05/.06/.07/.10 reviewed, не повторяются.
.04 частичная: Debug/Release build созданы и Debug strict/deep signature PASS;
Debug native empty phase timeout 25s, полного Keychain evidence нет — blocked.
.18 in_progress: wav_validator.dart/upload_options.dart, tests/format/analyze NOT RUN.
.21 in_progress: speech_status_api.dart/speech_status_dto.dart/v2_session_dto.dart,
tests/format/analyze NOT RUN. .22 in_progress: исследование, кода/fixtures/tests нет.
Эти непроверенные drafts сохранены, не считаются завершёнными.

Агенты /root/record_data и /root/results_contracts остановили запись на безопасной
границе и сообщили пути. Новая реализация не начинается до review этой коррекции.
После него coordinator явно передаёт writer обратно; другой reviewer проверяет
каждый implementation diff. Пользователь разрешил параллельные exact scopes,
providers/router/plan/active — только один назначенный writer.

Baseline planning: /tmp/dictai-plan-current-backend-20261102/baseline.json,
198 frontend / 589 backend-файлов и оба HEAD. Разрешённый planning write scope:
PLAN-FE-001, TASK-FE-001.03–.51, FRONTEND_TARGET_UX.ru.md,
FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md, decisions, active-plan и report ниже.
Все source/platform/test/dependencies/settings/Xcode local files и .01/.02 byte-preserved.
Оба BACKEND_* снимка неизменны. Сборки/SDK/fakes прошлого этапа не доказательство docs.

| Новый review ID | Write path | Owner | Резерв |
|---|---|---|---|
| REVIEW-FE-001.01-06 | docs/ai/reviews/REVIEW-FE-001.01-06.md | /root/review_current_backend_plan | created |

Коррекция завершена и независимо проверена: REVIEW-FE-001.01-06 reviewed/complete,
оба findings (checksum exception и stale naming verification) исправлены и повторно
проверены; открытых actionable P0–P3 нет. Docs checker PASS: 51 ID, 45 current/6future,
A/B/C=27/18/6, 726 local links/5 anchors/14 source refs, cycles=0,
current→future prerequisite=0, unordered shared writers=0. `git diff --check` PASS.
К baseline изменены только 54 разрешённых документа и добавлен один review;
144 остальных frontend-файла (включая source/drafts/01/02/deps/settings/platform)
и 589 backend-файлов byte-identical; оба HEAD/index и BACKEND_* копии сохранены.
NOT RUN: Flutter/native/backend tests в этой коррекции, поскольку изменены только docs.

Последнее поручение прямо разрешает теперь продолжать current implementation:
завершить .04 и начатые .18/.21/.22, затем .08/.09 и доступные data/capture/UI по DAG.
Планирование завершено, последующие изменения кода — отдельная разрешённая фаза;
это не автоматический accepted и не разрешение commit/push/merge.
Внешние host/operator/quality blockers не обходятся и не получают accepted.

## Возобновление current implementation после review — 2026-11-02

Документная коррекция завершена; её hash/links/DAG proof сохранён отдельно в
final-planning-checks.json вне репозитория. Последующие code изменения относятся
к прямо разрешённой implementation фазе, а не к baseline коррекции.
Writer scopes: primary-agent .04/card и общие coordinator записи;
/root/record_data .18/card; /root/results_contracts .21/.22/cards. Каждый читает
актуальный current scope, future .43/.45/.46/.47/.50/.51 не реализуются.
Reviewer /root/review_workspace_contracts пишет только reserved .04-04/.18-01/
.21-01/.22-01 reports. До их ready/checks/review новые зависимые задачи не стартуют.
Baseline этой фазы: /tmp/dictai-current-implementation-20261102/baseline.json.
Commit/push/merge по-прежнему запрещены.

## История прежних поручений и результатов (не текущая инструкция)

# Текущий этап: весь оставшийся PLAN-FE-001 — 2026-11-02

Пользователь явно расширил выбор на все оставшиеся задачи до конца плана.
.01/.02 приняты и read-only; .03/.05/.06/.07 уже реализованы/reviewed, не повторяются.
Работа идёт по DAG, после checks и независимого review без промежуточного запроса;
это прямое поручение на весь план, но не автоматическая приёмка/accepted карточек.
Backend read-only. Неизвестные контракты не выдумываются; C-задачи сохраняют gates.
Предыдущее разрешение commit/push остаётся, merge/release не выполняются.

Пользователь отдельно разрешил параллельную реализацию несколькими агентами.
Общие plan/active/providers/router пишет только coordinator; пересекающиеся
scopes не выполняются одновременно.

Текущие writer scopes: primary-agent — .04 (native smoke/evidence) и .10
(workspace API/DTO/tests), последовательно; общие учётные документы — coordinator.
Сначала .04, если профиль подписи доступен; иначе .10/.18/.21/.22/.26/.30 доступны
без неё. .08/.09/.11 и capture/journal ждут завершения соответствующих prerequisites.
Назначены /root/record_data — .18 (только её scope/card),
/root/results_contracts — .21/.22 (их scopes/cards); reviewer
/root/review_workspace_contracts пишет только зарезервированные review reports.

SDK 3.41.3 восстанавливается в игнорируемый `.dart_tool/codex-tools/flutter`,
чтобы пережить очистку системного tmp; pins и глобальный SDK не обновляются.
Baseline текущего прохода: /tmp/dictai-fe04-finish-20261102/baseline.json.

| Review ID | Write path | Owner | Резерв |
|---|---|---|---|
| REVIEW-FE-001.04-03 | docs/ai/reviews/REVIEW-FE-001.04-03.md | /root/review_keychain_finish | created, продолжается после native evidence |
| REVIEW-FE-001.10-01 | docs/ai/reviews/REVIEW-FE-001.10-01.md | /root/review_workspace_contracts | created |
| REVIEW-FE-001.04-04 | docs/ai/reviews/REVIEW-FE-001.04-04.md | /root/review_workspace_contracts | reserved |
| REVIEW-FE-001.18-01 | docs/ai/reviews/REVIEW-FE-001.18-01.md | /root/review_workspace_contracts | reserved |
| REVIEW-FE-001.21-01 | docs/ai/reviews/REVIEW-FE-001.21-01.md | /root/review_workspace_contracts | reserved |
| REVIEW-FE-001.22-01 | docs/ai/reviews/REVIEW-FE-001.22-01.md | /root/review_workspace_contracts | reserved |

## История предыдущего поручения

# Текущий этап: завершение .04 и публикация foundation — 2026-10-30

Пользователь настроил Team в Xcode и поручил завершить .04, затем commit/push
выполненных изменений. Текущая ветка main, база 80959cc10eacabf45fbf461dbe596030e4e7277c.
Разрешены проверки и узкая доработка native smoke harness .04, её карточка,
PLAN-FE-001 и этот реестр. Остальные implementation-задачи не выбраны, backend read-only.
Приёмка новых карточек автоматически не выставляется. Прежние Git-запреты ниже
относятся к предыдущим поручениям; текущее разрешает commit/push, но не merge/release.

Локальные пользовательские изменения project.pbxproj/Runner.xcscheme и
.vscode/settings.json сохраняются и исключаются из публикации. Для native проверки
используется выбранная пользователем development identity и внешний signing override;
личная Team не становится обязательной настройкой общего репозитория.
Прежний временный SDK удалён после перезапуска: восстанавливается та же принятая
Flutter 3.41.3/Dart 3.11.1 с проверкой закреплённого archive SHA, без обновления pins.
Baseline текущего прохода (190 frontend/589 backend-файлов) сохранён вне репозитория.

| Новый review ID | Назначенный write path | Owner | Резерв |
|---|---|---|---|
| REVIEW-FE-001.04-03 | docs/ai/reviews/REVIEW-FE-001.04-03.md | /root/review_keychain_finish | reserved |

## История предыдущего набора (не текущее разрешение)

# Реализация foundation .03–.07 — 2026-10-26

Пользователь явно выбрал .03/.04/.05/.06/.07 и подтвердил приёмку .01/.02.
Существующие реализации .01/.02 не повторяются и не перепроверяются; синхронизируется
только учёт их приёмки. Остальные задачи не выбраны. Backend read-only, commit/push/merge запрещены.
Coordinator/implementer — primary-agent, текущий checkout main с сохранённым dirty planning diff.
База frontend 80959cc10eacabf45fbf461dbe596030e4e7277c; baseline до реализации в памяти/временном manifest.

Порядок: .03/.04/.06 независимы после принятой .01; .05 после .03; .07 после .03/.05/.06.
Текущее поручение прямо разрешает следующий task выбранного набора после успешных
checks и независимого review без промежуточного запроса; это исключение только для
внутренних переходов этого набора, не автоматическое accepted новых карточек.
Scope источников — строго frontmatter пяти задач; общие api_client .03→.05 последовательно.
Если .04 не имеет реального macOS Debug/Release Keychain evidence, она blocked с результатом,
другие выбранные задачи от неё не зависят. Подходящая локальная подпись не меняется вне scope.

## Review ID текущей реализации (зарезервированы до делегирования)

| ID | Будущий путь | Owner | Состояние резерва |
|---|---|---|---|
| REVIEW-FE-001.03-01 | docs/ai/reviews/REVIEW-FE-001.03-01.md | /root/review_foundation_batch | created |
| REVIEW-FE-001.04-02 | docs/ai/reviews/REVIEW-FE-001.04-02.md | /root/review_foundation_batch | created |
| REVIEW-FE-001.05-01 | docs/ai/reviews/REVIEW-FE-001.05-01.md | /root/review_foundation_batch | created |
| REVIEW-FE-001.06-01 | docs/ai/reviews/REVIEW-FE-001.06-01.md | /root/review_test_foundation | created |
| REVIEW-FE-001.07-01 | docs/ai/reviews/REVIEW-FE-001.07-01.md | /root/review_foundation_batch | created |

## Итог текущего набора — 2026-10-27

| Задача | Фактический результат | Статус |
|---|---|---|
| [.03](tasks/TASK-FE-001.03.md) | Безопасные debug diagnostics, без URL/body/headers; 4 tests, независимый review без findings | review, не accepted |
| [.04](tasks/TASK-FE-001.04.md) | OS storage/migration/logout, оба entitlements, 14 fake tests; независимый review кода завершён | blocked: отсутствует development certificate, настоящий Keychain smoke NOT RUN |
| [.05](tasks/TASK-FE-001.05.md) | Явный gateway config, origin/redirect policy, timeouts; 17 tests и review | review, не accepted |
| [.06](tasks/TASK-FE-001.06.md) | App/router/widget smoke и test-only IO fakes; 6 tests и отдельный независимый review | review, не accepted |
| [.07](tasks/TASK-FE-001.07.md) | Общий error mapper, 31 test; TLS finding исправлен и независимо перепроверен | review, не accepted |

Счётчики: 51 карточка, A/B/C=24/22/5; accepted=2, review=4, blocked=6, draft=39.
Реализация будущих consumers mapper, auth/DTO/upload/polling/screens не начиналась.
.01/.02 изменены только для фиксации уже выраженной приёмки, без повторной реализации/проверок.

### Финальные проверки

Cwd `/Users/verliiar/Desktop_application`, macOS arm64. Использован прежний принятый
SDK `/private/tmp/dictai-fe-foundation-hdqe2j5k/sdk/flutter` (Flutter 3.41.3/Dart 3.11.1),
`PUB_CACHE=/private/tmp/dictai-fe-foundation-hdqe2j5k/pub-cache`, для Flutter —
`FLUTTER_SUPPRESS_ANALYTICS=true CI=true`. Это использование окружения, не повторная
проверка .01. Зависимости/pins не обновлялись. Для runner/analyzer разрешён доступ
к loopback/cache; backend не вызывался.

| Команда/проверка | Результат | Статус/граница |
|---|---|---|
| `flutter test --no-pub --reporter expanded` после TLS delta .07 | 72 tests passed | PASS; 4 logging + 14 storage/interceptor + 17 config + 6 test-foundation + 31 mapper |
| `dart analyze lib/core/config/app_config.dart lib/core/error/app_exception.dart lib/core/network/api_client.dart lib/core/network/auth_interceptor.dart lib/core/network/api_error_mapper.dart lib/core/storage/secure_storage.dart lib/shared/providers/providers.dart test` | No issues found | PASS, весь изменённый Dart scope |
| `dart format --output=none --set-exit-if-changed` для тех же source и `test` | После TLS delta: 16 files, 0 changed | PASS, только выбранный scope |
| `flutter analyze --no-pub` | 13 прежних prefer_const_constructors info в неизменённых shell/record, 0 errors/warnings, exit 1 | FAIL baseline; не объявляется чистым global analyze |
| `plutil -lint macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements` | Оба OK | PASS syntax; не OS security |
| Debug native smoke build .04 | Runner requires signing with a development certificate | FAIL, внешний blocker; project/team/profile не менялись |
| Реальный Debug/Release Keychain write/restart/read/delete, applied entitlements, controlled OS failure | Runner не собран | NOT RUN, обязательные проверки .04 остаются открыты |
| Linux/platform/live backend/TLS deployment/model checks | Не запускались | NOT RUN; fake/loopback tests не deployment evidence |

В .05 убрана скрытая зависимость fixture от новых storage interfaces .04;
использованы официальные plugin mocks, delta независимо проверена без findings.
В .07 reviewer обнаружил F01: стандартные IO HandshakeException/TlsException должны
считаться transportSecurity, а не invalidResponse. Исправлено с regression test и
приоритетом над incomplete-transfer/replay; reviewer независимо подтвердил fixed
повторными 31 tests/analyze/format. Новых/open code findings нет, приёмка ожидается.
Открытый B01 .04 не закрывается unit tests или отсутствием code findings.

### Файлы текущей реализации относительно сохранённого dirty baseline

Предыдущая актуализация UX/BR/51 карточки сохранена и не приписывается этому набору.
Точные изменения к baseline (не только tracked `git diff`):

| Область | Файлы |
|---|---|
| Dart production | `lib/core/config/app_config.dart`, `lib/core/error/app_exception.dart`, `lib/core/network/api_client.dart`, `lib/core/network/auth_interceptor.dart`, `lib/core/network/api_error_mapper.dart`, `lib/core/storage/secure_storage.dart`, `lib/shared/providers/providers.dart` |
| macOS/config | `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `.vscode/launch.json`, `.vscode/launch.example.json` |
| Tests/harness | `test/widget_test.dart`, `test/support/fakes.dart`, `test/support/test_app.dart`, `test/core/config/app_config_test.dart`, `test/core/network/logging_test.dart`, `test/core/network/storage_interceptor_test.dart`, `test/core/network/api_error_mapper_test.dart`, `test/core/storage/secure_storage_test.dart`, `test/core/storage/keychain_smoke_app.dart` |
| Инструкции | [Окружение](../development/ENVIRONMENT.ru.md), [тестирование](../testing/README.ru.md) |
| Учёт | Этот active-plan, [PLAN-FE-001](plans/PLAN-FE-001.md), `docs/ai/tasks/TASK-FE-001.01.md`–`TASK-FE-001.07.md`; .01/.02 только принятие владельцем |
| Независимые review | `docs/ai/reviews/REVIEW-FE-001.03-01.md`, `REVIEW-FE-001.04-02.md`, `REVIEW-FE-001.05-01.md`, `REVIEW-FE-001.06-01.md`, `REVIEW-FE-001.07-01.md` |

Backend snapshots, backend repo, feature clients/DTO, зависимости и чужой settings
не менялись. `python3 /tmp/dictai-foundation-03-07-20261026/check_docs.py` — PASS:
51 уникальный ID, таблица/карточки/depends_on согласованы, cycles=0, unordered shared
writers=0; 728 локальных ссылок, 6 anchors и 14 source bounds разрешаются.
Из 173 прежних frontend-файлов изменены только 19 разрешённых, 154 остальных
побайтово сохранены; добавлены 17 разрешённых файлов. Все 589 backend-файлов и оба
HEAD прежние; BACKEND_* копии идентичны исходным документам. Полный scoped diff,
новые файлы/no-index whitespace, conflict/credential patterns — PASS; временные
логи/manifest находятся вне репозитория, Podfile.lock восстановлен к baseline.
Git branch main и HEAD прежние, staging пуст, commit/push/merge не выполнялись.

Следующий рекомендуемый набор после приёмки .05/.06/.07 и отдельного выбора:
.10/.18/.21/.22/.26. Они не зависят от .04; .08/.15/.20 ждут её полного evidence.
Рекомендация не разрешает реализацию. Вне выбранных .03–.07 работа не начинается.

## История планирования (не текущее разрешение)

# Текущий этап: актуализация PLAN-FE-001 по окончательному UX

Обновлено: 2026-10-26. Выбрана только актуализация документации планирования.
Implementation-задачи этим поручением не выбраны. Coordinator/writer — primary-agent;
backend, код, dependencies и обе реализованные карточки .01/.02 read-only.
Baseline frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. Посторонний settings сохранён.

План актуализирован: **51 задача, A=24/B=22/C=5**; review=2, draft=44, blocked=5,
ready/accepted=0. Из прежних 42 карточек дополнена 31; .01/.02 и ещё 9 карточек
сохранены. Новые .43–.49 — локальные/UI работы; .50/.51 — blocked server
assignments/named export. Подробные цели: [UX](research/FRONTEND_TARGET_UX.ru.md),
[backend requests](research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[план](plans/PLAN-FE-001.md), ADR-FE-007 в [decisions](decisions.md).

Backend authoritative persistence/исторические contact snapshots/несколько Speaker
на contact и четыре применимых named TXT/PDF — target, ещё без backend API.
Mock только test/dev и внутренняя модель, production fallback запрещён.
Marker canonical-ready согласован; summary не gate, Stop/leave требуют подтверждения.
Первые кандидаты после явной приёмки уже реализованной .01: .03/.04/.06;
последующие task ID не выбраны. Полный порядок и точные scopes — в плане/карточках.

Scope записи: PLAN-FE-001, затронутые TASK-FE-001.03–.42, два FRONTEND_* UX/BR
исследования, decisions, этот реестр, новые .43–.51 и один review-отчёт.
BACKEND_* снимки не меняются. Независимый reviewer исследует всё read-only;
его единственный write path — зарезервированный REVIEW-FE-001.01-05 ниже.

## Резервирование новых ID текущего прохода

ID сверены с основным реестром ниже и двумя foundation worktrees; .01/.02
реализованы и опубликованы в main, status review и их evidence сохраняются.
Новые номера последовательно зарезервированы до создания и review-делегирования.

| ID | Путь | Owner | Состояние резерва |
|---|---|---|---|
| TASK-FE-001.43 | [tasks/TASK-FE-001.43.md](tasks/TASK-FE-001.43.md) | unassigned | created |
| TASK-FE-001.44 | [tasks/TASK-FE-001.44.md](tasks/TASK-FE-001.44.md) | unassigned | created |
| TASK-FE-001.45 | [tasks/TASK-FE-001.45.md](tasks/TASK-FE-001.45.md) | unassigned | created |
| TASK-FE-001.46 | [tasks/TASK-FE-001.46.md](tasks/TASK-FE-001.46.md) | unassigned | created |
| TASK-FE-001.47 | [tasks/TASK-FE-001.47.md](tasks/TASK-FE-001.47.md) | unassigned | created |
| TASK-FE-001.48 | [tasks/TASK-FE-001.48.md](tasks/TASK-FE-001.48.md) | unassigned | created |
| TASK-FE-001.49 | [tasks/TASK-FE-001.49.md](tasks/TASK-FE-001.49.md) | unassigned | created |
| TASK-FE-001.50 | [tasks/TASK-FE-001.50.md](tasks/TASK-FE-001.50.md) | unassigned | created |
| TASK-FE-001.51 | [tasks/TASK-FE-001.51.md](tasks/TASK-FE-001.51.md) | unassigned | created |
| REVIEW-FE-001.01-05 | [reviews/REVIEW-FE-001.01-05.md](reviews/REVIEW-FE-001.01-05.md) | /root/review_fe_plan_ux_final | created |

## Результат актуализации — 2026-10-26

- PASS: `python3 /tmp/dictai-plan-ux-20261026/check_docs.py`, cwd frontend,
  macOS/Python stdlib/Ruby YAML/Git: 51 уникальный ID, 24/22/5 и 2/44/5;
  таблица/DAG/карточки согласованы, циклов и unordered shared writers нет.
- PASS: own Markdown links/anchors/source bounds, существующие/planned paths,
  UX-01…19 и contract boundaries; .35–.38 не ждут будущих .50/.51, прежняя .28→.30
  и Keychain scope .04 сохранены. Новые endpoint/JSON contracts не выдуманы.
- PASS: `git diff --check`, полный tracked и no-index diff новых документов и
  прежних untracked UX/BR к baseline; whitespace diagnostics=0, staging пуст.
- PASS: SHA-256 всех 163 прежних frontend-файлов — изменены только 36 разрешённых
  документов, 127 остальных, включая приложение/.01/.02/dependencies/settings,
  неизменны. Добавлены девять карточек и отдельный review; оба HEAD и все 589
  backend-файлов прежние. BACKEND_* byte-identical origin и baseline.
- PASS: новый независимый `/root/review_fe_plan_ux_final` завершил полный review,
  REVIEW-FE-001.01-05 reviewed/complete, открытых actionable findings P0–P3 нет.
  Reviewer проверил все 51 карточку и реальные source; исходные .01/.02 не переоткрыты.
- NOT RUN: Flutter/native/backend/model/player/export runtime checks — нет реализации.
  Прежние baseline FAIL и backend/security/release gates сохранены, mocks не production.

Из прежних задач изменена 31, созданы 9, всего 51. Review не означает accepted.
Текущее поручение завершает планирование; implementation не начинается без
следующего явного выбора пользователя. Commit/push/merge не выполнялись.

## История foundation-этапа (не текущее разрешение)

Обновлено: 2026-10-25. Пользователь выбрал TASK-FE-001.01 и TASK-FE-001.02,
затем отдельно поручил объединить и опубликовать обе реализации в `main`.
Исходный план `fdd95eb` уже опубликован в `origin/main`. Реализации подготовлены
от этой базы: .01 — `8cc1906`, .02 — `865e0a1`; coordinator — primary-agent.
PLAN-FE-001 in_progress, selected_tasks=[TASK-FE-001.01, TASK-FE-001.02].
Остальные 40 задач не выбраны. Backend не меняется, accepted не выставляется.

## Результат и категории

Созданы [source-аудит](research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md) и **42 задачи**:
**A=23, B=16, C=3**. Статусы: review=2, ready=0, draft=37, blocked=3.
A — локальная основа/существующий wire, B — сквозной UI/state с mocks по известным
DTO, C — внешние backend/operator gates. Категория не отменяет FE depends_on.

| Этап | Содержание | Task suffix |
|---|---|---|
| 0 | Основа: SDK, секреты, storage, config, безопасные errors/tests | 01–07 |
| 1 | Auth, workspace/contacts и удаление profile coupling | 08–14 |
| 2 | Capture, WAV/V2, journal, status/canonical data и оба upload UX | 15–25 |
| 3 | Library/detail/transcript, export/delete, retirement/isolation | 26–34 |
| 4 | Regression suite, macOS/Linux verification, integration harness | 35–38 |
| 5 | Реальный backend gate/E2E, release candidate и приёмка | 39–42 |

## Выбор следующих задач

В `main` интегрируются выбранные .01 и .02; обе остаются review до явной
приёмки пользователя. Зависимости обеих пусты; следующие задачи не выбраны.
Рекомендуемые первые семь по порядку:

- [TASK-FE-001.01](tasks/TASK-FE-001.01.md): Согласовать и воспроизвести Flutter/Dart toolchain; review, owner primary-agent, prerequisites none.
- [TASK-FE-001.02](tasks/TASK-FE-001.02.md): Удалить значения секретов из tracked-конфигурации; review, owner primary-agent, prerequisites none.
- [TASK-FE-001.03](tasks/TASK-FE-001.03.md): Ограничить HTTP-логирование и редактировать чувствительные данные; draft, prerequisites 01.
- [TASK-FE-001.04](tasks/TASK-FE-001.04.md): Перевести session storage на защищённое хранилище; draft, prerequisites 01.
- [TASK-FE-001.05](tasks/TASK-FE-001.05.md): Настроить явную конфигурацию gateway и сетевых политик; draft, prerequisites 01, 02, 03.
- [TASK-FE-001.06](tasks/TASK-FE-001.06.md): Подготовить тестовую основу без сети и аппаратуры; draft, prerequisites 01.
- [TASK-FE-001.07](tasks/TASK-FE-001.07.md): Унифицировать безопасную обработку HTTP и транспортных ошибок; draft, prerequisites 03, 05, 06.

Перед исполнением пользователь выбирает ID; coordinator назначает owner.
Непринятые prerequisites и backend evidence не выполняются автоматически.
После реализации нужны checks и независимое review кода; review плана его не заменяет.

## Scope выбранной реализации и координация

- `.01`: `pubspec.yaml`, `pubspec.lock`, `docs/development/TOOLCHAIN.ru.md`,
  `docs/ai/tasks/TASK-FE-001.01.md`; worktree
  `/Users/verliiar/.codex/worktrees/fe-001-01-toolchain/Desktop_application`.
- `.02`: `.vscode/launch.json`, `.gitignore`, `.vscode/launch.example.json`,
  `docs/development/SECRETS.ru.md`, `docs/ai/tasks/TASK-FE-001.02.md`; worktree
  `/Users/verliiar/.codex/worktrees/fe-001-02-secrets/Desktop_application`.
- Обе реализации подготовлены primary-agent последовательно; только coordinator
  объединяет общие PLAN/active-plan и уточняет publication-записи двух карточек.
  При интеграции конфликты возникли только в PLAN/active-plan; сохранены обе
  карточки, оба implementation review и результаты каждой задачи.
- REVIEW-FE-001.01-03 и REVIEW-FE-001.02-01 завершены независимым
  /root/review_fe_foundation_01_02 в своих worktrees, reviewed/complete.
  Reviewer изменил только два назначенных отчёта; actionable findings нет.
- Commit/push/интеграция в main разрешены последним прямым поручением пользователя.
  Это разрешение не принимает задачи и не разрешает release или следующие задачи.
  Исторические записи о запрете публикации и GitHub 403 ниже описывают прежний этап.
- REVIEW-FE-001.01-04 зарезервирован до делегирования и завершён отдельным
  /root/review_fe_01_02_integration: reviewed/complete, новых findings нет.
  Проверены итоговый diff к опубликованному `fdd95eb` и общие записи.
  Единственный write path reviewer — новый отчёт; код/конфигурация read-only.

## Результаты выбранных карточек

Локальная .01 подготовлена и прошла
[независимый review REVIEW-FE-001.01-03](reviews/REVIEW-FE-001.01-03.md).
Status остаётся review: пользователь ещё не принял результат, accepted нет.
Flutter 3.41.3/Dart 3.11.1 проверен; pub get --enforce-lockfile PASS,
137 packages и lock неизменны. Исходный analyze FAIL (13 info), test FAIL
(пустой widget_test без main) и format FAIL (42/32) воспроизведены reviewer.
Приложение не объявлено verified, следующие зависимости не приняты.
Инструкция — [TOOLCHAIN.ru.md](../development/TOOLCHAIN.ru.md).

Локальная .02 подготовлена и прошла
[независимый review REVIEW-FE-001.02-01](reviews/REVIEW-FE-001.02-01.md).
Status остаётся review: пользователь ещё не принял результат, accepted нет.
Credential/model defines удалены из текущего дерева интеграции; JSON, scan и
ignore checks PASS. Source/API/DTO/dependency graph не менялись. Credential остаётся
в Git history и исходной toolchain-ветке; владелец отдельно выполняет revoke/rotation. Без его
evidence security release gate .42 остаётся открыт.
Инструкция — [SECRETS.ru.md](../development/SECRETS.ru.md).

Кроме явно выбранных изменений, прежние tracked files и весь backend сохранены.
Появившийся во время работы
посторонний untracked `.vscode/settings.json` в primary checkout не менялся
и не входит в задачи. Diff, scopes/42-card DAG и ссылки проверены.
Обе реализации сохранены отдельными локальными коммитами. Итоговый merge и push
в main будут выполнены после проверок и независимого integration review.

## Проверки объединения перед публикацией

[REVIEW-FE-001.01-04](reviews/REVIEW-FE-001.01-04.md) — полный независимый review
итогового diff: новых actionable findings нет. Implementation-файлы и оба
предыдущих отчёта побайтово совпадают с коммитами своих задач; при интеграции
добавлено только согласование общих документов и publication-записей карточек.

- PASS: 42 уникальные карточки; selected только .01/.02; review=2, draft=37,
  blocked=3, ready/accepted=0. YAML/таблица/owners/dependencies совпадают,
  cycles=0, unordered shared writers=0. Следующие задачи не разблокированы.
- PASS: 502 собственные локальные ссылки до добавления integration review;
  current-tree credential scan 159 файлов, findings=0 и копий исходного ключа=0;
  JSON/16 ignore cases и whitespace независимо проверены reviewer.
- Первый coordinator link-helper ошибочно считал суффикс `:line` частью имени
  файла; helper исправлен, повторная проверка ссылок PASS. Документы ради обхода
  этой ошибки не менялись.
- PASS: нет оставшихся conflict markers/unmerged paths; другие прежние tracked
  файлы, lock и dependency graph сохранены. Посторонний settings исключён.
- NOT RUN повторно: Flutter/native/backend/provider checks. Bytes реализации
  идентичны проверенным веткам; исходные analyze/test/format FAIL и открытый
  revoke gate сохранены. Integration review не является приёмкой задач.

Финальная проверка staged-состава и подтверждение удалённого SHA выполняются
coordinator при создании merge commit и push. Публикация разрешена пользователем;
release, rewrite истории и остальные задачи не разрешены.

## Backend-срез и блокировки

Код backend `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`, frontend
`b45c8c4dfe927a872182c7508fa85e01f83a9f0c`.
[API snapshot](research/BACKEND_API_CONTRACTS.ru.md) и
[target snapshot](research/BACKEND_TARGET_SCOPE.ru.md) сохранены побайтово;
их SHA-256/правила ссылок — в истории и [architecture](architecture.md).
Backend развивается: учитывать реализованные и согласованные будущие функции,
но не представлять design/open questions как готовые API.

- .39 backend accepted только limited RU scope; полный dataset/baseline/gates .29
  и CPU acceptance .17 не готовы.
- .24/.31 backend blocked, нужны staging/rollout evidence и in-flight policy.
- FE .39 blocked: test-origin/accounts/runtime и вопросы workspace access.
  FE .40 blocked: backend .17/.24, стенд и platform evidence.
  FE .42 blocked: FE E2E/candidate, backend .31, security evidence и приёмка.
- .18 GPU/.19 runtime не блокируют CPU frontend. .21 design-only не даёт live API.
  Profiles/confirm/legacy исключены. Chat/sharing/cancel/reprocess и другие
  неподтверждённые возможности не включены в обязательный batch backlog.

Открыты: точный SDK/Linux hosts/audio prerequisites, test URL/TLS/operator,
остаток full dataset, workspace/contact authorization, судьба старых jobs/results,
локальная quota/retention, combined pause policy и release signing/version.
Неизвестные API/task IDs не придумывать. Детали/условия C — в карточках и плане.

## Реестр ID

Coordinator последовательно зарезервировал новые ID до создания файлов.
Все перечисленные документы теперь созданы; reserved → created не означает
accepted. Task owner остаётся unassigned до выбора. Существующий setup review
сохранён, FE номера не переиспользуются.

| ID | Путь | Owner | Состояние резерва |
|---|---|---|---|
| PLAN-FE-001 | [plans/PLAN-FE-001.md](plans/PLAN-FE-001.md) | primary-agent | created |
| TASK-FE-001.01 | [tasks/TASK-FE-001.01.md](tasks/TASK-FE-001.01.md) | primary-agent | created |
| TASK-FE-001.02 | [tasks/TASK-FE-001.02.md](tasks/TASK-FE-001.02.md) | primary-agent | created |
| TASK-FE-001.03 | [tasks/TASK-FE-001.03.md](tasks/TASK-FE-001.03.md) | unassigned | created |
| TASK-FE-001.04 | [tasks/TASK-FE-001.04.md](tasks/TASK-FE-001.04.md) | unassigned | created |
| TASK-FE-001.05 | [tasks/TASK-FE-001.05.md](tasks/TASK-FE-001.05.md) | unassigned | created |
| TASK-FE-001.06 | [tasks/TASK-FE-001.06.md](tasks/TASK-FE-001.06.md) | unassigned | created |
| TASK-FE-001.07 | [tasks/TASK-FE-001.07.md](tasks/TASK-FE-001.07.md) | unassigned | created |
| TASK-FE-001.08 | [tasks/TASK-FE-001.08.md](tasks/TASK-FE-001.08.md) | unassigned | created |
| TASK-FE-001.09 | [tasks/TASK-FE-001.09.md](tasks/TASK-FE-001.09.md) | unassigned | created |
| TASK-FE-001.10 | [tasks/TASK-FE-001.10.md](tasks/TASK-FE-001.10.md) | unassigned | created |
| TASK-FE-001.11 | [tasks/TASK-FE-001.11.md](tasks/TASK-FE-001.11.md) | unassigned | created |
| TASK-FE-001.12 | [tasks/TASK-FE-001.12.md](tasks/TASK-FE-001.12.md) | unassigned | created |
| TASK-FE-001.13 | [tasks/TASK-FE-001.13.md](tasks/TASK-FE-001.13.md) | unassigned | created |
| TASK-FE-001.14 | [tasks/TASK-FE-001.14.md](tasks/TASK-FE-001.14.md) | unassigned | created |
| TASK-FE-001.15 | [tasks/TASK-FE-001.15.md](tasks/TASK-FE-001.15.md) | unassigned | created |
| TASK-FE-001.16 | [tasks/TASK-FE-001.16.md](tasks/TASK-FE-001.16.md) | unassigned | created |
| TASK-FE-001.17 | [tasks/TASK-FE-001.17.md](tasks/TASK-FE-001.17.md) | unassigned | created |
| TASK-FE-001.18 | [tasks/TASK-FE-001.18.md](tasks/TASK-FE-001.18.md) | unassigned | created |
| TASK-FE-001.19 | [tasks/TASK-FE-001.19.md](tasks/TASK-FE-001.19.md) | unassigned | created |
| TASK-FE-001.20 | [tasks/TASK-FE-001.20.md](tasks/TASK-FE-001.20.md) | unassigned | created |
| TASK-FE-001.21 | [tasks/TASK-FE-001.21.md](tasks/TASK-FE-001.21.md) | unassigned | created |
| TASK-FE-001.22 | [tasks/TASK-FE-001.22.md](tasks/TASK-FE-001.22.md) | unassigned | created |
| TASK-FE-001.23 | [tasks/TASK-FE-001.23.md](tasks/TASK-FE-001.23.md) | unassigned | created |
| TASK-FE-001.24 | [tasks/TASK-FE-001.24.md](tasks/TASK-FE-001.24.md) | unassigned | created |
| TASK-FE-001.25 | [tasks/TASK-FE-001.25.md](tasks/TASK-FE-001.25.md) | unassigned | created |
| TASK-FE-001.26 | [tasks/TASK-FE-001.26.md](tasks/TASK-FE-001.26.md) | unassigned | created |
| TASK-FE-001.27 | [tasks/TASK-FE-001.27.md](tasks/TASK-FE-001.27.md) | unassigned | created |
| TASK-FE-001.28 | [tasks/TASK-FE-001.28.md](tasks/TASK-FE-001.28.md) | unassigned | created |
| TASK-FE-001.29 | [tasks/TASK-FE-001.29.md](tasks/TASK-FE-001.29.md) | unassigned | created |
| TASK-FE-001.30 | [tasks/TASK-FE-001.30.md](tasks/TASK-FE-001.30.md) | unassigned | created |
| TASK-FE-001.31 | [tasks/TASK-FE-001.31.md](tasks/TASK-FE-001.31.md) | unassigned | created |
| TASK-FE-001.32 | [tasks/TASK-FE-001.32.md](tasks/TASK-FE-001.32.md) | unassigned | created |
| TASK-FE-001.33 | [tasks/TASK-FE-001.33.md](tasks/TASK-FE-001.33.md) | unassigned | created |
| TASK-FE-001.34 | [tasks/TASK-FE-001.34.md](tasks/TASK-FE-001.34.md) | unassigned | created |
| TASK-FE-001.35 | [tasks/TASK-FE-001.35.md](tasks/TASK-FE-001.35.md) | unassigned | created |
| TASK-FE-001.36 | [tasks/TASK-FE-001.36.md](tasks/TASK-FE-001.36.md) | unassigned | created |
| TASK-FE-001.37 | [tasks/TASK-FE-001.37.md](tasks/TASK-FE-001.37.md) | unassigned | created |
| TASK-FE-001.38 | [tasks/TASK-FE-001.38.md](tasks/TASK-FE-001.38.md) | unassigned | created |
| TASK-FE-001.39 | [tasks/TASK-FE-001.39.md](tasks/TASK-FE-001.39.md) | unassigned | created |
| TASK-FE-001.40 | [tasks/TASK-FE-001.40.md](tasks/TASK-FE-001.40.md) | unassigned | created |
| TASK-FE-001.41 | [tasks/TASK-FE-001.41.md](tasks/TASK-FE-001.41.md) | unassigned | created |
| TASK-FE-001.42 | [tasks/TASK-FE-001.42.md](tasks/TASK-FE-001.42.md) | unassigned | created |
| REVIEW-FE-001.01-01 | [reviews/REVIEW-FE-001.01-01.md](reviews/REVIEW-FE-001.01-01.md) | independent-reviewers; запись coordinator | created |
| REVIEW-FE-001.01-02 | [reviews/REVIEW-FE-001.01-02.md](reviews/REVIEW-FE-001.01-02.md) | /root/review_fe_plan_full_v2 | created |
| REVIEW-FE-001.04-01 | [reviews/REVIEW-FE-001.04-01.md](reviews/REVIEW-FE-001.04-01.md) | /root/review_fe_plan_full_v2 | created |
| REVIEW-FE-SETUP-01 | [reviews/REVIEW-FE-SETUP-01.md](reviews/REVIEW-FE-SETUP-01.md) | previous bootstrap reviewer | created |
| REVIEW-FE-001.01-03 | [reviews/REVIEW-FE-001.01-03.md](reviews/REVIEW-FE-001.01-03.md) | /root/review_fe_foundation_01_02 | created |
| REVIEW-FE-001.02-01 | [reviews/REVIEW-FE-001.02-01.md](reviews/REVIEW-FE-001.02-01.md) | /root/review_fe_foundation_01_02 | created |
| REVIEW-FE-001.01-04 | [reviews/REVIEW-FE-001.01-04.md](reviews/REVIEW-FE-001.01-04.md) | /root/review_fe_01_02_integration | created |

## История корректировки F01 P2 — 2026-10-25

Пользователь выбрал только исправление документации по F01 из
[REVIEW-FE-001.01-02](reviews/REVIEW-FE-001.01-02.md). Coordinator — writer
`tasks/TASK-FE-001.04.md`, `plans/PLAN-FE-001.md` и этого active-plan.
Независимый reviewer `/root/review_fe_plan_full_v2`, не писавший исправление,
завершил отдельный [REVIEW-FE-001.04-01](reviews/REVIEW-FE-001.04-01.md),
reviewed/complete. Его единственное изменение — этот новый отчёт.
Предыдущие отчёты сохранены.

- В будущий scope .04 добавлены оба существующих macOS entitlements для
  минимального Keychain setup и planned smoke entry point без новых зависимостей,
  backend или настоящих credentials. Уточнены criteria и будущие Debug/Release
  проверки реального storage; .36 остаётся итоговой regression-проверкой.
- Проверены реальные plist, назначения Xcode и README lock-версии. Изменять
  entitlements, подпись, зависимости или функциональный код сейчас не разрешено.
- Граф проверен по всем 42 карточкам: cycles=0, unordered shared writers=0,
  A/B/C=23/16/3; статусы прежние. Оба entitlements имеют writers .04 → .16,
  существующая цепочка .04 → .15 → .16 достаточна, depends_on не изменены.
- Авторские проверки ссылок, YAML/scopes и согласованности DAG/table пройдены.
  Полный no-index diff трёх файлов относительно fresh baseline изучен, whitespace
  diagnostics отсутствуют. SHA-256: изменены только эти три документа; остальные
  150 прежних frontend-файлов и все 589 backend-файлов совпадают с baseline.
  HEAD/staging прежние; Flutter/build/native smoke сейчас NOT RUN (только планирование).

F01 после независимой повторной проверки имеет disposition **fixed with evidence
только на уровне планирования**; новых actionable findings нет. Это не проверка
работающего Keychain или реализации .04. Исправление готово к приёмке пользователем;
старый отчёт хранит исторический open finding, а новый — evidence его исправления.
.04 не реализуется, все implementation criteria unchecked; plan draft,
task draft/unassigned, selected_tasks=[], accepted отсутствует.

## Полный независимый review — 2026-10-25, до исправления F01

По отдельному поручению пользователя новый reviewer `/root/review_fe_plan_full_v2`,
не участвовавший в создании или исправлении плана, завершил полную проверку
актуального PLAN-FE-001 и всех 42 карточек. Результат —
[REVIEW-FE-001.01-02](reviews/REVIEW-FE-001.01-02.md), status reviewed,
completion complete. Его единственный write scope — этот новый отчёт;
coordinator изменяет только active-plan. План, задачи, предыдущий отчёт,
snapshots, приложение и backend сохранены без изменений.

- Подтверждены API/target coverage, категории A=23/B=16/C=3, согласованность
  DAG/таблицы/карточек, отсутствие циклов и порядок общих write scopes.
- Прежний finding .28 → .30 независимо перепроверен: исправление корректно.
  Старый partial-отчёт сохранён как исторический, новый проход завершён полностью.
- Открыт один новый P2, F01: scope .04 не назначает обязательный macOS Keychain
  setup в обоих entitlements для используемой версии secure storage. Исправления
  автоматически не выполнялись. До полной приёмки reviewer рекомендует решить
  F01 и независимо проверить выбранное исправление; .01/.02 можно выбрать отдельно.
- Выполнены статические проверки документации/графа/ссылок и сверка исходников;
  Flutter/native/runtime проверки не запускались. Полные evidence и ограничения
  приведены в отчёте. Review плана не подтверждает будущую реализацию.
- Итоговая проверка coordinator: PASS — YAML отчёта содержит все 42 task ID,
  status reviewed/completion complete; 485 локальных Markdown-ссылок без ошибок;
  полные no-index diff и whitespace двух файлов без diagnostics. SHA-256 baseline:
  из прежних 152 frontend-файлов изменён только active-plan, добавлен новый отчёт;
  остальные 151 файл и все 589 backend-файлов неизменны. План, 42 карточки,
  snapshots и функциональный код не менялись; HEAD и staging обоих repos прежние.

Статусы плана/задач не изменены; selected_tasks=[]; accepted не выставлен.
Приёмка, выбор исправления F01 и выбор implementation-задач остаются за пользователем.

## Предыдущий scope и проверки планирования — 2026-10-24

Primary-agent — единственный writer: этот active-plan, PLAN-FE-001, 42 карточки,
FRONTEND_BACKEND_GAP_ANALYSIS и REVIEW-FE-001.01-01. Независимые reviewers read-only;
findings сохраняет coordinator. Общие code paths будущих задач упорядочены DAG,
не разрешают параллельную запись. Весь backend, BACKEND_* copies, AGENTS/templates,
architecture/decisions и функциональные файлы исключены из текущего diff.

- PASS: первичная Ruby YAML/schema проверка 42 ID, статусов/категорий, existence
  depends_on, отсутствие cycles, явные planned_paths и backend task traceability.
- PASS: нет общих write paths у задач без порядка ancestry в DAG.
- PASS: 472 собственные frontend Markdown-ссылки, source/API mapping 23 mandatory
  batch operations, planned/source paths, полный diff/whitespace 46 файлов проверены.
- PASS: 106 прежних frontend-файлов и все 589 backend-файлов неизменны;
  изменён только active-plan, добавлены 45 planning-документов. Код/API/DTO,
  зависимости, snapshots и HEAD обоих репозиториев не менялись.
- PARTIAL: оба независимых reviewers нашли P2 — .28 не зависела от .30 для
  summary.txt. Исправлено в карточке, DAG и таблице; повторный self-check PASS.
  Оба reviewer затем остановились по account usage limit. Полный review и
  независимый delta review не завершены; запись в REVIEW-FE-001.01-01 остаётся open.
  План подготовлен, но planning-этап целиком завершённым/независимо проверенным
  не объявляется. Нужно закончить review после восстановления доступности reviewer.
- NOT RUN: Flutter format/analyze/test/build, capture/OS storage/real API/model tests;
  сейчас только документация. Команды карточек — будущий Verification, не PASS.
- План и задачи не implemented/verified/accepted. Commit/push/merge/release не разрешены.

## История предыдущего переноса backend-снимков

Ниже сохранено предыдущее поручение с его scope и evidence. Его запреты на создание
плана и старое состояние реестра не заменяют текущий явный planning scope.

Обновлено: 2026-10-24. Текущее поручение — перенести два backend-исследования
без изменения содержимого и подготовить документационный контекст для следующего
этапа планирования адаптации frontend. Продуктовый план и задачи сейчас не создаются.

### Выбранный scope

- Побайтовые копии [BACKEND_API_CONTRACTS.ru.md](research/BACKEND_API_CONTRACTS.ru.md)
  и [BACKEND_TARGET_SCOPE.ru.md](research/BACKEND_TARGET_SCOPE.ru.md).
- Этот active-plan и ссылки/правила чтения снимков в
  [architecture.md](architecture.md).
- Проверки SHA-256, согласованности, ссылок, diff и неизменности приложения/backend;
  независимый read-only review с findings координатору, без нового review-файла.

Owner текущего документационного scope — primary-agent. Другим агентам запись
не назначается. Код, API-клиенты, DTO, зависимости, платформенные файлы и backend
исключены из записи. Новые PLAN/TASK/review ID не выдаются, commit/push не разрешены.

### Источники backend и состояние разработки

Исходный backend: `/Users/verliiar/phiziks_pr`. Исследованный backend commit SHA:
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. Дата обоих исследований — 2026-10-24.
Оба документа имеют статус `researched`, не являются приёмкой frontend и не
доказывают production readiness. Исходные Markdown-файлы пока untracked в backend:
SHA обозначает исследованный код, а тождество самих копий определяется SHA-256.

| Копия во frontend | Исходный файл относительно корня backend | SHA-256 исходника и копии |
|---|---|---|
| [BACKEND_API_CONTRACTS.ru.md](research/BACKEND_API_CONTRACTS.ru.md) | `docs/ai/research/FRONTEND_API_CONTRACTS.ru.md` | `bb1cf337461350afb6600b5903757bd27027c9ec46aa080bf7e6cc7c43350d74` |
| [BACKEND_TARGET_SCOPE.ru.md](research/BACKEND_TARGET_SCOPE.ru.md) | `docs/ai/research/FRONTEND_TARGET_SCOPE.ru.md` | `a508f60326f68d73e65fa5791ea2acbbd6deea0fda4dba97b9a8a3e0e2b11478` |

Backend продолжает активно разрабатываться. При планировании frontend нужно
учитывать фактические операции из API-документа и согласованное целевое поведение,
включая незавершённые backend-задачи из target scope. Возможность в дизайне,
незавершённая проверка или открытый вопрос не равны реализованному API.

Ключевые границы снимка:

- 25 клиентских HTTP-операций реализованы в коде, часть требует runtime/config
  prerequisites; это не подтверждение работающего deployment.
- Target scope различает batch-продукт, незавершённые quality/cutover этапы,
  будущий live-дизайн и возможности без утверждённых контрактов.
- TASK-002.39 принята только в ограниченном RU scope; полный benchmark и gates
  не закрыты. TASK-002.18 — review; TASK-002.21 — design-only draft.
- Голосовые профили и обязательный confirm исключены целевым backend, но текущий
  frontend ещё описывается отдельно в architecture.md. Сравнение пока не выполнено.

Содержимое копий, их frontmatter, исходные имена и относительные ссылки сохранены.
Ссылки внутри копий относятся к backend, даже если одноимённый frontend-файл
существует. Правила разрешения ссылок и соответствие переименованных документов
зафиксированы в architecture.md. Исторические Verification внутри копий не
являются результатами текущего переноса.

Для автономного предварительного планирования достаточно двух локальных копий,
карты текущего frontend и AGENTS.md. Для проверки исходного evidence, обновления
среза и реализации API-зависимых задач потребуется актуальный backend-контекст.
Не утверждать готовность отсутствующих контрактов и не восстанавливать их догадками.

### Следующий этап

Сравнить текущий Flutter/Dart frontend с целевым backend, затем создать план
адаптации и атомарные frontend-задачи с зависимостями, file scope, acceptance
criteria и Verification. Разделить готовое к реализации, работу с mock-данными
по существующим контрактам и работу, ожидающую backend/решений.

Это следующий этап по отдельному поручению. В текущем scope сравнение, план,
task-карточки и резервирование их ID не выполняются. Реализация будущего плана
потребует явного выбора пользователя по WORKFLOW.md. Перед ней нужно сверить
изменившиеся backend-задачи/контракты с зафиксированным SHA.

### Проверки текущего переноса

- PASS: Python 3 stdlib, byte comparison/SHA-256 — обе пары совпадают с таблицей
  выше; в обеих копиях тот же backend SHA. Согласованность current/target проверена:
  25 реализованных операций отделены от незавершённых этапов и открытых вопросов.
- PASS: проверены 34 ссылки всей собственной frontend AI-документации и 197
  source-ссылок копий с backend-базой, включая диапазоны #L. Сохранённые ссылки
  не считаются обычной frontend-навигацией: 188 не разрешаются локально, ещё 9
  могут попасть в одноимённые frontend-файлы; architecture явно задаёт контекст.
- PASS: полный no-index diff четырёх файлов и `git diff --check`, без whitespace
  diagnostics; `git diff --no-index --check -- /dev/null <file>` в этой среде
  возвращает 1 для нового untracked-файла без сообщений об ошибках whitespace.
- PASS: SHA-256 baseline — во frontend изменены только два указателя и добавлены
  две копии; остальные 103 существовавших файла (включая все 91 tracked) неизменны.
  Backend: 589/589 существовавших файлов неизменны, добавлений нет, HEAD прежний.
- PASS: независимый read-only review `/root/review_backend_snapshot_import`: содержательных
  findings нет; подтверждены равенство копий, ссылки, 20 JSON-примеров и достаточность
  контекста для автономного предварительного плана. P3 о лишней пустой строке в EOF
  active-plan исправлен; повторная whitespace-проверка и delta review PASS, новых
  findings нет. Reviewer подтвердил ссылки/копии самостоятельно; исходный baseline
  103/589 файлов учитывает как evidence автора, а не собственный повторный запуск.
- NOT RUN: Flutter format/analyze/test/build, backend/runtime tests — меняется только документация.

Проверки выполнены из корня frontend, backend использован только для чтения.
Для файлов, которые до поручения уже были untracked, сохранён baseline в памяти
прохода; diff проверяется и целиком, и относительно исходного содержания указателей.
Staging пуст; commit/push/merge/release не выполнялись. Продуктовый план и task-карточки
не созданы. Проверки и review не означают явную приёмку пользователем.

### История: подготовка AI-документации frontend

Ниже сохранены scope и evidence предыдущего bootstrap-этапа. Они не означают
новую приёмку и не заменяют проверки переноса выше.

#### Предыдущий выбранный scope

- Корневой AGENTS.md и документация docs/ai.
- Шаблоны планов, задач и независимого review; правила координации.
- Проверка документации и подтверждение неизменности функционального кода.

Продуктовые планы и task-карточки на bootstrap-этапе не создавались. Примеры
PLAN-FE-001/TASK-FE-001.01 в шаблонах не резервируют ID.

### Реестр выданных ID

Реестр меняет только координатор. Состояния резерва: reserved, created, retired.
Это отдельные состояния учёта ID; они не заменяют task status.

| ID | Путь | Owner | Состояние резерва |
|---|---|---|---|
| REVIEW-FE-SETUP-01 | [reviews/REVIEW-FE-SETUP-01.md](reviews/REVIEW-FE-SETUP-01.md) | /root/review_frontend_ai_setup; запись координатором | created |

Выдан только bootstrap review. PLAN/TASK ID пока не выданы.

### История областей записи bootstrap

| Работа | Owner | Write scope | Состояние |
|---|---|---|---|
| Bootstrap AI-документации | primary-agent | AGENTS.md, docs/ai/** | документация подготовлена; проверки и независимый review выполнены; ожидает приёмки |

Независимый reviewer работал read-only; отчёт сохранил координатор. Активная
параллельная запись завершена; новые области не назначены. Функциональный код
и соседний backend исключены из записи.

### Проверки и приёмка bootstrap

- PASS: структура, Markdown-ссылки, пути, примеры будущих ID и согласованность статусов.
- PASS: YAML frontmatter шаблонов (Ruby YAML, без установки зависимостей).
- PASS: полный no-index diff новых файлов и whitespace; обычный diff не скрывает
  проверку untracked-документов, они проверены отдельно.
- PASS: контрольные суммы всех 91 исходного tracked-файла совпали до/после;
  функциональный код, API-клиенты, зависимости и платформенные файлы неизменны.
- PASS: значения ключей не скопированы в новые документы; сами значения не выводятся.
- Независимый [review](reviews/REVIEW-FE-SETUP-01.md): actionable findings не обнаружены.
- NOT RUN: Flutter format/analyze/test/build и backend API — вне документационного scope.
- Commit/push/merge/release не выполнялись; staging пуст. Новые документы оставлены
  untracked для просмотра пользователем.

Система подготовлена и проверена в указанном scope. До явного ответа пользователя
приёмка не заявляется; принятых продуктовых задач нет. Подробные evidence и
ограничения сохранены в review-отчёте.
