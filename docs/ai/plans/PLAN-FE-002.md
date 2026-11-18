---
id: "PLAN-FE-002"
title: "DictAI для iOS/iPhone на существующем Flutter и batch API"
status: "in_progress"
owner: "primary-agent"
selected_tasks: ["TASK-FE-002.01", "TASK-FE-002.02", "TASK-FE-002.03", "TASK-FE-002.04", "TASK-FE-002.05", "TASK-FE-002.06", "TASK-FE-002.07", "TASK-FE-002.08", "TASK-FE-002.09", "TASK-FE-002.10", "TASK-FE-002.11", "TASK-FE-002.12", "TASK-FE-002.13", "TASK-FE-002.14", "TASK-FE-002.15", "TASK-FE-002.16", "TASK-FE-002.17", "TASK-FE-002.18", "TASK-FE-002.19", "TASK-FE-002.20"]
planning_authorized: true
implementation_authorized: true
frontend_commit: "44ace4d"
requirements_revision: "ios-2026-11-16"
---

# PLAN-FE-002: DictAI для iOS/iPhone

## Итог доступной реализации — 2026-11-18

.16 сохранена commit `8da7b55`/push origin/main. .17 review, owner `/root`
после quota interruption implementer:5 новых joined tests и весь803 host suite
PASS34s, analyze no issues, scoped format PASS. Full format имеет5 неизменённых
baseline failures вне scope. .18/.19 blocked: signing0/team отсутствует, iPhone
DDI/tunnel недоступны, runtime/operator/release inputs не подтверждены;
account-deletion HTTP в backend отсутствует. Подготовлены opt-in harness и
release checklist; hardware E2E/candidate/Store NOT RUN. Независимый final review
`/root/final_regression_review` завершён: .17-01/.18-01/.19-01 reviewed/complete,
actionable findings нет; .18/.19 blocked сохраняются. Новые5 tests/format
повторены reviewer PASS, full803/analyze evidence прочитано отдельно.

## Текущий handoff .17 — 2026-11-18

.16 checks/review complete, commit `8da7b55` отправлен в origin/main. .17
in_progress, sole writer `/root/batch_regression`, exact scope карточки;
source .16 frozen. Reviewer `/root/cleanup_review_finish` получает только
зарезервированные .17-01/.18-01/.19-01 reports. Coordinator готовит независимые
read-only prerequisites/evidence .18/.19 и фиксирует external blockers; никакие
signing/device/backend mutations или release не выполняются.

## Возобновление .16 — 2026-11-18

.16 source frozen/review:262 targeted PASS, analyzer no issues, independent168
и format21 PASS. Native9 XCTest PASS; Simulator backup readback подтверждён,
file protection unavailable честно обозначен simulator-only capability;
device builds требуют strict protection readback. Native capture/export smoke
PASS, final main Simulator build7.2s/install/launch и unsigned device compile26.0s
PASS. Device compile не является signed install/runtime. .16-01
reviewed/complete; F01–F04 fixed with evidence, открытых findings нет.
Host/Simulator gate .16 завершён; .17 получает следующий handoff. Physical NOT RUN.

## Текущий handoff .16 — 2026-11-18

.15 checks/review complete, commit3665fae/push origin/main. .16 in_progress,
owner `/root/cleanup_prep_finish`, native/filepolicy writer
`/root/filepolicy_prep_finish` в непересекающихся exact scopes active-plan.
Reviewer `/root/cleanup_review_finish`, reserved .16-01. .17 ещё не стартовала.

## Текущий handoff .15 — 2026-11-18

.14 checks/review завершены, commit bdfc370/push origin/main. .15 review,118 targeted/format5/analyze PASS7 info, final main build8.5s/install/launch PASS,
owner `/root/notice_prep_finish`, exact frontmatter scope; независимый reviewer
`/root/media_review_finish`, .15-01 reviewed/complete. Physical ограничения сохраняются.

## Текущий gate .14 — 2026-11-18

.14 review:102 targeted tests/format5/analyze PASS7 info. Нативная export phase
после исправления F03 path_provider Caches/tmp mismatch: PASS iPhone17Pro и
iPadPro11M5 Simulator/iOS26.5, build9.2s, real sheet/cancel/early-cancel.
Final main build7.8s/install/launch обоих Simulator PASS. .14-01 reviewed/complete, F01–F03 исправлены; physical/provider-write NOT RUN.

## Текущий gate .13 — 2026-11-17

Owner `/root`, status review: host97 PASS после decoder-stream fix, analyze PASS
с семью прежними info, native Simulator capture/timeout PASS5.3s/10.7s;
production main build7.4s/install/launch PASS перед Dart-only fix. Независимый
REVIEW-FE-002.13-01 reviewed/complete, F01/F02 исправлены; physical criteria NOT RUN.
Final integration 2026-11-18: полный `flutter test --no-pub --reporter expanded`
738/738 PASS33s, scoped format26 PASS, local links266/whitespace PASS; final
production main Simulator build8.4s/install/launch PASS после F01.
Host/Simulator review gate пройден. Пользователь разрешил commit/push текущего
результата и продолжение доступных выбранных задач (2026-11-18). Результат сохранён commit33a1fb3/push origin/main. .14 получает sole write
owner `/root/export_prep_finish`, exact card scope, reviewer .14-01
`/root/media_review_finish`; accepted не назначается.

## История выбранного максимума — 2026-11-17

.12-01 independent review **reviewed/complete**,103 tests/format3 PASS,
открытых findings нет. .13 получает solewrite exact expanded cache/player/
native handshake/test-harness scope; reviewer media_review. .12 source frozen.

.12 viewer implemented/frozen/review:103 tests/format3/analyze PASS7info.
Exact50MiB canonical JSON decoded/rendered с ограниченным видимым layout;
10k segments, IDs/labels/UNKNOWN/overlap/fullmicroseconds/clipboard/scale2.
Hostdebug farjump22–27s — известное ограничение; phoneFPS/peakRAM/VoiceOver
NOT RUN. Final .12-01 independent tests/doc delta ожидается; native build
повторится в .13, .11 build не выдаётся за новую .12 проверку.

.11-01 independent review **reviewed/complete**; F01/F02 fixed with evidence,
открытых findings нет. Host checks/review gate пройден, .12 получает sole write
transcript/detail viewer scope. .11 source/tests frozen до следующего handoff.

.11 frozen/review: detail route/реальный canonical/independent summary готовы.
Author88 tests/format7/analyze PASS7info; reviewer88/format7 PASS, F01/F02
исправлены с regression evidence, открытых source findings нет. Root **704
полных host tests PASS**, Simulator main build12.8s/install/launch PASS.
Final .11-01 organizational delta передана; physical/backend E2E NOT RUN.

.09/.10 independent review .09-01 **reviewed/complete**, findings нет.
Host gate пройден; .11 получает sole write exact scope. .09 source/tests
frozen; physical/backend criteria не подменяются этим разрешением.

.09 host scope implemented/frozen: tests122/format5/analyze PASS
(7 прежних info). Включены .10 iOS/desktop library regressions; .10 source
сохранён, coordinator дополнил интеграционную карточку. Independent reviewer
повторил122 tests/format5 PASS, source findings нет; final .09-01 doc delta
передана. Physical/backend E2E NOT RUN; .09/.10 не accepted.

.20 independent implementation review .20-02 **reviewed/complete**,
открытых actionable findings нет; reviewer повторил102 tests/format9 PASS.
.09 получает sole write после этого gate; .20 source/tests frozen.

Первый handoff .20: pause/send/discard реализованы, tests102/format9/analyze
PASS (7 прежних info), production main Simulator build7.3s/install/launch
PASS. Статус review; независимый .20-02 завершает организационную delta.
Physical checks NOT RUN, accepted не назначен.

Пользователь выбрал максимальное доступное число оставшихся задач и до 10
субагентов. Вся очередь .20 → .09 → завершение .10 → .11–.19 выбрана.
Реализация идёт последовательно по общим файлам после host/Simulator checks
и независимого review предыдущего scope; подготовительное исследование
независимых scopes допускается параллельно. Device-only проверки остаются
NOT RUN и не заменяются host evidence; это не запрет выбранной разработки.
.18/.19 не объявляются завершёнными без реального внешнего evidence.

По прямому решению пользователя TASK-FE-002.03 **accepted с исключениями**:
подпись/устройство и physical lock/unlock/reinstall/restore/account-switch/HTTPS
не требуются для её приёмки; прежние NOT RUN и известные Keychain ограничения
сохранены. Это снимает dependency blocker .03, без нового runtime PASS.
Commit/push/release не выбраны. Ниже — исторические записи прошлых поручений.

## Дополнение требований записи — 2026-11-17

По прямому поручению пользователя добавлена
[TASK-FE-002.20](../tasks/TASK-FE-002.20.md): повторный tap основной кнопки ставит
запись на паузу, нажатие кнопки паузы возобновляет её. На паузе доступны зелёная
«Отправить» и крестик с подтверждением удаления. Уход во время записи/паузы
показывает экран «Остаться» / «Отменить запись и выйти»; без подтверждения запись
сохраняется, при подтверждении удаляется только текущая локальная запись.

Новая iOS-политика заменяет прежнее Stop/отправку при уходе из .08 после будущей
реализации .20; старые checks/review .08 остаются evidence прежнего кода.
Очередь: **.08 → .20 → .09 → .10**; зависимости остальных задач сохранены.
.20 draft/unassigned, implementation_selected=false; список выбранных реализаций
не меняется. Это planning-only поручение. ADR-FE-012 в decisions и
[iOS UX](../research/IOS_TARGET_UX.ru.md) синхронизированы.

Verification/Result этого planning diff (cwd frontend; Python3/Ruby Psych/Git):
`python3 /tmp/check_dictai_record_controls_plan.py` и `git diff --check` — PASS,
20 task YAML/IDs, dependency DAG/table/scope/planned paths/links и неизменный
выбор реализаций согласованы. Полный incremental diff и новые документы прочитаны.
Независимый [planning-review .20-01](../reviews/REVIEW-FE-002.20-01.md) выполняет
`/root/record_controls_plan_review`; итоговые findings/completion хранятся в отчёте.
Baseline355: изменены только6 назначенных docs, созданы task20/review20;
остальные349 файлов и HEAD/staging сохранены. Runtime checks NOT RUN:
это добавление требований, нового поведения приложения пока нет.


## Итог интеграции выбранного блока — 2026-11-17

Поручение «посмотри предыдущего агента и продолжи» продолжает только
.04/.05/.06/.07/.08/.10. Их реализация интегрирована; sole writer после handoff —
primary-agent; статус карточек review с явно открытыми physical criteria.
Ни .09, ни .11–.19 не выбраны. Последующий текст хранит историю предыдущих решений.

Полный повтор host tests **658 PASS**, changed/new Dart format **27/27 PASS**,
`flutter analyze --no-fatal-infos` **PASS** (7 прежних info, 0 errors/warnings).
Общий format lib/test — **FAIL** на 10 прежних файлах вне scope, без изменений.
Production main Simulator build **PASS 12.3s**, install/launch/render **PASS**;
обычное приложение восстановлено после native audio targets, прежняя public
HTTPS config и sandbox/Keychain сохранены. Audio capture: два предыдущих native
PASS, первый start FAIL остаётся известным ограничением; permission-denied phase
теперь **PASS** по явному native marker, mic grant затем восстановлен.
Методика/риски — [IOS_AUDIO](../../testing/IOS_AUDIO.ru.md).

Независимые отчёты: [общий batch](../reviews/REVIEW-FE-002.04-02.md)
и [native audio/Files](../reviews/REVIEW-FE-002.06-01.md). Первый самостоятельно
повторил 87 tests, второй 83; актуальный итог review находится в самих отчётах.
Оба review **reviewed/complete**, открытых actionable findings нет; F01 P3
о неточном описании fixture исправлен и подтверждён reviewer.
`python3 /tmp/check_dictai_ios_resume.py` — **PASS**: YAML/status/scope/table,
219 локальных ссылок, whitespace, baseline342/353 и неизменность HEAD/staging.
От resume изменены только 9 документов и 2 новых review reports; остальные
344 файла, включая весь код/tests/dependencies/платформы и .DS_Store, сохранены.
`plutil -lint ios/Runner/Info.plist ios/Runner.xcodeproj/project.pbxproj` — **PASS**.
Авторский intermediate profile-free integration FAIL устранён ожиданием
async WAV copy в fixture и возвратом прежнего desktop toggle в .08; выбор option
и assertions сохранены, общий PASS658.

Все команды/cwd/environment/limits записаны в интеграционных разделах карточек.
Physical iPhone checks **NOT RUN**: подпись/устройство не подготовлены; .03 остаётся
blocked, .06/.07/.08 не verified и suspend/relaunch recovery .09 не реализуется.
Полный iPhone E2E/production readiness не заявлены. Commit/push/release/accepted
не выполнялись. Ниже — исторические результаты, не новые разрешения.


## Параллельное исполнение выбранного блока — 2026-11-16

Новое поручение пользователя выбирает .04/.05/.06/.07/.08/.10 и до 10 агентов.
.04 — login UI поверх готового navbar; .08/.10 — мобильный UI и текущие flows,
без автоматической реализации .09. Exact disjoint scopes/owners закреплены
в active-plan и карточках, shared native/notifier пишет один audio owner.
ADR-FE-011 разрешает параллельную разработку выбранного scope с сохранением
интеграционных и physical проверок; прежние последовательные write gates ниже
описывают историю. .03 остаётся blocked по physical; .09 и .11–.19 не выбраны.
Root интегрирует, проверяет весь diff, строит/устанавливает/запускает Simulator;
затем независимые .04-02/.06-01 review. Status accepted не назначается.

## Текущий выбранный scope — 2026-11-16

Новое поручение пользователя отдельно выбирает responsive shell .04: на
iOS нижний навбар вместо левой панели при любой ширине, доступный logout,
Back вложенных маршрутов и safe areas. Узкие desktop окна также используют
нижнюю панель; широкий desktop сохраняет sidebar.
Owner primary-agent, exact write scope в active-plan. Login layout и внутренние
экраны не включены в этот UI проход. Physical criteria .03 сохраняются для
полной readiness; они не препятствуют прямо выбранному изменению оболочки.
Ни .03, ни полная .04/.05 не объявляются завершёнными. Выбранная оболочка
реализована: 33 targeted tests PASS, simulator build PASS,
analyze --no-fatal-infos PASS (7 прежних info вне scope). Независимый
[REVIEW-FE-002.04-01](../reviews/REVIEW-FE-002.04-01.md) завершён без findings;
reviewer повторил 33 tests, format и doc/preservation checks. Статус .04 review означает передачу частичного UI scope,
не снятие остальных критериев и dependency gate .05. Ниже — предыдущий итог.


Актуальный результат: .01/.02 прошли checks и независимый review. На установленном
iPhone17 Pro Simulator/iOS26.5 собран и запущен Runner с Flutter3.41.3.
.03 реализовала explicit Keychain policy и retained-key logout fix; targeted60,
full561 tests, analyze (9 прежних info) и9native Keychain/HTTPS/auth phases PASS.
Тестовый аккаунт создан по разрешению пользователя. Full independent .03-02
завершён: F01 P3 исправлен, открытых findings нет. .03 status blocked на обязательных physical checks без подписи;
.04/.05 не открываются. Реализатор .03 после handoff — primary-agent.
Ниже сохранена история предыдущих проходов, где runtime ещё отсутствовал.

Последующее решение пользователя разрешило отдельный Flutter3.41.3. .02
проверена primary-agent в своём exact scope: enforced pub PASS, 552 tests PASS,
analyze PASS (9info), pubspec/lock сохранены. Actual CocoaPods создал native lock
и штатную project/workspace integration. Flutter build FAIL из-за отсутствующего
Simulator destination/runtime, поэтому .02 остаётся blocked. Независимый повторный
review REVIEW-FE-002.02-02 завершён без открытых findings. .03–.05 gates и
физическая подпись не отменены.
Последующий текст содержит предыдущий snapshot Flutter3.44, отдельно от текущего.


Последующее поручение: пять агентов для пяти ближайших iOS-задач по принятому
flow. Выбраны .01–.05; .06–.19 не выбраны. Владельцы и последовательная передача
exact scopes зафиксированы в active-plan. Следующий этап допускается только
после обязательных checks и независимого review зависимости. Недоступные
внешние проверки фиксируются как blockers, без автоматического обхода gates.
Публикация и accepted этим поручением не разрешены. Ниже сохранён planning
baseline; прежние формулировки «реализация не выбрана» описывают тот этап.

Текущее исполнение: .01 прошла checks и независимый review .01-02; .02 имеет
Runner scaffold, но blocked из-за несовместимого SDK/lock и отсутствующего
Simulator runtime; .03–.05 blocked по обязательным зависимостям и device signing.
Пять исполнителей завершили preflight; пять функциональных этапов не объявлены
выполненными. Candidate с тремя изменёнными SDK-pinned dependencies проверен только
в изолированной копии: resolution PASS, analyze PASS (9 info), tests FAIL
(550/552), simulator build FAIL (нет destination/runtime). Исходный lock сохранён.
Подробные команды/границы — в active-plan и IOS_BASELINE, все изменения SDK/lock
и выход за exact scope ожидают отдельного решения, accepted не назначен.

## Goal

Работающее приложение для iPhone: вход → рабочее пространство либо запись без
workspace → микрофон или WAV из Files → V2 upload → готовый транскрипт →
прослушивание и экспорт → безопасные удаление/выход. Flutter/Riverpod/GoRouter/Dio
и существующие API сохраняются; Swift используется для узких iOS-возможностей.
Целевой сценарий включает запись с заблокированным экраном и обработку audio
interruptions, восстановление загрузки после suspend и использование iOS Files.

Поручение пользователя 2026-11-16: переписать/добавить задачи под iOS. Сейчас
разрешены только планирование и изменение flow. Реализация карточек не выбрана;
планирование не разрешает её автоматически. Review выполняется агентами внутри
процесса; пользователь видит конечный результат и существенные ограничения.

## Current state

Проверенный checkout `44ace4d`, исходный git status чистый. `ios/` отсутствует,
`.metadata` перечисляет root/macOS, есть macOS/Linux исходники. В pubspec Flutter
>=3.41.3 / Dart >=3.11.0, record ^5.1.2 (lock: 5.2.1, record_darwin 1.2.2), audioplayers, file_picker, path_provider,
flutter_secure_storage; совместимость конкретного iOS target ещё не доказана.

- MainShell: Row/sidebar 220; RecordScreen: фиксированные 360; UploadModal: 480.
- RecordNotifier capture factory выбирает macOS/Linux; MicrophoneCapture отказывает
  вне macOS. Наличие record plugin не делает текущую запись совместимой с iOS.
- Готовы компоненты auth, secure storage без plaintext fallback, workspace/contact,
  V2 upload/options/WAV preflight, durable upload/job journals, polling, canonical/
  documents/results API, library. Detail route/viewer/player ещё не завершены.
- Backend/API snapshots в docs/ai/research — исторические источники с внешними
  путями; актуальный backend/стенд/качество не подтверждены этим планированием.
  Контракт и реальную интеграцию проверяем read-only, backend не изменяем.

Это source-аудит, не runtime test. Ранее записанные 552 Flutter tests и macOS
smoke относятся к прежнему diff: iOS build, запись, Files и Keychain NOT RUN.
Подробности: [architecture](../architecture.md), [iOS UX](../research/IOS_TARGET_UX.ru.md),
[ADR-FE-009/010](../decisions.md), [WORKFLOW](../WORKFLOW.md).

## Task graph

Первый порт выполняется по одной задаче за раз, чтобы shared router/providers,
Runner/Info.plist, capture/notifier и result detail имели одного writer. Поэтому
очередь .01 → … → .08 → .20 → .09 → … → .19 содержит функциональные
и интеграционные зависимости. Позднее добавленная .20 сохраняет свой ID.
Граф не означает выбор реализации. Переход внутри выбранной очереди требует
checks и внутреннего независимого review без блокирующих findings; accepted
остаётся явной приёмкой пользователя, без промежуточных запросов review.

```text
.01 baseline → .02 Runner → .03 Keychain/HTTPS → .04 navigation → .05 workspaces
→ .06 iOS audio → .07 Files import → .08 Record → .20 pause/send/discard
→ .09 lifecycle/upload recovery
→ .10 Results → .11 detail → .12 transcript → .13 player → .14 export
→ .15 ready notice → .16 cleanup → .17 regression → .18 iPhone E2E → .19 candidate
```

## Tasks

Owner unassigned относится к будущей реализации; planner/coordinator всех
документов — primary-agent. До старта выбранной задачи назначается один writer.

| ID | Title | Status | Dependencies | Owner | Write scope |
|---|---|---|---|---|---|
| [TASK-FE-002.01](../tasks/TASK-FE-002.01.md) | Зафиксировать iOS toolchain, deployment target и manifest Runner | review | none | /root/ios_baseline | Exact paths в карточке |
| [TASK-FE-002.02](../tasks/TASK-FE-002.02.md) | Добавить iOS Runner и воспроизводимую simulator-сборку | review | TASK-FE-002.01 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.03](../tasks/TASK-FE-002.03.md) | Подтвердить iOS Keychain, авторизацию и HTTPS | accepted | TASK-FE-002.02 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.04](../tasks/TASK-FE-002.04.md) | Сделать мобильную навигацию и экран входа | review | TASK-FE-002.03 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.05](../tasks/TASK-FE-002.05.md) | Адаптировать workspaces и контакты для iPhone | review | TASK-FE-002.04 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.06](../tasks/TASK-FE-002.06.md) | Добавить iOS микрофон, background recording и audio interruptions | review | TASK-FE-002.05 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.07](../tasks/TASK-FE-002.07.md) | Импортировать WAV из Files в sandbox приложения | review | TASK-FE-002.06 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.08](../tasks/TASK-FE-002.08.md) | Собрать мобильный экран записи и безопасный Stop/уход | review | TASK-FE-002.07 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.20](../tasks/TASK-FE-002.20.md) | Изменить управление записью: пауза, отправка и подтверждённая отмена | review | TASK-FE-002.08 | /root/record_controls | Exact paths в карточке |
| [TASK-FE-002.09](../tasks/TASK-FE-002.09.md) | Адаптировать upload и восстановление к iOS suspend/resume | review | TASK-FE-002.20 | /root/recovery_prep | Exact paths в карточке |
| [TASK-FE-002.10](../tasks/TASK-FE-002.10.md) | Адаптировать библиотеку результатов и восстановление отправок | review | TASK-FE-002.09 | primary-agent | Exact paths в карточке |
| [TASK-FE-002.11](../tasks/TASK-FE-002.11.md) | Добавить единый мобильный экран результата | review | TASK-FE-002.10 | /root/detail_prep | Exact paths в карточке |
| [TASK-FE-002.12](../tasks/TASK-FE-002.12.md) | Показать большой транскрипт с говорящими и таймкодами | review | TASK-FE-002.11 | /root/detail_prep | Exact paths в карточке |
| [TASK-FE-002.13](../tasks/TASK-FE-002.13.md) | Добавить iOS аудиоплеер и принадлежащий аккаунту cache | review | TASK-FE-002.12 | /root | Exact paths в карточке |
| [TASK-FE-002.14](../tasks/TASK-FE-002.14.md) | Экспортировать документы и WAV через iOS Files/share sheet | review | TASK-FE-002.13 | /root/export_prep_finish | Exact paths в карточке |
| [TASK-FE-002.15](../tasks/TASK-FE-002.15.md) | Связать готовность результата с lifecycle и уведомлением внутри приложения | review | TASK-FE-002.14 | /root/notice_prep_finish | Exact paths в карточке |
| [TASK-FE-002.16](../tasks/TASK-FE-002.16.md) | Завершить удаление, account isolation и cleanup iOS flow | review | TASK-FE-002.15 | /root/cleanup_prep_finish | Exact paths в карточке |
| [TASK-FE-002.17](../tasks/TASK-FE-002.17.md) | Закрепить iOS batch-сценарий регрессионными проверками | review | TASK-FE-002.16 | /root | Exact paths в карточке |
| [TASK-FE-002.18](../tasks/TASK-FE-002.18.md) | Подтвердить реальный iPhone E2E и platform readiness | blocked | TASK-FE-002.17 | /root | Exact paths в карточке |
| [TASK-FE-002.19](../tasks/TASK-FE-002.19.md) | Подготовить iOS candidate и требования TestFlight/App Store | blocked | TASK-FE-002.18 | /root | Exact paths в карточке |

## Перенос PLAN-FE-001

Старые ID, статусы, evidence и готовый код сохранены. Все 51 карточка помечены
historical_not_selected и ссылаются на этот план; selected_tasks старого плана
очищен, сам план blocked для исполнения. Перенос не означает отмену/приёмку
старого результата или разрешение повторно реализовать уже готовые компоненты.

| Прежние задачи | Решение для iOS |
|---|---|
| .01–.10 | Reuse toolchain/auth/network/storage/contracts; iOS перепроверка .01–.04 |
| .11–.14 | Reuse profile-free workspace/contact CRUD; мобильная адаптация .05 |
| .15/.16 | Reuse AudioCapture/lifecycle опыт; новый iOS adapter .06, desktop код сохраняется |
| .17/.37 | Linux capture/build отложены, не входят в iOS gate |
| .18–.25 | Reuse WAV/upload/DTO/journals/polling, iOS Files/Record/lifecycle в .06–.09 |
| .26/.27 | Reuse Results data/list; iPhone library .10 |
| .28/.29/.44 | Незавершённые detail/transcript/player перенесены в .11–.13 |
| .30/.31 | Reuse DocumentsApi, iOS export .14 |
| .32–.35 | Delete/legacy cleanup/account isolation/regression перенесены в .16/.17 |
| .36/.38–.42 | macOS/Linux release gate заменён iOS baseline/device/backend/candidate .01/.18/.19 |
| .48/.49 | Reuse Stop/guard; iOS gestures/lifecycle/ready notice .08/.15 |
| .43/.45/.46/.47/.50/.51 | Будущие speaker names/contact assignment/named export по-прежнему ждут backend и отдельного выбора |

Это перенос существующей frontend интеграции на iOS, не разрешение создавать
новые backend endpoints/tasks. Immutable BACKEND_* snapshots не редактируются.

## Verification strategy

Для текущего planning diff: frontmatter/ID, dependency DAG/status table,
exact paths/planned_paths, ссылки, сохранность исходников/старых task статусов,
полный tracked/untracked diff и внутренний независимый planning-review.
Flutter/analyze/build/audio/backend E2E сейчас NOT RUN: функциональный код не меняется.

При реализации: format/analyze/targeted tests для каждого Dart scope, затем
общий regression; simulator build для Runner; физический iPhone для Keychain,
микрофона, background/lock/interruption/route changes, Files/export, suspend и
account isolation. Реальный HTTPS backend нужен для .18, модельное качество и
workspace security не выводятся из успешного UI/fixtures. Archive/signing/Store
validation проверяются отдельно, без автоматической публикации.

## Risks and decisions

- iPhone — основной target. Минимальная iOS версия выбирается в .01 по pinned
  dependencies. iPad — адаптивная работоспособность и безопасный share popover,
  отдельный iPad UX не обязателен первому этапу. Android не входит в эту очередь.
- iOS mic + WAV Files import; захват звука звонков/других приложений, ScreenCaptureKit,
  ReplayKit/broadcast extension не входят. Запись на фоне проверяется на iPhone.
- AVAudioSession/permission, file protection и lock/interruptions — реальные gates.
  Продолжение записи при force quit и бессрочная фоновая загрузка не обещаются.
- Upload восстанавливается по journal/key при возвращении приложения; не вводим
  background URLSession/push/APNs без отдельного решения. Ready notice — in-app.
- Public HTTPS endpoint, физический iPhone, signing/team и backend/operator могут
  быть недоступны: записать blocker и продолжать только независимый выбранный scope.
- App Store account deletion/privacy policy/review access проверяются в .19.
  Неподдержанное удаление аккаунта — release blocker, не повод придумывать endpoint.
- Нет MP3/M4A transcoding, speaker renaming/editor/live/chat или production fake data.
  Новые packages, permissions и signing changes разрешаются только в выбранном
  exact scope с обоснованием; текущий planning diff их не вносит.

## Completion

Приложение готово после выполнения выбранных .01–.19 и новой .20 с реальными gates и
внутренним независимым review; приёмка остаётся за пользователем. Готовый план
не означает готовое приложение и не разрешает commit/push/release. Текущее поручение меняет документы; переход к реализации требует
выбора новых задач пользователем.

## Verification / Result текущего перепланирования

2026-11-16: подготовлены 19 новых карточек, активный iOS-план, UX, перенос 51
исторической карточки и правила внутреннего review в AGENTS/WORKFLOW/README.
Implementation, platform config, зависимости и исторические reviews не меняются.
Doc checks и [независимый review](../reviews/REVIEW-FE-002.01-01.md) завершены.
Reviewer `/root/ios_planning_review` подтвердил исправление F01–F03 P2/F04 P3;
открытых actionable findings нет. Status ready — подготовленный план к выбору,
не реализованность новых задач и не accepted.

Проверки документации выполнены из `/Users/mxdnght/dictai-app`, локальное
окружение Python 3 / Ruby Psych 3.1.0. Checker и baseline расположены в `/tmp`,
не входят в продуктовый diff.

| Command / scenario | Cwd / environment | Actual | Status | Limitation |
|---|---|---|---|---|
| `python3 /tmp/check_dictai_ios_plan.py` | frontend / Python 3, Ruby Psych 3.1.0 | 19 новых задач; YAML, ID/table, DAG, exact/planned paths, новые ссылки и ordered shared scopes проверены; 51 прежний task status и всё историческое содержимое сохранены; 197 protected file hashes без изменений | PASS | Локальный doc checker; не тест приложения |
| `git diff --check` | frontend / Git | Whitespace ошибок нет | PASS | Новые файлы дополнительно проверены checker/no-index diff |
| Полный tracked diff и `git diff --no-index /dev/null <new-doc>` | frontend / Git | Проверены doc-only изменения и новые документы; код/dependencies/platforms/старые reviews/BACKEND_* сохранены | PASS | no-index exit 1 означает найденный diff |
| Flutter analyze/test/build; device/backend smoke | Не выполнялось | Изменены только документы | NOT RUN | Не относится к scope; готовность iOS не утверждается |
| Независимый planning-review и delta | Агент ios_planning_review, только назначенный report | REVIEW-FE-002.01-01 reviewed; F01–F04 fixed with evidence, открытых findings нет | PASS | Только planning diff, отдельно от runtime checks |
