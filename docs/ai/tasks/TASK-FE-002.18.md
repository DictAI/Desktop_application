---
id: "TASK-FE-002.18"
plan: "PLAN-FE-002"
title: "Подтвердить реальный iPhone E2E и platform readiness"
status: "blocked"
owner: "/root"
priority: "P0"
delivery_stage: "ios"
depends_on: ["TASK-FE-002.17"]
scope: ["docs/testing/IOS_DEVICE_E2E.ru.md", "docs/testing/IOS_BACKEND_GATE.ru.md", "docs/ai/tasks/TASK-FE-002.18.md"]
planned_paths: ["docs/testing/IOS_DEVICE_E2E.ru.md", "docs/testing/IOS_BACKEND_GATE.ru.md"]
reuses_tasks: ["TASK-FE-001.36", "TASK-FE-001.37", "TASK-FE-001.38", "TASK-FE-001.39", "TASK-FE-001.40", "TASK-FE-001.42"]
implementation_selected: true
---

# TASK-FE-002.18: Подтвердить реальный iPhone E2E и platform readiness

## Текущий результат и blocker — 2026-11-18

Пользователь поручил закончить ранее выбранную очередь и push; owner `/root`.
Выполнено независимое read-only исследование prerequisites агентом
`/root/readiness_audit`, затем coordinator подготовил воспроизводимые
[device E2E шаги](../../testing/IOS_DEVICE_E2E.ru.md) и
[backend gate](../../testing/IOS_BACKEND_GATE.ru.md). Это подготовка evidence,
не завершённый iPhone/backend E2E. Dependency .17 закрывает только host regression.

**Blocked:** valid signing identities=0, DEVELOPMENT_TEAM отсутствует; paired
запись iPhone13mini/iOS18.5 существует, но DDI services unavailable и tunnel
отключён. Разрешённый актуальный runtime origin/operator, два тестовых аккаунта,
deployed SHA/model/artifact readiness для полного E2E не подтверждены. Подпись,
устройство, backend, secrets и production данные не менялись. Новый endpoint
или backend task не создаётся.

Для продолжения нужны готовые signing/team/device services и операторский
runtime evidence по двум harness docs. Прежний synthetic STG smoke/Simulator
не заменяет реальный E2E. Полная приёмка отсутствует, status blocked сохраняется.

## Verification текущего prerequisite scope

Cwd frontend `/Users/mxdnght/dictai-app`, read-only backend
`/Users/mxdnght/dictai`, SHA `92ad6e4572a3b12a601ba3ab7e5cc385a21694ae`.
Host macOS26.5.2 arm64/Xcode26.5/SDK26.5, pinned Flutter3.41.3/Dart3.11.1.

| Command / scenario | Actual | Status | Limitation |
|---|---|---|---|
| `xcodebuild -version`; `xcrun --sdk iphoneos --show-sdk-version`; `sw_vers` | Xcode26.5/build17F42, SDK26.5, macOS26.5.2 | PASS inventory | Не E2E |
| `security find-identity -v -p codesigning`; source signing inspection | 0 valid identities, DEVELOPMENT_TEAM отсутствует | PASS inventory | Подписанный запуск blocked |
| `xcrun devicectl list devices --json-output <private-temp-json>` | Paired iPhone13mini/iOS18.5, developer mode enabled, DDI unavailable/tunnel disconnected | PASS inventory | Device IDs/raw JSON вне Git, запуска нет |
| Source .16 production main Simulator build/install/launch; unsigned device build `--debug --no-codesign --no-pub` | 7.2s Simulator / 26.0s device compile PASS; проверенный source сохранён в `8da7b55` | PASS compile | Device protection branch компилируется; не signed runtime |
| Backend current SHA/contracts/routes/runtime prerequisites read-only | Source baseline и gaps записаны в IOS_BACKEND_GATE | PASS source audit | Runtime deployment не проверен |
| Hardware/backend сценарии D01–D12, TLS/Keychain/lock/Files/model quality/A→B | Не выполнялись | NOT RUN | Нет готовых внешних prerequisites |
| YAML/status/scope/local links/full doc diff и independent .18-01 | Coordinator/reviewer PASS, .18-01 reviewed/complete, actionable findings нет | PASS | Отдельно от hardware readiness |

## Result prerequisite scope

Созданы только два документа из exact scope и обновлена эта карточка;
приложение/backend/device/signing не менялись. Указаны воспроизводимые шаги,
фактический inventory, ожидаемое evidence и конкретные blockers. Физические
acceptance criteria остаются открыты, `accepted` не выставлен. Независимый [review документов .18-01](../reviews/REVIEW-FE-002.18-01.md)
reviewed/complete, actionable findings нет; внешний blocker сохраняется.

## Текущее поручение — 2026-11-17

Пользователь выбрал оставшуюся очередь для максимально доступной реализации
с до 10 субагентами. Эта задача выбрана; старт записи требует назначения
точного owner и завершения checks/review предыдущего implementation scope.
Physical evidence фиксируется отдельно и не выдумывается. Прежние записи
«не выбрана» ниже описывают planning baseline и заменены этим поручением.

## Goal

Подтвердить реальный iPhone E2E и platform readiness. Один завершённый этап iOS/iPhone очереди.

## Context

[PLAN-FE-002](../plans/PLAN-FE-002.md), [активный реестр](../active-plan.md),
[WORKFLOW](../WORKFLOW.md), [текущая архитектура](../architecture.md).
Поручение 2026-11-16 разрешает перепланирование; эта реализация ещё не выбрана.
Baseline исходников: `44ace4d`. Backend snapshot остаётся историческим; перед
использованием API сверять доступный актуальный контракт read-only. Новые API
и backend-задачи этим планом не назначаются.

Reuse: [TASK-FE-001.36](../tasks/TASK-FE-001.36.md), [TASK-FE-001.37](../tasks/TASK-FE-001.37.md), [TASK-FE-001.38](../tasks/TASK-FE-001.38.md), [TASK-FE-001.39](../tasks/TASK-FE-001.39.md), [TASK-FE-001.40](../tasks/TASK-FE-001.40.md), [TASK-FE-001.42](../tasks/TASK-FE-001.42.md).
Старые статусы/evidence сохранены; desktop PASS не означает iOS PASS.

## Acceptance criteria

- [ ] Есть разрешённый HTTPS test-origin/operator/accounts, актуальный backend SHA и существующие runtime prerequisites; секреты и аудиозаписи не попадают в Git.
- [ ] На физическом iPhone подтверждены запись/lock/background/interruption, Files import, TLS/Keychain, network loss/recovery, canonical/player/export/delete/logout и account isolation.
- [ ] Зафиксированы iPhone/iOS/Xcode/SDK/build/длительность/память и точные PASS/FAIL/NOT RUN; Simulator и synthetic tests не заменяют hardware/backend/model evidence.
- [ ] Если host/device/signing/backend/access/quality недоступны, задача становится blocked с конкретным недостающим evidence; существующие workspace access/security caveats не объявлены исправленными клиентом.
- [ ] Назначенный owner реализовал exact scope, записал реальные проверки и получил внутренний независимый review; существенные findings устранены или явно переданы как ограничения, `accepted` не выставлен автоматически.

## Implementation notes

Согласовать operator и реальные записи отдельно; не менять backend. Это перенесённый существующий integration gate, не новый backend task/endpoint.

Очередь выполняется последовательно: предыдущая карточка — интеграционная
зависимость, в том числе для общего writer router/providers/Runner/detail. Это
не требование заново реализовывать готовый desktop код. Перед стартом назначить
owner и выбрать реализацию. Отсутствующие пути перечислены в planned_paths и
создаются только при необходимости критериев; обязательные deliverables не
пропускаются. Изменение exact scope фиксируется до записи.
Review организует координатор агентами; промежуточное review пользователя
не требуется. Commit/push/merge/release отдельно не разрешены.

## Verification planning baseline

Cwd: корень frontend. SDK/host/device записываются при выполнении.

| Command / scenario | Cwd / environment | Expected | Actual | Status | Limitation |
|---|---|---|---|---|---|
| flutter build ios --simulator --debug; flutter build ios --debug --no-codesign — при соответствующем окружении, не доказательство установки | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |
| Подписанный запуск на iPhone и opt-in реальные API-сценарии по IOS_DEVICE_E2E.ru.md; без production данных | frontend; нужный SDK/Xcode/iPhone по сценарию | Acceptance criteria подтверждены реальным evidence | Не выполнялось | NOT RUN | Сейчас только планирование |

## Result planning baseline

2026-11-16: карточка подготовлена для переориентации на iOS. Реализация и её
проверки не выполнялись. Проверки документов и независимый planning-review
записываются в PLAN-FE-002/active-plan; они не доказывают готовность приложения.
Приёмка пользователем отсутствует, публикация не разрешена.
