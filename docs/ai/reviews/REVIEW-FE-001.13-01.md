---
id: REVIEW-FE-001.13-01
task_ids: ["TASK-FE-001.13"]
reviewer: /root/review_snapshot_ui
mode: read-only
status: reviewed
completion: complete
---

# REVIEW-FE-001.13-01

## Scope

2026-11-07. База frontend `80959cc10eacabf45fbf461dbe596030e4e7277c`,
baseline .12 в [REVIEW-FE-001.12-01](REVIEW-FE-001.12-01.md). Проверены
изменения contact UI и state в `workspace_detail_screen.dart` и
`workspace_notifier.dart`, новый `contact_crud_widget_test.dart` и карточка .13.
Для проверки контракта прочитаны реальные workspace router, W06–W09 handlers,
service, PostgreSQL repository и ограничение `UNIQUE(workspace_id,email)`.
Получатели сверены с backend `notification-service/internal/durable/worker.go`.

## Findings

### F01 / P2. Подтверждённый конфликт или исчезнувший контакт блокируют дальнейшие изменения

- File: `lib/features/workspace/presentation/workspace_notifier.dart:484–514`
  первого прохода.
- Impact: после неопределённого PUT пользователь может застрять в recovery,
  которое блокирует все изменения контактов этого workspace.
- Evidence: при повторном W06 список может показать, что нужный email уже
  занят другим ID или редактируемого ID больше нет. Conflict сейчас определяется
  только для add. Для edit UI оставляет pending и предлагает retry. При занятом
  email клиентская проверка :372–379 отклоняет retry, сохраняя pending. При
  исчезнувшем ID реальный W08 отдаёт not found, а ветка `retry ||` :430 возвращает
  пользователя к той же проверке. Cancel закрывает диалог, но recovery lock
  сохраняется. Исходные тесты покрывают положительное подтверждение lost PUT,
  но не эти два результата W06.
- Recommendation: считать оба результата W06 терминальными для прежнего edit,
  обновлять список, очищать pending и объяснять, почему повтор недоступен.
  Добавить регрессии, подтверждающие отсутствие дополнительного PUT и разблокировку CRUD.
- Disposition: fixed with independent evidence. W06 завершает recovery при
  конфликте с другим ID или исчезновении target. Список обновляется, прежний
  retry скрывается и Add разблокируется. При исчезнувшем ID в открытом диалоге
  также скрывается Save. Два новых widget-сценария подтверждают один PUT.

### F02 / P3. Scoped analyzer сигнализирует о двух многострочных ветках без фигурных скобок

- Files: `lib/features/workspace/presentation/workspace_detail_screen.dart:336`,
  `lib/features/workspace/presentation/workspace_notifier.dart:518` первого прохода.
- Impact: целевая статическая проверка задачи завершается с кодом 1.
- Evidence: два info `curly_braces_in_flow_control_structures` при повторном analyze.
- Recommendation: добавить блоки в указанных условиях и повторить analyze.
- Disposition: fixed with independent evidence. Оба условия используют блоки,
  повторный scoped analyze завершился с кодом 0.

Открытых actionable findings нет.

## Verification

Самостоятельный прогон из корня frontend на macOS arm64. Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, существующий pub cache,
`--no-pub`.

| Проверка | Результат | Статус |
|---|---|---|
| `flutter test --no-pub test/core/network/logging_test.dart test/features/workspace --reporter expanded` | 67 tests, включая 12 новых contact widget tests | PASS, сценарии F01 отсутствуют |
| `flutter analyze --no-pub` по трём .13 Dart paths и logging test | 2 info .13, exit 1 | FAIL, F02 |
| `dart format --output=none --set-exit-if-changed` по тем же четырём путям | 0 изменений | PASS |
| `git diff --check` для изменённых tracked source и `git diff --no-index --check /dev/null test/features/workspace/contact_crud_widget_test.dart` | Whitespace diagnostics отсутствуют | PASS |
| Delta `flutter test --no-pub test/features/workspace --reporter expanded` | 65 tests, включая 14 contact widget tests и оба сценария F01 | PASS |
| Delta scoped `flutter analyze --no-pub` и `dart format --output=none --set-exit-if-changed` по двум production paths и contact widget test | No issues found, 3 formatted, 0 changed | PASS |
| Delta tracked diff и no-index check по тем же путям | Whitespace diagnostics отсутствуют | PASS |

SHA-256 первого прохода:

- `workspace_detail_screen.dart` — `e42a2dc64c5c47bbd07e4714bd7dd15840ad58cac181fd9b4bc659a31aad47e7`
- `workspace_notifier.dart` — `e3c935e32940a0585f28b6bf65bc26d6261e13a68cd9d85afcd6a4852c58538b`
- `contact_crud_widget_test.dart` — `67b923e348c53cf6ed7798477198e72a1e366d5e3babcf490b0c44633d53a62a`

SHA-256 финального проверенного delta:

- `workspace_detail_screen.dart` — `37519debbbbd416effdbdea5a7a6fb47b78f7f8b2435cdec195a697a34fcd125`
- `workspace_notifier.dart` — `4933118011443d0cd37833e979c0a5a171c75666283129d89deb7b55f71641b1`
- `contact_crud_widget_test.dart` — `c3091e0af803db4793408295133a34f53288509bf8673bd6a083625395f977b5`

## Strengths and residual risk

Тесты покрывают пустой JSON `null`, реальные формы W07/W08 с ID из backend,
локальную проверку и 409, одновременные действия, read-before-retry после
неоднозначного исхода, подтверждение удаления и отказ 403. Workspace и его
контакты показаны отдельно от Speaker labels и учётных записей. Текст про
email соответствует получателям backend и учитывает зависимость доставки
от серверных настроек. Живые W06–W09 и доставка писем не проверялись.
