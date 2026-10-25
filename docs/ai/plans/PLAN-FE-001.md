---
id: PLAN-FE-001
title: "Адаптация DictAI Flutter к целевому batch backend"
status: in_progress
owner: primary-agent
selected_tasks: ["TASK-FE-001.02"]
frontend_commit: b45c8c4dfe927a872182c7508fa85e01f83a9f0c
backend_commit: f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6
---

# PLAN-FE-001: Адаптация DictAI Flutter к целевому batch backend

## Goal

Два пути — workspace и authenticated owner-only — должны вести от записи или
выбора WAV через durable V2 upload к canonical Speaker N, независимым summary,
TXT/PDF/original, библиотеке и корректному delete/logout на macOS/Linux.
Разработка учитывает реализованный API и согласованный target, включая
незавершённые backend quality/cutover задачи. Наличие service code не равно
production readiness.

**2026-10-25 пользователь выбрал .01 и .02. Этот checkout реализует только .02
в своей ветке; peer .01 выполняется отдельно.** Остальные 40 задач не выбраны.
План in_progress в local scope; accepted и разрешения commit/push/merge
новых результатов автоматически не выдаются.

Исключены: voice profiles/embeddings, mandatory confirm, legacy compatibility,
live/chat/public sharing/speaker editing/user cancel/reprocess/provider selector,
версии/history UI без API и spec-only meeting endpoints. Не создаются CI,
новые глобальные framework layers, другой state/router stack или backend fixes.
Публикация, signing с credentials, commit/push/merge/release требуют отдельного разрешения.

## Current state

Полный [source-аудит и матрица расхождений](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md)
содержат состояние всех экранов/notifiers/clients/DTO и платформ. FE HEAD
`b45c8c4dfe927a872182c7508fa85e01f83a9f0c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`.
Документация до планирования уже была untracked; источник кода и сам Markdown
нельзя отождествлять по одному SHA.

Ключевые факты: login token/часть workspace DTO и R01/R02 уже совместимы;
detail зависит от удалённого VoiceProfileApi; record gate требует profiles;
ordinary теряет job metadata, anonymous пишет M4A/OGG и ждёт confirm;
canonical/detail отсутствуют; list done ошибочно управляет PDF;
legacy downloads читают весь audio в RAM и сохраняют .mp3; xdg-open вызывается
на macOS. SDK 3.38.1/Dart 3.10.0 не удовлетворяет lock Dart >=3.11.0.
Есть значение ключа в launch config, body logging и plaintext preferences.
Runtime, модели, OS permissions и builds текущим аудитом не проверялись.

Контракты для карточек:
[BACKEND_API_CONTRACTS](../research/BACKEND_API_CONTRACTS.ru.md),
[BACKEND_TARGET_SCOPE](../research/BACKEND_TARGET_SCOPE.ru.md).
Внутренние ссылки копий разрешаются в backend-контексте по
[architecture](../architecture.md); содержимое копий не меняется.

## Предлагаемая целевая архитектура

Сохранить `lib/core`, `lib/features`, `lib/shared/providers`, StateNotifier,
GoRouter, Dio и ручную сериализацию. Сохранить shell/theme/cards/forms, меняя
смысл bindings и недостоверные подписи вместо полного redesign.

- Core: AppConfig, безопасный storage, redacted diagnostics, общий error mapping
  и session generation. Сервер авторизует запросы; локальная проверка JWT не
  выдаёт прав и не создаёт несуществующий /me/logout endpoint.
  .04 включает минимальный macOS Keychain setup обоих существующих entitlements
  и реальный Debug/Release storage smoke; .36 повторяет его на итоговом приложении.
- Record/data: узкий capture interface с mic/macOS/Linux adapters,
  bounded WAV preflight, V2 accepted/options DTO и owner-scoped upload journal.
  Все перечисленные новые файлы — будущие planned_paths, не существующий код.
- Results/data: status/canonical/page/document models/clients, pending job store
  и export service. Только gateway, без direct MinIO/NATS/inference access.
- Presentation: один job tracker, общий detail и transcript viewer; оба upload
  UX сходятся на accepted audio/job/version, не на profile/confirm.
- Provider composition остаётся в shared/providers; API, capture, clock,
  storage и process boundaries подменяются для осмысленных тестов.
- Предлагаемый frontend route `/results/:audioId?job_id=...` не является новым
  backend endpoint. Backend routes только существующие R03/R04/R05.

Auth → capture → upload → queued/running → canonical и summary/documents —
разные lifecycles. 202 upload = durable acceptance; 202 structured может быть
failed/cancelled. no_speech — success. list done ≠ summary ready.
Микросекунды, nullable keys/words и local speaker labels сохраняют wire semantics.
Нет процентов, ETA или live state, которых сервер не возвращает.

## Этапы и приоритеты

| Этап | Результат | Карточки |
|---|---|---|
| 0 | Основа: SDK, секреты, storage, config, безопасные errors/tests | 01, 02, 03, 04, 05, 06, 07 |
| 1 | Auth, workspace/contacts и удаление profile coupling | 08, 09, 10, 11, 12, 13, 14 |
| 2 | Capture, WAV/V2, journal, status/canonical data и оба upload UX | 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25 |
| 3 | Library/detail/transcript, export/delete, retirement/isolation | 26, 27, 28, 29, 30, 31, 32, 33, 34 |
| 4 | Regression suite, macOS/Linux verification, integration harness | 35, 36, 37, 38 |
| 5 | Реальный backend gate/E2E, release candidate и приёмка | 39, 40, 41, 42 |

Этапы — группировка, не обязательный линейный запуск. Полный DAG ниже:
например .25 предшествует .23/.24, а data .21/.22 может готовиться раньше UI.
P0 — среда/security/release gates, P1 — обязательный batch behavior,
P2 — завершение существующего workspace/contact CRUD UX.
Все 42 карточки входят в предлагаемый batch milestone; дополнительные будущие
направления ниже не включены. Владелец может принять иной scope явно.

### Готовность A/B/C

- **A — 23:** локальная основа, platform code или прямой existing wire contract.
  Реальные platform probes требуют подходящего host; category не обещает его наличие.
- **B — 16:** новые сквозные state/UI/recovery сценарии можно реализовать по
  известным DTO с mocks. Их end-to-end интеграция зависит от backend окружения.
- **C — 3:** полноценное завершение невозможно без внешнего backend/operator
  evidence и решений. У карточек status blocked и явные условия разблокировки.

A/B определяют backend/contract готовность, а не отменяют FE depends_on.
Даже A-задача с непринятыми prerequisites остаётся draft.

## Task graph

Полный список входящих FE-зависимостей; `<-` означает «начать после accepted
всех перечисленных prerequisites». Backend IDs намеренно не помещаются в FE
depends_on: они перечислены в backend_tasks и внешних gates.

```text
TASK-FE-001.01 <- none
TASK-FE-001.02 <- none
TASK-FE-001.03 <- TASK-FE-001.01
TASK-FE-001.04 <- TASK-FE-001.01
TASK-FE-001.05 <- TASK-FE-001.01, TASK-FE-001.02, TASK-FE-001.03
TASK-FE-001.06 <- TASK-FE-001.01
TASK-FE-001.07 <- TASK-FE-001.03, TASK-FE-001.05, TASK-FE-001.06
TASK-FE-001.08 <- TASK-FE-001.04, TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.09 <- TASK-FE-001.08
TASK-FE-001.10 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.11 <- TASK-FE-001.09, TASK-FE-001.10
TASK-FE-001.12 <- TASK-FE-001.11
TASK-FE-001.13 <- TASK-FE-001.12
TASK-FE-001.14 <- TASK-FE-001.11
TASK-FE-001.15 <- TASK-FE-001.04, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.16 <- TASK-FE-001.15
TASK-FE-001.17 <- TASK-FE-001.15
TASK-FE-001.18 <- TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.19 <- TASK-FE-001.05, TASK-FE-001.07, TASK-FE-001.18
TASK-FE-001.20 <- TASK-FE-001.04, TASK-FE-001.19
TASK-FE-001.21 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.22 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.23 <- TASK-FE-001.11, TASK-FE-001.14, TASK-FE-001.15, TASK-FE-001.16, TASK-FE-001.17, TASK-FE-001.18, TASK-FE-001.19, TASK-FE-001.20, TASK-FE-001.25
TASK-FE-001.24 <- TASK-FE-001.23
TASK-FE-001.25 <- TASK-FE-001.09, TASK-FE-001.14, TASK-FE-001.20, TASK-FE-001.21
TASK-FE-001.26 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.27 <- TASK-FE-001.25, TASK-FE-001.26
TASK-FE-001.28 <- TASK-FE-001.09, TASK-FE-001.22, TASK-FE-001.24, TASK-FE-001.25, TASK-FE-001.27, TASK-FE-001.30
TASK-FE-001.29 <- TASK-FE-001.22, TASK-FE-001.28
TASK-FE-001.30 <- TASK-FE-001.05, TASK-FE-001.06, TASK-FE-001.07
TASK-FE-001.31 <- TASK-FE-001.29, TASK-FE-001.30
TASK-FE-001.32 <- TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.31
TASK-FE-001.33 <- TASK-FE-001.14, TASK-FE-001.23, TASK-FE-001.24, TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.31, TASK-FE-001.32
TASK-FE-001.34 <- TASK-FE-001.09, TASK-FE-001.20, TASK-FE-001.25, TASK-FE-001.27, TASK-FE-001.28, TASK-FE-001.32, TASK-FE-001.33
TASK-FE-001.35 <- TASK-FE-001.12, TASK-FE-001.13, TASK-FE-001.23, TASK-FE-001.24, TASK-FE-001.29, TASK-FE-001.31, TASK-FE-001.32, TASK-FE-001.34
TASK-FE-001.36 <- TASK-FE-001.16, TASK-FE-001.33, TASK-FE-001.35
TASK-FE-001.37 <- TASK-FE-001.17, TASK-FE-001.33, TASK-FE-001.35
TASK-FE-001.38 <- TASK-FE-001.19, TASK-FE-001.21, TASK-FE-001.22, TASK-FE-001.26, TASK-FE-001.30, TASK-FE-001.34, TASK-FE-001.35
TASK-FE-001.39 <- TASK-FE-001.38
TASK-FE-001.40 <- TASK-FE-001.36, TASK-FE-001.37, TASK-FE-001.39
TASK-FE-001.41 <- TASK-FE-001.33, TASK-FE-001.35, TASK-FE-001.36, TASK-FE-001.37, TASK-FE-001.38
TASK-FE-001.42 <- TASK-FE-001.40, TASK-FE-001.41
```

## Tasks

Каждая карточка следует TASK_TEMPLATE: owner, scope/planned_paths, criteria,
Verification, Result и backend/API traceability. Полные write scopes — в карточках;
общий путь в нескольких scopes обслуживается последовательно, а не двумя writers.

| ID | Title | Category | Priority | Status | Dependencies | Owner | Write scope |
|---|---|---|---|---|---|---|---|
| [TASK-FE-001.01](../tasks/TASK-FE-001.01.md) | Согласовать и воспроизвести Flutter/Dart toolchain | A | P0 | ready | none | unassigned | Точные пути в карточке |
| [TASK-FE-001.02](../tasks/TASK-FE-001.02.md) | Удалить значения секретов из tracked-конфигурации | A | P0 | review | none | primary-agent | Точные пути в карточке |
| [TASK-FE-001.03](../tasks/TASK-FE-001.03.md) | Ограничить HTTP-логирование и редактировать чувствительные данные | A | P0 | draft | 01 | unassigned | Точные пути в карточке |
| [TASK-FE-001.04](../tasks/TASK-FE-001.04.md) | Перевести session storage на защищённое хранилище | A | P0 | draft | 01 | unassigned | Точные пути в карточке |
| [TASK-FE-001.05](../tasks/TASK-FE-001.05.md) | Настроить явную конфигурацию gateway и сетевых политик | A | P0 | draft | 01, 02, 03 | unassigned | Точные пути в карточке |
| [TASK-FE-001.06](../tasks/TASK-FE-001.06.md) | Подготовить тестовую основу без сети и аппаратуры | A | P1 | draft | 01 | unassigned | Точные пути в карточке |
| [TASK-FE-001.07](../tasks/TASK-FE-001.07.md) | Унифицировать безопасную обработку HTTP и транспортных ошибок | A | P1 | draft | 03, 05, 06 | unassigned | Точные пути в карточке |
| [TASK-FE-001.08](../tasks/TASK-FE-001.08.md) | Сверить auth API с действующим wire contract | A | P1 | draft | 04, 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.09](../tasks/TASK-FE-001.09.md) | Согласовать auth UI, JWT lifecycle и навигацию | B | P1 | draft | 08 | unassigned | Точные пути в карточке |
| [TASK-FE-001.10](../tasks/TASK-FE-001.10.md) | Закрепить workspace/contact DTO и CRUD-контракты | A | P1 | draft | 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.11](../tasks/TASK-FE-001.11.md) | Убрать voice-profile coupling из workspace и старта записи | B | P1 | draft | 09, 10 | unassigned | Точные пути в карточке |
| [TASK-FE-001.12](../tasks/TASK-FE-001.12.md) | Завершить workspace UX создания и переименования | B | P2 | draft | 11 | unassigned | Точные пути в карточке |
| [TASK-FE-001.13](../tasks/TASK-FE-001.13.md) | Завершить contact CRUD и пояснить email recipients | B | P2 | draft | 12 | unassigned | Точные пути в карточке |
| [TASK-FE-001.14](../tasks/TASK-FE-001.14.md) | Удалить неиспользуемый voice-profile API и wiring | A | P1 | draft | 11 | unassigned | Точные пути в карточке |
| [TASK-FE-001.15](../tasks/TASK-FE-001.15.md) | Выделить общий lifecycle микрофонной WAV-записи | A | P1 | draft | 04, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.16](../tasks/TASK-FE-001.16.md) | Сделать macOS system+microphone capture совместимым и ограниченным по памяти | A | P1 | draft | 15 | unassigned | Точные пути в карточке |
| [TASK-FE-001.17](../tasks/TASK-FE-001.17.md) | Сделать Linux system+microphone capture предсказуемым | A | P1 | draft | 15 | unassigned | Точные пути в карточке |
| [TASK-FE-001.18](../tasks/TASK-FE-001.18.md) | Проверять WAV/лимиты и формировать upload options | A | P1 | draft | 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.19](../tasks/TASK-FE-001.19.md) | Добавить V2 multipart upload client и accepted DTO | A | P1 | draft | 05, 07, 18 | unassigned | Точные пути в карточке |
| [TASK-FE-001.20](../tasks/TASK-FE-001.20.md) | Сохранить upload identity и job references для восстановления | B | P1 | draft | 04, 19 | unassigned | Точные пути в карточке |
| [TASK-FE-001.21](../tasks/TASK-FE-001.21.md) | Добавить job status и anonymous session V2 контракты | A | P1 | draft | 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.22](../tasks/TASK-FE-001.22.md) | Добавить canonical transcript DTO и 200/202 result API | A | P1 | draft | 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.23](../tasks/TASK-FE-001.23.md) | Перевести ordinary record/upload UX на V2 | B | P1 | draft | 11, 14, 15, 16, 17, 18, 19, 20, 25 | unassigned | Точные пути в карточке |
| [TASK-FE-001.24](../tasks/TASK-FE-001.24.md) | Заменить anonymous confirm на owner-only V2 batch UX | B | P1 | draft | 23 | unassigned | Точные пути в карточке |
| [TASK-FE-001.25](../tasks/TASK-FE-001.25.md) | Организовать lifecycle polling и восстановление accepted jobs | B | P1 | draft | 09, 14, 20, 21 | unassigned | Точные пути в карточке |
| [TASK-FE-001.26](../tasks/TASK-FE-001.26.md) | Закрепить V2 results list и pagination data | A | P1 | draft | 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.27](../tasks/TASK-FE-001.27.md) | Адаптировать библиотеку результатов и фильтры | B | P1 | draft | 25, 26 | unassigned | Точные пути в карточке |
| [TASK-FE-001.28](../tasks/TASK-FE-001.28.md) | Добавить result detail route с независимыми состояниями | B | P1 | draft | 09, 22, 24, 25, 27, 30 | unassigned | Точные пути в карточке |
| [TASK-FE-001.29](../tasks/TASK-FE-001.29.md) | Показать canonical transcript и recording-local speakers | B | P1 | draft | 22, 28 | unassigned | Точные пути в карточке |
| [TASK-FE-001.30](../tasks/TASK-FE-001.30.md) | Добавить авторизованный document/original download client | A | P1 | draft | 05, 06, 07 | unassigned | Точные пути в карточке |
| [TASK-FE-001.31](../tasks/TASK-FE-001.31.md) | Сделать экспорт TXT/PDF/WAV и локальное открытие кроссплатформенными | B | P1 | draft | 29, 30 | unassigned | Точные пути в карточке |
| [TASK-FE-001.32](../tasks/TASK-FE-001.32.md) | Согласовать delete/tombstone и очистку локального состояния | B | P1 | draft | 27, 28, 31 | unassigned | Точные пути в карточке |
| [TASK-FE-001.33](../tasks/TASK-FE-001.33.md) | Удалить остатки legacy speech flow после переключения consumers | A | P1 | draft | 14, 23, 24, 27, 28, 31, 32 | unassigned | Точные пути в карточке |
| [TASK-FE-001.34](../tasks/TASK-FE-001.34.md) | Проверить и завершить account isolation и cleanup всего batch flow | B | P0 | draft | 09, 20, 25, 27, 28, 32, 33 | unassigned | Точные пути в карточке |
| [TASK-FE-001.35](../tasks/TASK-FE-001.35.md) | Покрыть batch-пути unit/widget regression suite | B | P1 | draft | 12, 13, 23, 24, 29, 31, 32, 34 | unassigned | Точные пути в карточке |
| [TASK-FE-001.36](../tasks/TASK-FE-001.36.md) | Проверить macOS Debug/Release, permissions, capture и файлы | A | P1 | draft | 16, 33, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.37](../tasks/TASK-FE-001.37.md) | Проверить Linux build, аудио prerequisites и export | A | P1 | draft | 17, 33, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.38](../tasks/TASK-FE-001.38.md) | Подготовить opt-in интеграционный harness и требования к стенду | B | P1 | draft | 19, 21, 22, 26, 30, 34, 35 | unassigned | Точные пути в карточке |
| [TASK-FE-001.39](../tasks/TASK-FE-001.39.md) | Подтвердить тестовый backend и закрыть контрактные вопросы доступа | C | P0 | blocked | 38 | unassigned | Точные пути в карточке |
| [TASK-FE-001.40](../tasks/TASK-FE-001.40.md) | Выполнить реальную batch-интеграцию на подготовленном стенде | C | P1 | blocked | 36, 37, 39 | unassigned | Точные пути в карточке |
| [TASK-FE-001.41](../tasks/TASK-FE-001.41.md) | Подготовить локальный batch release candidate и инструкцию выпуска | A | P1 | draft | 33, 35, 36, 37, 38 | unassigned | Точные пути в карточке |
| [TASK-FE-001.42](../tasks/TASK-FE-001.42.md) | Зафиксировать готовность frontend-интеграции к batch-релизу | C | P0 | blocked | 40, 41 | unassigned | Точные пути в карточке |

### Первые задачи и выбор

В этом checkout выбрана **.02**; peer .01 локально остаётся ready,
а выполняется в своей ветке. Остальные draft/blocked; зависимости не приняты автоматически.
Рекомендуемый первый пакет порядка работ: **.01 → .02 → .03 → .04 → .05 → .06 → .07**.
Это предложение для выбора: .03/.04/.06 требуют принятой .01,
.05 также .02/.03, .07 — .03/.05/.06. Порядок допускает независимое выполнение
после принятых зависимостей, но не изменяет required review/acceptance.

После подготовки среды/безопасности: .08/.09 и .10/.11, затем capture и V2 data,
polling/journal, оба UX и results. Не реализовывать весь план по факту его создания.

## Координация файлов

Coordinator выдаёт FE ID и меняет active-plan; owner local .02 — primary-agent,
остальные local карточки пока unassigned. Peer-ветка учтена в active-plan.
Назначается один implementer на выбранную карточку. Новые файлы помечены
planned_paths; файл может быть создан prerequisite до старта зависимой задачи.
Scope включает собственную task-карточку. Если prerequisite уже удалил retired
файл, не создавать его заново ради scope.

Общие последовательности записи:
- api_client: .03 → .05; pubspec/lock: .01 → .20.
- auth/router/providers: .05 → .09 → .11 → .14 → .25 → .23 → .24 →
  .28 → .33 → .34; часть стрелок — явный DAG через prerequisites.
- workspace_notifier/detail: .10 → .11 → .12 → .13.
- result screens/notifiers: .27 → .28 → .29 → .31 → .32 → .33/.34.
- native RunnerTests: .16 → .36.
- macOS DebugProfile/Release entitlements: writers .04 → .16; порядок уже задан
  цепочкой .04 → .15 → .16. .04 меняет только минимальный Keychain setup, .16 —
  только необходимый capture setup с сохранением Keychain. .36 проверяет итог,
  но не изменяет entitlements. Дополнительных FE edges и параллельных writers нет.

Параллельны только непересекающиеся scopes после prerequisites: например .16/.17,
data .21/.22/.26/.30 и независимые tests. Worktree не разрешает конфликтующие
writes. При расширении scope/gates сначала пересмотреть план с владельцем.
Reviewer read-only и не является implementer; каждый implementation diff проходит
своё независимое review, review этого плана его не заменяет.

## Зависимости от backend

| Backend этап/вопрос | Состояние на snapshot | Влияние/условие |
|---|---|---|
| .14/.15/.16/.20/.25/.30/.37 | accepted в описанном scope | Existing wire для A/B; runtime config/TLS/models/SMTP/Typst всё ещё нужны |
| .26/.41 harness и .39 dataset | accepted limited/provisional | .39 только RU local bundle; полный dataset/acceptance readiness и реальный baseline не закрыты |
| .29 numerical gates | draft | До .17 нужно evidence baseline и решение владельца; FE не выбирает WER/DER thresholds |
| .17 CPU E2E | draft | Gate качества/robustness и реального release-bound E2E .40 |
| .24 staging/cutover | blocked по .17 | Нужно настроенное staging и in-flight policy; доступ к test env предварительно проверяется .39 |
| .31 production evidence | blocked по .24 | Финальная синхронизация release gate .42, не разрешение frontend/deployment публикации |
| .18 GPU / .19 runtime | review / draft | Не блокируют CPU frontend; provider/device selector не требуется |
| .21 live | draft design-only | Не даёт нового API и не входит в batch release |
| .27 cleanup | accepted design-only | DELETE не обещает physical destruction; historical data не уничтожается планом |
| Workspace access/contacts, grant discovery | Вопросы текущего кода, нет автоматически обещанного fix task | FE .39 фиксирует нужное решение/owner; grant UI не добавляется без контракта |

Для C .39 необходимы разрешённый isolated test origin, accounts/оператор и
подтверждённые runtime prerequisites. .40 требует принятый backend .17 и готовый
staging scope .24 плюс macOS/Linux evidence. .42 требует rollout receipts .31
и отдельной приёмки владельцем. До появления evidence статус blocked.
Для .39 нет требования «выдумать» backend задачу по access: команда должна
выбрать реальный scope исправления либо принять явное безопасное ограничение;
frontend не исправляет server security client-side.

## Verification strategy

Планирование: ID uniqueness, YAML frontmatter, зависимости/циклы, category totals,
точные существующие/будущие пути, ссылки и cross-file write order; source-driven
API coverage и все15 пользовательских областей из поручения; полный diff и
baseline hashes двух репозиториев. Копии BACKEND_* не меняются.

Реализация: каждая карточка содержит concrete targeted tests/smoke с NOT RUN до
исполнения. После .01 — format изменённых файлов, analyze и unit/widget;
реальные mic/OS storage/process/download smoke отдельно на каждой платформе.
В .04 перед принятием защищённого storage нужны plist/mapping checks и настоящий
Keychain smoke в Debug/Release через будущий изолированный macOS smoke entry point,
указанный в карточке. Он не требует backend/новых пакетов/реальных секретов.
Unit fakes его не заменяют; без подходящего host/локальной подписи результат
NOT RUN/blocked. Signing-конфигурация и выпуск не входят в этот setup.
CI не добавляется автоматически. Глобальные baseline analyzer/format failures
не исправляются вне scope и не скрываются; нужный остаток выносится на выбор.

Интеграция: opt-in harness .38 не звонит hardcoded production. Test-origin,
credentials и разрешение synthetic writes должны быть явными. .39–.40 фиксируют
actual backend SHA/config, source changes и real outcomes. Нет public cancel
и full model error detail — тесты не придумывают такие commands.

### Verification планирования

- PASS: Ruby YAML/schema — 42 уникальных ID, A/B/C=23/16/3,
  ready/draft/blocked=2/37/3; все local/backend IDs существуют, циклов нет.
- PASS: scopes/planned_paths явно учитывают отсутствующие файлы; общие writes
  имеют порядок ancestry; task frontmatter и полный DAG в плане совпадают.
- PASS: 472 локальные ссылки собственной frontend AI-документации, fences,
  полный no-index diff и whitespace всех 46 файлов planning scope проверены.
  Ссылки BACKEND_* сохраняют отдельный backend-контекст, copies не менялись.
- PASS: 23 обязательных batch HTTP-операции покрыты карточками. U05/U06
  существуют, но UI discovery не готов: они явно не включены как готовый flow.
  Матрица аудита покрывает все15 областей поручения; значения launch-secret
  не перенесены в новые документы.
- PASS: SHA-256 baseline — 106 прежних frontend-файлов неизменны, изменён только
  active-plan и добавлены 45 planning-документов. Все 589 backend-файлов прежние,
  backend/FE HEAD, BACKEND_* copies и tracked/staged diff неизменны.
- PARTIAL: [независимый review](../reviews/REVIEW-FE-001.01-01.md) запущен двумя
  неавторами. Оба сообщили один P2: .28 не зависела от documents client .30.
  Зависимость исправлена автором, DAG/table/card синхронизированы, self-check PASS.
  Затем оба reviewer завершились ошибкой account usage limit до полного review.
  **Полный независимый review и delta review исправления NOT RUN/не завершены.**
  Это не отсутствие остальных findings и не основание объявить план проверенным
  независимым reviewer. Документ остаётся draft до завершения этого этапа.
- NOT RUN: Flutter/backend/runtime tests — сейчас документация, не implementation.

## Risks and decisions

- **Toolchain:** несовместимость подтверждена; конкретный совместимый SDK/версию
  выбирают в .01 по реальной доступности, без случайного package upgrade.
- **Security:** token preferences/body logs/launch secret, stale account state;
  .02–.05/.09/.34 обязательны. Revoke/rotation требует внешнего evidence; история Git
  не переписывается. Значения credentials в новые документы не включаются.
- **Capture:** macOS whole-file buffers, Linux no-join/silent fallback,
  несинхронный pause и anonymous codec. Bounded/data-integrity tests не заменять
  маленькими mock tests или переименованием расширения.
- **Idempotency/restart:** source/options/key надо сохранить до HTTP запроса;
  deployment revision conflict409 не обходится новым key автоматически.
- **Result lifecycle:** document404/503, summary partial success, multiple schemas
  и tombstones требуют разных UI states; не resurrect deleted jobs.
- **Контракты/права:** source OpenAPI расходится, workspace/contact access требует
  согласования. Snapshot не live deployment receipt; новые серверные поля требуют
  отдельного contract update, не неявной генерации клиента.
- **Объём UI:** rename workspace/edit contacts используют существующие W API.
  Account credential methods адаптируются, но новый settings screen не обязателен.
  Полный дизайн/локализация/Windows/mobile/web не входят.
- **Стенд/выпуск:** Linux host, macOS permissions/Keychain, тестовая PKI/models и
  production evidence не предоставлены этим поручением. Подготовить candidate
  можно отдельно; реальный release/deployment не разрешён.

### Открытые вопросы

1. Какая точная Flutter/Dart версия и hosts будут выбраны? Какой минимальный
   supported Linux desktop/audio server и способ доставки CLI prerequisites?
2. Каков разрешённый test-origin/TLS, кто оператор и владелец test data/accounts?
3. Кто и в каком scope закрывает backend full dataset/gates и workspace access
   вопросы? Отсутствующий task ID не заполняется догадкой.
4. Как трактовать контакты/owner-only email links и судьбу старых jobs/results?
   Sharing/history migration не обещаны и требуют отдельного решения.
5. Каковы ожидания по локальному retention pending audio/journal и storage quota?
   Минимум — не терять неразрешённый upload outcome и не показывать другому owner.
6. Combined pause должен быть синхронным или отсутствовать в этом режиме;
   не оставлять текущую частичную паузу как честный pause всей записи.
7. Release version/signing/notarization/installer distribution и secret rotation
   выполняются только по отдельным решениям, с evidence владельца.

### Потенциальные направления, не обязательный backlog этого релиза

Live/replay/progress (.21) после batch; chat/history; public sharing/invitations;
speaker editing; user cancel/reprocess; grant recovery discovery; version history;
provider selector; универсальный file transcoding/YouTube URL ingestion.
Для каждого сначала решение/контракт/отдельный план; FE task ID здесь не создаются.
Отменённые voice profiles/confirm/legacy fallback не возвращаются как такие направления.

## Completion

Frontend-интеграция считается завершённой только после выбранных mandatory tasks,
unit/widget и реальных macOS/Linux checks, .39/.40 integration evidence,
закрытых security findings и .42 с актуальными backend .17/.24/.31 receipts.
Оба режима проходят один V2 pipeline, доступны canonical/independent summary/
TXT/PDF/original, работают library/delete/restart/logout isolation, retired API
не вызываются. Все checks имеют команды/среду/actual results, независимые reviews
и явную приёмку пользователя. Mock PASS не подтверждает backend model quality.

Изменения этого planning-прохода: один план, 42 карточки, source-аудит, review record
и active-plan. Код/DTO/clients/dependencies, исходные backend snapshots и backend
не изменяются. Никакие implementation criteria не отмечаются выполненными.
