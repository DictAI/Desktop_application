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
