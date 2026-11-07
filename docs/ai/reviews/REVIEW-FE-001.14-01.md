---
id: REVIEW-FE-001.14-01
task_ids: ["TASK-FE-001.14"]
reviewer: /root/review20_resume
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.14-01

## Scope

2026-11-06. Независимый reviewer `/root/review20_resume`, не автор .14.
База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`, текущий рабочий diff.
Проверены удаления `lib/features/voice_profile/data/voice_profile_api.dart` и
`lib/features/voice_profile/data/dto/voice_profile_dto.dart`, удаление import и
`voiceProfileApiProvider` из `lib/shared/providers/providers.dart`, новый
`test/features/workspace/retired_voice_api_test.dart` и карточка .14.

В providers также существуют прежние изменения .05/.09. Они сохранены и не
выдаются за результат .14. Сверены AGENTS/WORKFLOW, план, backend API/target
snapshots, независимый .11-01 и реальные gateway router/retired_profiles_test.go
в backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6` read-only.
Reviewer пишет только этот отчёт.

## Findings

Actionable findings P0–P3 в выбранном scope не обнаружено.
Независимый review завершён. Оснований менять текущую реализацию .14 не найдено.
Приёмка остаётся решением владельца.

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, закреплённый Flutter
3.41.3 / Dart 3.11.1 из `.dart_tool/codex-tools/flutter`,
`PUB_CACHE=/Users/verliiar/.pub-cache`, `CI=true`,
`FLUTTER_SUPPRESS_ANALYTICS=true`. Проверки выполнены самим reviewer.

| Команда или сценарий | Actual | Статус и граница |
|---|---|---|
| `flutter test --no-pub test/features/workspace/retired_voice_api_test.dart test/features/workspace/profile_free_flow_test.dart test/features/workspace/workspace_api_test.dart --reporter expanded` через закреплённый SDK | 27/27 tests, exit 0 | PASS. Новый runtime regression gate, три profile-free widget tests, 23 W API tests. |
| `flutter analyze --no-pub lib/shared/providers/providers.dart test/features/workspace/retired_voice_api_test.dart` через закреплённый SDK | No issues found, exit 0 | PASS scoped analyze. |
| `dart format --output=none --set-exit-if-changed` по двум оставшимся Dart paths | 2 files, 0 changed | PASS. Удалённые файлы не передавались formatter. |
| `rg` и независимый Python scan всего runtime `lib/**/*.dart` для retired route/client/DTO/provider/import | Совпадений нет. Оба удалённых файла фактически отсутствуют. | PASS. Сканирование не ограничено общими providers. |
| `git diff --check` для tracked scope и `git diff --no-index --check /dev/null test/features/workspace/retired_voice_api_test.dart` | Whitespace diagnostics нет | PASS. Exit 1 для no-index означает новый файл. |
| Markdown-ссылки карточки .14 | Пять локальных ссылок существуют | PASS. |
| Backend gateway retirement и контракт §10 | `/voice-profiles/*` исключены из runtime; backend regression test ожидает 404 и для authenticated requests | PASS сверки исходников. Backend tests и реальные HTTP-запросы не запускались. |
| Full frontend analyze/build и живой backend | Не запускались reviewer | NOT RUN. Проверка удаления не объявляет готовность всей текущей интеграции. |

SHA-256 оставшихся проверенных Dart-файлов.

- `providers.dart` — `e7647dcb3d3f38144989d157e17e3900b5b0040cb151162582dc332ef11668f1`
- `retired_voice_api_test.dart` — `e34a45560300bcf3be98a1ca1b5f97ccc1f44b5ed6f1101fbb9acb75d64566c9`

## Strengths and residual risk

Неиспользуемые client, DTO и provider удалены после consumers .11. Они не заменены
заглушкой или compatibility adapter. Name/email contacts и действующие workspace
API сохранены, их проверки прошли. Исторические документы и fixtures не удалялись,
пакеты и lockfile в scope не включались.

Новый тест служит отрицательным regression gate для возврата известных retired
URL и wiring во всём runtime Dart-коде. Он не заменяет анализ реальных backend
контрактов при последующих изменениях. Переход текущих форм записи на V2 остаётся
работой .23/.24. Новые функции именования спикеров этим удалением не реализованы.
Task status `accepted` или разрешение публикации данный отчёт не устанавливает.
