# Текущий этап: выполнение foundation-задачи .02

Обновлено: 2026-10-25. Пользователь явно выбрал .01 и .02. Этот checkout выполняет
только TASK-FE-001.02 в ветке `codex/TASK-FE-001.02-secrets` от `fdd95eb`.
Owner — primary-agent; local PLAN-FE-001 in_progress, selected_tasks=[TASK-FE-001.02].
Peer .01 выполняется отдельно в `codex/TASK-FE-001.01-toolchain`.
Остальные 40 задач не выбраны. Main и backend не меняются, accepted не выставляется.

## Результат и категории

Созданы [source-аудит](research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md) и **42 задачи**:
**A=23, B=16, C=3**. Local статусы: review=1, ready=1, draft=37, blocked=3.
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

В этой ветке выбрана TASK-FE-001.02; peer .01 локально остаётся ready/unassigned,
но её реализация назначена в отдельном worktree. Все зависимости обеих пусты.
Рекомендуемые первые семь по порядку:

- [TASK-FE-001.01](tasks/TASK-FE-001.01.md): Согласовать и воспроизвести Flutter/Dart toolchain; ready, prerequisites none.
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

- `.01`: `pubspec.yaml`, `pubspec.lock`, будущий `docs/development/TOOLCHAIN.ru.md`,
  `docs/ai/tasks/TASK-FE-001.01.md`; worktree
  `/Users/verliiar/.codex/worktrees/fe-001-01-toolchain/Desktop_application`.
- `.02`: `.vscode/launch.json`, `.gitignore`, будущие `.vscode/launch.example.json`,
  `docs/development/SECRETS.ru.md`, `docs/ai/tasks/TASK-FE-001.02.md`; worktree
  `/Users/verliiar/.codex/worktrees/fe-001-02-secrets/Desktop_application`.
- Обе реализации выполняет primary-agent последовательно; только coordinator
  меняет общие PLAN/active-plan. Local карточки/таблица согласованы в каждой ветке;
  будущая интеграция общих records потребует сверки, worktree не отменяет её.
- REVIEW-FE-001.01-03 и REVIEW-FE-001.02-01 завершены независимым
  /root/review_fe_foundation_01_02 в своих worktrees, reviewed/complete.
  Reviewer изменил только два назначенных отчёта; actionable findings нет.
- Commit/push/merge новых результатов не поручены. Старый docs commit остаётся
  локальным после GitHub 403. Проверки и результаты фиксируются в своей карточке.

## Результат выбранной карточки

Локальная .02 подготовлена и прошла
[независимый review REVIEW-FE-001.02-01](reviews/REVIEW-FE-001.02-01.md).
Status остаётся review: пользователь ещё не принял результат, accepted нет.
Credential/model defines удалены из текущей конфигурации ветки; JSON, scan и
ignore checks PASS. Source/API/DTO/dependencies не менялись. Credential остаётся
в истории/main/peer; владелец отдельно выполняет revoke/rotation. Без его
evidence security release gate .42 остаётся открыт.
Инструкция — [SECRETS.ru.md](../development/SECRETS.ru.md).

Primary tracked files и весь backend сохранены. Появившийся во время работы
посторонний untracked `.vscode/settings.json` в primary checkout не менялся
и не входит в задачи. Diff, scopes/42-card DAG и ссылки проверены.
Новые результаты не закоммичены, не отправлены и не объединены.
Общие records peer-веток требуют сверки при будущей явно разрешённой интеграции.

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
| TASK-FE-001.01 | [tasks/TASK-FE-001.01.md](tasks/TASK-FE-001.01.md) | unassigned | created |
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
| REVIEW-FE-001.01-03 | `reviews/REVIEW-FE-001.01-03.md` (создан в peer toolchain worktree) | /root/review_fe_foundation_01_02 | created |
| REVIEW-FE-001.02-01 | [reviews/REVIEW-FE-001.02-01.md](reviews/REVIEW-FE-001.02-01.md) | /root/review_fe_foundation_01_02 | created |

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
