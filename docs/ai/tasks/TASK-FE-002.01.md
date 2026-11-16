---
id: "TASK-FE-002.01"
plan: "PLAN-FE-002"
title: "Зафиксировать iOS toolchain, deployment target и manifest Runner"
status: "review"
owner: "/root/ios_baseline"
priority: "P0"
delivery_stage: "ios"
depends_on: []
scope: ["docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md", "docs/ai/tasks/TASK-FE-002.01.md"]
planned_paths: ["docs/testing/IOS_BASELINE.ru.md", "docs/testing/IOS_SCAFFOLD_MANIFEST.ru.md"]
reuses_tasks: ["TASK-FE-001.01", "TASK-FE-001.16", "TASK-FE-001.36"]
implementation_selected: true
---

# TASK-FE-002.01: Зафиксировать iOS toolchain, deployment target и manifest Runner

## Goal

Зафиксировать iOS toolchain, deployment target и manifest Runner. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Последующее поручение 2026-11-16 выбрало реализацию .01–.05 пятью агентами.
Write gate и owner назначены в active-plan; зависимости проверяются до записи.
Planning baseline исходников: `44ace4d`; текущий execution baseline: `260b149`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.01](../tasks/TASK-FE-001.01.md), [TASK-FE-001.16](../tasks/TASK-FE-001.16.md), [TASK-FE-001.36](../tasks/TASK-FE-001.36.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [x] Зафиксированы фактически доступные Flutter/Dart/Xcode/CocoaPods, simulator/device, совместимость pinned record, audioplayers, secure storage, file picker и path provider; отсутствие инструмента отмечено NOT RUN/blocker.
- [x] Выбран минимальный iOS deployment target по требованиям pinned SDK/плагинов и обоснован доступными источниками; версия не выдумана заранее и SDK/lock не обновлены.
- [x] Описаны команды генерации Runner текущим SDK и полный список создаваемых tracked файлов; manifest согласован с exact scope .02 до записи scaffold.
- [x] Разделены simulator build, реальная запись на iPhone и подписанный candidate; bundle identifier/team/signing перечислены как решения/доступы, секреты не записаны.
- [x] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Первый безопасный шаг реализации iOS-направления. Только аудит и два документа; не генерировать ios/, не менять зависимости/подпись. Инвентаризацию шаблона можно получить в изолированном временном каталоге без backend.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification

Cwd: `/Users/mxdnght/dictai-app`. Host macOS 26.5.2 arm64. Полное source evidence
и границы проверок — [IOS_BASELINE.ru.md](../../testing/IOS_BASELINE.ru.md),
точный manifest — [IOS_SCAFFOLD_MANIFEST.ru.md](../../testing/IOS_SCAFFOLD_MANIFEST.ru.md).

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| `sw_vers`; `uname -m`; `xcode-select -p`; `xcodebuild -version`; `pod --version` | frontend / macOS | Фактический toolchain | macOS 26.5.2 arm64; Xcode26.5 build17F42; CocoaPods1.16.2 | PASS | Инвентаризация, не приложение |
| `CI=true flutter --no-version-check --version` | frontend / coordinator command outside initial sandbox | Версии без upgrade | Flutter3.44.0 stable revision559ffa3f75; Dart3.12.0 | PASS | Evidence координатора; plain --version ранее завис в remote version check и остановлен |
| `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart --version`; SDK git HEAD/cache version | frontend / read-only | Согласованный SDK | Dart3.12.0; revision совпал с Flutter output | PASS | Без SDK upgrade |
| `xcrun simctl list devices available`; `xcrun xctrace list devices` | frontend / вне initial sandbox | Доступные targets | 0 available Simulator; 0 online iPhone, 1 offline iOS18.5 | PASS | Только состояние на время аудита; device smoke NOT RUN |
| `xcrun simctl list runtimes`; `xcodebuild -showsdks` | frontend / coordinator command | Runtime/SDK | Runtime отсутствуют; iphoneos26.5/iphonesimulator26.5 есть | PASS | Наличие SDK не означает Simulator launch |
| Сверка pubspec/lock и pinned native manifests; SHA-256 archive | frontend / Python3, cached packages, coordinator download в /tmp | Обоснованный target без обновлений | iOS13.0; audio archive SHA совпал с lock; package config проекта пока нет | PASS | Source minima; linking в .02 |
| `CI=true flutter --no-version-check create --platforms=ios --project-name dict_ai --org com.dictai --no-pub /tmp/dictai-ios-scaffold-00201` | frontend / coordinator command; output только /tmp | Полный manifest текущего SDK | Exit0, Flutter сообщил52 файла; проверены40 ios paths, все входят в scope .02; Podfile отдельно из SDK template | PASS | Никакой ios/ в repository не создан |
| Python3: новые local Markdown links; 40-path manifest против temp scaffold и scope .02; полный tracked/untracked/no-index diff; `git diff --check` | frontend | Согласованность документов и whitespace | Проверено перед handoff | PASS | Только exact scope .01; остальные файлы принадлежат координатору |
| Flutter analyze/test/build; device/backend/signing smoke | frontend | Не требуется для doc-only .01 | Не запускались | NOT RUN | .02+ gates; пользователь готовит iPhone и тестовый HTTPS URL |
| Независимый [REVIEW-FE-002.01-02](../reviews/REVIEW-FE-002.01-02.md) и delta | Независимый reviewer, назначенный координатором | Review без блокирующих findings | Reviewed/complete; P3 F01 исправлен и подтверждён delta, открытых findings нет | PASS | Только doc-only .01; accepted не выставлен |

## Result

2026-11-16: реализован exact doc-only scope .01: IOS_BASELINE.ru.md,
IOS_SCAFFOLD_MANIFEST.ru.md и эта карточка. Подтверждены установленный toolchain,
iOS13.0 по pinned native sources и 40-file ios template manifest; все эти пути
уже есть в scope .02. Podfile и .metadata согласуются в .02; координатор добавил
ios/Podfile.lock в scope/planned_paths .02 до CocoaPods integration. Manifest
синхронизирован с этим разрешением по P3 F01 независимого reviewer; в .01 lock
не создавался. Независимый delta review подтвердил исправление F01;
открытых findings нет, последний acceptance criterion закрыт.

SDK/dependencies/pubspec.lock, приложение, платформы и backend не менялись.
Simulator runtime и online iPhone отсутствовали во время инвентаризации; это
ограничения следующих runtime проверок, не blocker завершения doc-only аудита.
Пользователь сообщил, что подключит iPhone и укажет тестовый HTTPS endpoint;
готовность должна быть перепроверена при соответствующем этапе.

Обязательные document checks выполнены; независимый
[REVIEW-FE-002.01-02](../reviews/REVIEW-FE-002.01-02.md) завершён вместе с delta,
reviewed/complete PASS. Карточка остаётся в status review; dependency gate .01
готов к переходу .02 по решению координатора. Write ownership двух документов
docs/testing передан .02; исполнитель .01 больше их не меняет. Accepted и
публикации нет.
