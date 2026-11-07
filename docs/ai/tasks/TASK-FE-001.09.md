---
id: TASK-FE-001.09
plan: PLAN-FE-001
title: "Согласовать auth UI, JWT lifecycle и навигацию"
status: review
owner: primary-agent
priority: P1
readiness_category: B
phase: "1"
depends_on: ["TASK-FE-001.08"]
backend_tasks: ["TASK-002.37"]
api_contracts: ["A01–A03", "§2"]
blocked_by: []
scope:
  - "lib/features/auth/presentation/auth_notifier.dart"
  - "lib/features/auth/presentation/login_screen.dart"
  - "lib/core/network/auth_interceptor.dart"
  - "lib/core/storage/secure_storage.dart"
  - "lib/core/router/auth_listenable.dart"
  - "lib/core/router/app_router.dart"
  - "lib/shared/providers/providers.dart"
  - "test/features/auth/session_navigation_test.dart"
  - "test/widget_test.dart"
  - "test/core/storage/secure_storage_test.dart"
  - "docs/ai/tasks/TASK-FE-001.09.md"
planned_paths:
  - "test/features/auth/session_navigation_test.dart"
delivery_stage: current
---

# TASK-FE-001.09: Согласовать auth UI, JWT lifecycle и навигацию

## Goal

Явные login/loading/error/expired/logout состояния и управляемое обновление ещё действующего JWT.

Выбрана пользователем 2026-11-02 в составе всего оставшегося PLAN-FE-001.
Начинать по depends_on после checks/review prerequisites; внешние blockers
не обходить и accepted автоматически не выставлять.

## Context

[План](../plans/PLAN-FE-001.md), [source-аудит](../research/FRONTEND_BACKEND_GAP_ANALYSIS.ru.md),
[API-снимок](../research/BACKEND_API_CONTRACTS.ru.md),
[target scope](../research/BACKEND_TARGET_SCOPE.ru.md).
Backend SHA: `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`; перед реализацией
проверить актуальность. Ссылки внутри снимков относятся к backend, см. architecture.

**Исходное состояние:** Redirect проверяет только наличие token; 401 удаляет его; error copyWith не очищает null; session-bound features живут глобально.

**Целевое:** Явные login/loading/error/expired/logout состояния и управляемое обновление ещё действующего JWT.

**Категория B, P1.** Текущая UI/state-логика работает с реальными API. Test fakes допустимы только для проверки существующих контрактов, не для будущих бизнес-функций.
FE prerequisites: [TASK-FE-001.08](TASK-FE-001.08.md).
Backend traceability: TASK-002.37
API: A01–A03, §2.

## Requirements delta — 2026-10-26

Исторические требования именования из UX сохраняются для будущего этапа. Текущая граница и критерии ниже пересмотрены 2026-11-02: только существующий backend, без names UI/mock/store и без блокировки самостоятельной текущей части.

## Этап и решение — 2026-11-02

Нужна: JWT/session/navigation; убрать обязательства editor/draft guards текущего этапа.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] Auth redirect/session cleanup не останавливает capture случайным route dispose; общий Stop/leave guard реализует .49. Guards редактора имён в текущий scope не входят.
- [x] Register→login сохранён; ошибка очищается при повторе; double submit и late callbacks не меняют новую session.
- [x] Истёкший/старый issuer JWT требует login; refresh только ещё действующего JWT, без бесконечного 401 loop.
- [ ] Logout удаляет credential/feature state, late 401 старой сессии не разлогинивает новую. Полная isolation дополняется .34; anonymous также под JWT.
- [x] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [x] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Уточнение scope — 2026-11-03

Добавлен secure_storage.dart. Сравнение JWT в interceptor и последующее удаление
были бы двумя операциями с гонкой. Проверка версии сессии и её удаление или
обновление выполняются в одной существующей очереди .04. Версия отличает даже
повторный вход с побайтово одинаковым JWT. Формат хранения и настройки Keychain
сохраняются. Добавлен test/widget_test.dart для корректировки проверки ошибки
Login 401 после подключения общего mapper. Secure storage test уточнён после
F03 review: частично записанный JWT сохраняет старые данные и остаётся недоступен
до явного успешного повтора записи.

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

2026-11-03, cwd `/Users/verliiar/Desktop_application`, macOS arm64,
`.dart_tool/codex-tools/flutter` 3.41.3 / Dart 3.11.1,
`PUB_CACHE=/Users/verliiar/.pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true`.

| Команда / сценарий | Actual | Статус / граница |
|---|---|---|
| `flutter test --no-pub --timeout 45s test/features/auth test/core/storage/secure_storage_test.dart test/core/network/storage_interceptor_test.dart test/widget_test.dart` | 52 tests passed | PASS, 12 session/route, 20 wire, 14 storage/interceptor, 6 foundation |
| `dart analyze` в exact Dart scope карточки | No issues found | PASS |
| `dart format --output=none --set-exit-if-changed` в изменённом Dart scope | 8 files, 0 changed | PASS |
| Real gateway / OS capture cleanup | Не запускались | NOT RUN, .34/.36–.40/.49 |
| Independent review .09-01 | Передан отдельному reviewer | Pending |

Fixture actual GoRouter проверяет переход с Workspaces на Login после текущего 401
и auth guard Record/Results. Отдельные tests охватывают byte-identical JWT на новой
сессии, public 401, атомарную замену, single-flight, late login/refresh, logout,
issuer/expiry и один failed proactive renewal с последующим истечением. Реальные
gateway auth-service handlers и claims сверены read-only по backend SHA из Context.

## Result

Вход и регистрация имеют отдельные loading/error, повтор очищает сообщение,
запаздывающий login после logout не меняет session. Register требует 8 UTF-8 bytes,
login передаёт пароль без правила длины регистрации. Неподходящий issuer или
истечение JWT закрывают защищённые маршруты. Проверка claims в Dart используется
для навигации и времени обновления, подпись и доступ проверяет gateway.

Выбрана одна попытка A03 за пять минут до expiry действующего JWT. Ошибка renewal
оставляет действующий token до expiry или текущего 401. HTTP 401 сам не запускает
refresh. Применяется только более долгий JWT того же owner. Сравнение credential
revision и mutation сериализованы в SecureStorage. Старый 401 и refresh не меняют
новую сессию даже при одинаковом JWT. Public 401 отображает понятную ошибку входа.

Logout очищает session credentials и auth state. Общая очистка feature state,
активной записи, результатов и загрузок остаётся .34/.49. Эти интеграционные
критерии не выданы за готовые. Keychain smoke .04 уже проходил на исходном
storage lifecycle, здесь повторены storage unit tests после изменений.

Status review, независимый отчёт ожидается. Нет automatic accepted.


## Исправления по review — 2026-11-03

[REVIEW-FE-001.09-01](../reviews/REVIEW-FE-001.09-01.md) воспроизвёл F01–F03.
При неподтверждённом удалении или изменении credential блокируется в текущем
процессе. Matched 401 уведомляет router даже при ошибке очистки. Исключение
уведомления завершает запрос безопасной ошибкой. Если старый JWT после неудачного
обновления подтверждён без изменений, его revision и таймер expiry сохраняются.
Частично записанный JWT требует полного успешного повтора входа. При отказе OS
удаление между запусками не подтверждено, приложение явно сообщает об ошибке
защищённого хранилища. Проверки authors delta: 57 auth/storage/widget tests PASS
и 18 .15 tests PASS в совместном запуске, scoped analyze No issues found.
Повторный независимый review завершён. REVIEW-FE-001.09-01 подтверждает F01–F03 fixed, 57 auth/storage/widget tests и 18 capture tests, открытых findings нет.


Дополнительная macOS regression после изменения очереди credentials. Обе локальные
подписанные сборки harness из .04 созданы с прежним SDK и signing override. Повтор
12 отдельных фаз в Debug и 12 в Release прошёл. `codesign --verify --deep --strict`
и applied entitlements PASS для обоих bundles. Cwd frontend, evidence в
`/tmp/dictai-resume-20261103/{debug,release}-results.json`. Нативные Keychain операции
проверены на изолированных fixtures. Частичный сбой logout/renewal проверен unit
fixtures, что не подтверждает физическое удаление при отказе OS.
