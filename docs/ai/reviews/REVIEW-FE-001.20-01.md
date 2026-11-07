---
id: REVIEW-FE-001.20-01
task_ids: ["TASK-FE-001.20"]
reviewer: /root/results_contracts
mode: read-only
status: open
completion: partial
---

# REVIEW-FE-001.20-01

## Scope

2026-11-05. Независимый reviewer `/root/results_contracts`. База frontend
`80959cc10eacabf45fbf461dbe596030e4e7277c`, текущий рабочий diff. Проверены
`pending_upload_store.dart`, `dto/pending_upload.dart`, `pending_upload_store_test.dart`
и карточка .20. Прочитаны связанные .18/.19, owner/session guards и план интеграции.
Reviewer пишет только этот отчёт. Backend HEAD `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`
использован read-only для сверки U01/U02 и owner-scoped idempotency fingerprint.

## Findings

| ID / priority | File | Impact | Evidence | Recommendation | Disposition |
|---|---|---|---|---|---|
| F01 / P2 | `lib/features/record/data/pending_upload_store.dart:381` и `:194` | Вызов может вернуть запись прежнего пользователя после завершения его сессии. Следующий consumer способен получить старые local entries или accepted job reference. | `_lockOwner` проверяет generation, затем `finally` ожидает `lock.close()` перед выдачей результата. Изолированный probe переключил session flag в microtask из последней успешной проверки при существующем owner directory. После закрытия lock `list()` вернул запись, хотя flag уже false. `submit` также ожидает закрытия собственного `sendLock` после inner owner guard. | После всех awaited cleanup операций повторно проверить generation прямо перед успешной выдачей результата. Сохранить освобождение locks и уже подтверждённые durable commits. Проверить переключение между последним pre-cleanup guard и завершением операции. | open |

## Verification

Cwd `/Users/verliiar/Desktop_application`, macOS arm64, pinned Flutter 3.41.3 /
Dart 3.11.1 из `.dart_tool/codex-tools/flutter`, `PUB_CACHE=/Users/verliiar/.pub-cache`.

| Проверка | Результат | Статус / граница |
|---|---|---|
| `flutter test --no-pub test/features/record/pending_upload_store_test.dart test/features/record/v2_upload_api_test.dart test/features/record/wav_validator_test.dart --reporter expanded` | 110/110 тестов прошли | PASS. Проверены 20 journal и 90 .18/.19. |
| `flutter analyze --no-pub lib/features/record/data/pending_upload_store.dart lib/features/record/data/dto/pending_upload.dart test/features/record/pending_upload_store_test.dart` | No issues found | PASS. Scoped Dart. |
| `dart format --output=none --set-exit-if-changed` по тем же трём paths | 3 files, 0 changed | PASS. |
| Whitespace scoped new files/card и local links | Diagnostics отсутствуют | PASS. |
| Изолированный `flutter test` с текущим store и флагом session generation | 1/1 probe воспроизвёл выдачу прежней записи после смены флага | PASS воспроизведения F01. Probe жил во временном каталоге. |
| Backend `db/upload_v2.go` | Сверены owner/key, SHA-256 bytes, options, processing/engine/config revisions и исходы 202/409 | PASS сверки исходников. |
| Real gateway, межпроцессный и power-loss smoke, UI restart и авторизованная смена аккаунта | Не запускались | NOT RUN. |

SHA-256 первого прохода.

- `pending_upload_store.dart` `13d7fe08ac408f2dee3c5dcc8227b3d3702caa78067013e20eeccb53511af91d`
- `pending_upload.dart` `baf83c800ea962312a48d8e69c2edf1fcd9f2a2a0c0392cef7f3a4ecf18886e4`
- `pending_upload_store_test.dart` `a49a9311dbfa9a2ee235f1300cdf867f7bf8baf379365e1f1cef2d230cea31fd`

## Strengths and residual risk

Store публикует owned WAV и metadata до POST. Тесты покрывают переоткрытие,
byte-exact replay с прежним ключом, 409, accepted poll-only, ошибки файлов,
SHA-256 vectors, квоту и одновременный submit. Accepted receipt коммитится
до удаления локального WAV. Повреждённые записи изолированы при чтении.

Будущие callers .23/.24/.34 должны отменять token прежней сессии до смены
владельца и проверять generation при публикации данных. Эта граница явно
зафиксирована в карточке. Её runtime verification и поведение Results остаются
интеграционными проверками. F01 ожидает независимого delta review. Приёмка
остаётся решением владельца.
