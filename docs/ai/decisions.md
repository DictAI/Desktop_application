# Решения по AI-разработке frontend

Решения относятся к процессу разработки. Продуктовые и API-изменения не
разрешаются наличием записи в этом документе. Новое решение содержит дату,
основание, область действия и явно заменяемые прежние решения.

## ADR-FE-001: Состояние работы хранится в репозитории

2026-10-24, по запросу пользователя о подготовке frontend. AGENTS.md задаёт
правила; docs/ai содержит планы, задачи, проверки, review и решения. История
чата дополняет записи, но не заменяет task frontmatter и evidence.

## ADR-FE-002: Выбор scope и приёмка остаются у пользователя

Планы не запускают реализацию. Исполнитель работает только с явно выбранным
scope/задачами; зависимости не выбираются автоматически. implemented, verified
и accepted различаются. accepted требует явной приёмки результата; commit,
push, merge и release — отдельного разрешения на соответствующее действие.

## ADR-FE-003: Независимый review

Полный review выполняет другой агент/субагент, не писавший diff. Проверяющий
не исправляет реализацию и не принимает задачу за пользователя. Findings,
исправления, deferred замечания и непроверенные риски сохраняются явно.
Правило применяется и к bootstrap организационной документации.

## ADR-FE-004: Координатор, FE ID и непересекающиеся файлы

Из backend-процесса перенесены frontmatter и жизненный цикл задач, но добавлены
frontend-префикс, последовательное резервирование ID в active-plan.md, owner,
точные scopes и planned_paths. Общие файлы имеют одного writer; отдельный
worktree не отменяет координацию. Диспетчер и автоматическая проверка схем
пока отсутствуют. Детальный протокол — в WORKFLOW.md.

## ADR-FE-005: Ограниченный bootstrap

Этот этап создаёт только AGENTS.md и docs/ai. Функциональный код, API-клиенты,
зависимости и CI исключены. Старые backend-задачи/исследования не копируются;
задачи по интеграции не создаются. Архитектура фиксирует существующий Flutter-код,
а известные проблемы перечисляются как наблюдения без автоматического выбора
исправлений. Внешний backend может использоваться read-only для будущей сверки
контракта, но не становится обязательной частью локального checkout frontend.

## ADR-FE-006: Проверки выбираются по изменению

Для документации нужны согласованность, пути, полный diff и независимый review.
Flutter analyze/test/build не запускаются ради документационных правок.
Для кода используется матрица WORKFLOW.md; результаты команд, skips и ограничения
пишутся явно. Наличие конфигурации или чтение исходников не означают PASS.

## ADR-FE-007: Окончательный batch UX и граница backend contracts

Историческая стратегия раннего mock/draft заменена ADR-FE-008 для текущего этапа;
согласованные будущие продуктовые требования сохраняются.

2026-10-26, прямое поручение пользователя: актуализировать frontend планирование,
без реализации/изменения backend. Действует PLAN-FE-001 с сохранёнными ID и .01/.02.
Подробный нормативный UX — [FRONTEND_TARGET_UX](research/FRONTEND_TARGET_UX.ru.md),
backend запросы — [FRONTEND_BACKEND_CHANGE_REQUESTS](research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md).

До Start выбраны workspace/без workspace, mic/system и язык; Stop/leave active capture
требуют «Продолжить запись» / «Завершить и отправить», без preview/случайного stop.
Валидный canonical-ready независимо от summary открывает assignment только ожидающему,
иначе in-app notice; restart/Skip/late edit доступны через Results. Есть full player,
первый подходящий sample по intervals и понятный fallback. Manual/Speaker N доступны
без workspace; contact snapshot историчен, один contact на несколько IDs с warning.

Backend persistence между login/устройствами и имена в четырёх применимых TXT/PDF —
целевые требования, **ещё без API**. .43 interface/internal mock и .46 draft не заменяют
server save; real .50 и named-export .51 blocked до контракта/реализации отдельной
backend-командой. Endpoints/JSON не придумываются, production mock fallback запрещён.

Это заменяет только прежние frontend исключения ручного speaker naming/contact mapping
и открытые storage/marker/export/snapshot развилки. Immutable BACKEND_* сохраняют
старый backend snapshot; voice profiles/auto identity/canonical merge/split/live/chat/
reprocess не возвращаются. Реализация остальных задач, commit/push/merge/release
не разрешены; accepted .01/.02 автоматически не выставляется.

## ADR-FE-008: Текущая версия только на существующем backend

2026-11-02, прямое решение владельца. Текущая версия — полноценный batch frontend
с реальной авторизацией, workspaces/contacts, WAV/V2 upload/recovery, canonical
транскриптом, независимой summary, Results, player и существующими TXT/PDF/WAV.
Показываются исходные backend Speaker ID/labels, без frontend aliases.

Переименование/contact binding/server persistence/named export остаются согласованной
будущей целью. .43/.45/.46/.47/.50/.51 переводятся в future C blocked; никакого раннего
mock repository, demo editor, local name store, fake save или unavailable формы.
.44 сохраняет полноценный player, .48 — current ready notice/показ transcript;
будущий editor routing принадлежит .50. .29/.31/.32/.34/.35–.42 не ждут future names.
.39/.40/.42 — текущие внешние gates стенда/host/security/quality, без names API.

Это заменяет стратегию раннего mock/draft из ADR-FE-007, не удаляя его будущие
продуктовые требования. Synthetic fakes действующих HTTP/hardware контрактов в tests
разрешены; runtime business mock будущих API запрещён. Новые зависимости/универсальные
слои/фиктивные endpoints не добавляются коррекцией. Уже созданный код и статусы,
accepted .01/.02 сохраняются; correction phase меняет только документы.
После независимого review пользователь поручил сразу исполнять все current tasks
по DAG с независимыми reviews, без автоматического accepted. Commit/push/merge
последним поручением запрещены, прежнее разрешение публикации не применяется.

## ADR-FE-009: iOS/iPhone вместо продолжения desktop-очереди

2026-11-16 пользователь поручил переориентировать разработку на iOS, переписать
или добавить задачи. Создан PLAN-FE-002/.01–.19. PLAN-FE-001 blocked для исполнения,
selected_tasks очищен; все старые task статусы/evidence сохранены, execution_lane
historical_not_selected и ios_successors дают перенос без повторного использования ID.
Flutter/Riverpod/GoRouter/Dio, готовые API/DTO/journals и desktop source сохраняются.
Первый iOS сценарий — microphone + Files WAV, background audio/interruption policy,
mobile UI, recoverable upload, transcript/player/share, physical device E2E и candidate.
Linux/macOS host проверки не являются iOS gate. Speaker naming/backend extensions
остаются future. Минимальный iOS target определяется по pinned SDK/plugins в .01.
Запрос разрешает planning docs, не implementation, обновление packages или выпуск.

## ADR-FE-010: Пользователь видит конечный результат, review внутренний

2026-11-16 пользователь: «без ревью, чтобы я смотрел только на конечный результат;
для ревью можешь запускать агентов, зафиксируй это в flow». Это отказ от ручного
промежуточного review пользователем; независимый контроль качества организует
coordinator через субагентов. Reviewer не пишет проверяемый source, findings
исправляет implementer в выбранном scope, затем delta review и релевантные checks.
Внутренние переходы не требуют подтверждения пользователя. В явно выбранной очереди
checks + review без блокирующих findings разрешают зависимый шаг; accepted остаётся
явной приёмкой конечного результата. Не превращать это правило в автоматический
выбор всего плана, commit/push или публикацию. Пользователю сообщаются конечный
результат, проверки и существенные ограничения, уточнения — при реальных blockers.

## ADR-FE-011: Параллельная разработка выбранного iOS блока

2026-11-16 пользователь после списка доступных iOS работ поручил выполнить все
перечисленные части и разрешил до 10 агентов. Выбраны .04 login, .05 workspaces,
.06 audio, .07 Files, .08 mobile Record и .10 mobile library. .09 lifecycle/recovery
и .11–.19 не выбраны. Разрешена работа с существующими API; новые backend contracts,
зависимости, signing/team, публикация и расширение продуктового scope не поручены.

Прежний линейный write gate заменён непересекающимися exact scopes. Native Runner
и AudioCapture/RecordNotifier принадлежат одному audio writer; остальные writers
используют согласованные интерфейсы, пересечения передаются последовательно через
coordinator. Общие router/shell/providers/docs интегрирует root. Проверки зависимостей
сохраняются перед интеграционным выводом о готовности; разработка независимых частей
не ждёт недоступного physical evidence. Эта перестановка прямо следует поручению
работать параллельно и не объявляет .03 выполненной.

Критерии physical iPhone/lock/background/interruption/Files остаются обязательными
для полной iOS readiness. Недоступные checks записываются NOT RUN/ограничениями,
не заменяются fixtures/Simulator PASS. .10 без выбранной .09 подтверждает мобильную
компоновку и существующие journal flows, но не полное suspend/relaunch recovery.
Каждая часть получает tests/review; root делает общий regression/build/launch и
проверяет сохранность исходного diff. Accepted/commit/push/release не выполняются.


## ADR-FE-012: Пауза основной кнопкой и подтверждённая отмена iOS записи

2026-11-17 пользователь поручил добавить в задачи новый сценарий Record.
Создана TASK-FE-002.20, draft/unassigned, implementation_selected=false;
текущее поручение меняет только документы. Очередь .08 → .20 → .09 → .10.

Основная кнопка: idle→recording, повторный tap→paused, tap на паузе→recording.
В paused видны зелёная «Отправить» и крестик удаления. Отправить финализирует
и отправляет текущий WAV один раз. Крестик требует подтверждения; отказ
сохраняет paused, подтверждение удаляет текущую запись и остаётся в Record.
Уход из recording/paused открывает отдельный экран «Остаться» / «Отменить запись
и выйти»; подтверждённая отмена удаляет текущую локальную запись и выполняет
исходный переход. Открытие подтверждения само не останавливает/возобновляет capture;
системные interruptions и auth/session invalidation сохраняют приоритет.

Это заменяет прежнюю iOS Stop/exit-with-send политику .08 и соответствующий
пункт iOS UX; ADR-FE-007/исторический desktop UX в остальных границах сохранены.
Discard не вызывает upload/создание journal entry и не отменяет серверные jobs;
удаляется только собственный capture WAV, не импортированный original или экспорт.
Новые API, зависимости/permissions/signing, backend изменения и публикация
не входят в scope. Старые checks/review .08 не доказывают новое поведение.
