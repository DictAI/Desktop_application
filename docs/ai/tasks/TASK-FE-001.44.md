---
id: TASK-FE-001.44
plan: PLAN-FE-001
title: "Добавить встроенный аудиоплеер и owned cache original WAV"
status: draft
owner: unassigned
priority: P1
readiness_category: A
phase: "3"
depends_on: ["TASK-FE-001.29", "TASK-FE-001.30"]
backend_tasks: []
backend_requests: []
api_contracts: ["U04"]
blocked_by: []
scope:
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "test/features/results/result_audio_cache_test.dart"
  - "test/features/results/result_audio_player_test.dart"
  - "docs/ai/tasks/TASK-FE-001.44.md"
planned_paths:
  - "lib/features/results/data/result_audio_cache.dart"
  - "lib/features/results/presentation/result_audio_player.dart"
  - "lib/features/results/presentation/result_detail_screen.dart"
  - "test/features/results/result_audio_cache_test.dart"
  - "test/features/results/result_audio_player_test.dart"
delivery_stage: current
---

# TASK-FE-001.44: Добавить встроенный аудиоплеер и owned cache original WAV

## Goal

Полноценные Play/Pause/перемотка original WAV в результате, bounded download/cache и cleanup, без будущего редактора.

Текущий этап. Реализация после завершения пересмотра и независимого review, в порядке DAG.

## Context

[План](../plans/PLAN-FE-001.md), [окончательный UX](../research/FRONTEND_TARGET_UX.ru.md),
[backend change requests](../research/FRONTEND_BACKEND_CHANGE_REQUESTS.ru.md),
[API snapshot](../research/BACKEND_API_CONTRACTS.ru.md),
[target snapshot](../research/BACKEND_TARGET_SCOPE.ru.md).
Frontend baseline `80959cc10eacabf45fbf461dbe596030e4e7277c`, backend snapshot
`f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`. BACKEND_* сохраняются неизменными;
новые продуктовые решения 2026-10-26 не являются реализованным backend-контрактом.

FE prerequisites: [TASK-FE-001.29](TASK-FE-001.29.md), [TASK-FE-001.30](TASK-FE-001.30.md).
Категория A: локальный scope по существующему API; реальный platform smoke отдельно.
Новых backend task ID пока нет: их выдаёт backend-команда. BR-ID ниже —
разделы исследования, не backend task-карточки.

## Этап и решение — 2026-11-02

Нужна сейчас: полноценный Play/Pause/seek/cache по U04; не строить sample/editor seams заранее.

**Текущая работающая версия.** Production использует только существующие API/данные; изолированные fakes для тестов этих контрактов разрешены. Именование Speaker/назначения/именованный экспорт не prerequisite.

## Acceptance criteria

- [ ] В реальном result detail есть Play/Pause/seek по завершённому original WAV, синхронные duration/position/end/error/dispose.
- [ ] U04 авторизованно загружается потоком в полностью завершённый app-owned файл; 1 GiB не читается целиком в RAM, Range/ранний streaming не обещаются.
- [ ] Loading/ready/playing/paused/error/unavailable явны; недоступное audio не скрывает canonical transcript, retry только GET/local player.
- [ ] Owner/audio/job cache bounded quota/inventory; late download/logout/delete изолированы, pending source/user WAV не удаляются.
- [ ] Используется существующий audioplayers. Нет speaker sample buttons/range editor seam или mock player ради будущего .45; cleanup интегрируется .32/.34.
- [ ] Записаны релевантные format/analyze/tests или docs checks, команды/cwd/actual PASS/FAIL/NOT RUN и ограничения.
- [ ] Независимый reviewer проверил выбранный scope; findings/ограничения записаны, accepted требует решения владельца.

## Implementation notes

Выполнять только current scope по существующим API и точным frontmatter paths. Fakes относятся к tests реального wire/оборудования, не к runtime бизнес-данным будущего backend. Не добавлять layers/packages/неподтверждённые endpoints или player/editor abstractions на вырост. Один writer на shared paths, порядок DAG обязателен. Backend и BACKEND_* snapshots read-only. Текущая коррекция — документация; после review разрешено продолжение выбранного current этапа. Commit/push/merge запрещены.

## Verification

План проверок текущего scope, **NOT RUN** в этой коррекции документации.

| Проверка | Статус / граница |
|---|---|
| `flutter test test/features/results/result_audio_cache_test.dart test/features/results/result_audio_player_test.dart` | NOT RUN; planned tests/docs не создаются этой коррекцией |
| Формат/analyze только при реализации Dart, platform/live smoke при наличии разрешённой среды | NOT RUN; fakes не подтверждают native/model/стенд |
| Полный diff, ссылки/DAG/paths и независимый review документации | Выполняются coordinator, результаты в PLAN/active-plan |

## Result

Не реализовано. Создана только карточка планирования; функциональный код,
API-клиенты, DTO, платформы и зависимости не менялись. Mock evidence не означает
серверного сохранения, multi-device readiness или именованного server export.
Implemented ≠ verified ≠ accepted; приёмки и разрешения публикации нет.
