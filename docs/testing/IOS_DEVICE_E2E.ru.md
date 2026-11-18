# Проверка DictAI на физическом iPhone

Подготовительный opt-in harness TASK-FE-002.18. На 2026-11-18 hardware/backend
сценарии ниже **NOT RUN**. Документ и host/Simulator tests не доказывают E2E.
Запуск возможен после host gate .17 и выполнения
[backend prerequisites](IOS_BACKEND_GATE.ru.md). Синтетические unit/widget
сценарии отдельно описаны в [регрессии](IOS_REGRESSION.ru.md).

## Текущее окружение и blockers

Read-only inventory из frontend `/Users/mxdnght/dictai-app`, 2026-11-18:

| Проверка | Actual | Status | Граница |
|---|---|---|---|
| `xcodebuild -version` | Xcode26.5, build17F42 | PASS | Инвентаризация, не сборка |
| `xcrun --sdk iphoneos --show-sdk-version` | 26.5 | PASS | Наличие SDK |
| `sw_vers` | macOS26.5.2/build25F84 | PASS | Host |
| `security find-identity -v -p codesigning` | 0 valid identities | PASS для inventory | Подписанный device run blocked |
| `xcrun devicectl list devices --json-output <private-temp-json>` | Paired iPhone13mini/iOS18.5; developer mode enabled; DDI services unavailable; tunnel disconnected | PASS для inventory | Устройство недоступно для текущего запуска |
| Source project signing | DEVELOPMENT_TEAM отсутствует | PASS для inventory | Team/profile не назначены |
| Production main Simulator build/install/launch, проверенный source .16 `8da7b55` | Build7.2s/install/launch PASS | PASS | Simulator не hardware E2E |
| `flutter build ios --debug --no-codesign --no-pub --target lib/main.dart` с прежним разрешённым HTTPS config | Unsigned device compile26.0s PASS; `/tmp/dictai-finish-20261118-unsigned-device-build.log` | PASS | Строгая device branch компилируется; подпись/установка не выполнены |
| Подписанный install/launch, аппаратные сценарии | Не выполнялись | NOT RUN | Нет готовой signing/device среды |

Имена владельца устройства, UDID и полные inventory JSON в Git не сохранять.
Наличие paired записи не означает, что iPhone сейчас доступен. Подпись, trust,
provisioning/certificates и изменения устройства выполняет назначенный владелец
после подготовки доступа; этот harness их автоматически не выполняет.

## Перед прогоном

1. Зафиксировать frontend SHA и чистоту релевантного diff, SDK/revisions,
   `pubspec.lock`/Podfile.lock hashes, физическую модель/iOS, bundle/version/build,
   team владельца и способ установки. Использовать проверенный Flutter3.41.3 и
   подготовленные locked dependencies; не менять SDK/packages ради запуска.
2. Подготовить подписанную сборку с разрешённым HTTPS `API_BASE_URL` без path,
   credentials/query. Debug Simulator сборка не заменяет device install.
   Установка CA на iPhone требует отдельного осознанного действия владельца;
   TLS verification/ATS не отключать. Для private test CA заранее
   согласовать поддержанный способ доверия; её private key в приложение не передавать.
3. Оператор подтверждает backend SHA/runtime readiness, два разрешённых тестовых
   аккаунта A/B и workspace A, политику очистки тестовых данных. Не использовать
   production credentials/записи; реальные голоса записывать с согласия участников.
4. Подготовить в Files короткие PCM WAV (mono16kHz, RU/EN/mixed), invalid WAV,
   переименованный MP3, доступный внешний original и export destination.
   Записать duration/bytes/hash и сценарий без личного transcript в Git.
5. В каждом сценарии фиксировать UTC timestamp, build, backend SHA, expected,
   actual, PASS/FAIL/NOT RUN, безопасный evidence path и ограничения. Определить
   deadline ожидания результата по операторскому envelope до начала, а не после.

## Ручной прогон

Каждый пункт — отдельный наблюдаемый результат. После отказа не объявлять
последующие зависимые пункты PASS; записывать NOT RUN и причину.

| ID | Действия | Expected / evidence |
|---|---|---|
| D01 TLS/login | Запустить cold process; войти A; перезапустить приложение | Доверенный HTTPS, защищённые API доступны; session восстановлена через native Keychain; без токенов в logs |
| D02 permission | На свежем permission state отказать микрофону, повторить через Settings; записать короткий WAV | Понятный отказ без загрузки; затем Start/Pause/Resume/Send, WAV валиден; существующий доступ не сбрасывать глобально |
| D03 lifecycle | Во время записи lock/unlock и background/foreground, затем interruption и смена audio route | Фактическое поведение audio session задокументировано; нет ложного индикатора записи, повторной отправки и потери owned cleanup; force quit отдельно |
| D04 cancel/navigation | Уйти во время recording/paused; выбрать «Остаться», затем подтвердить отмену другой записи | При Stay запись остаётся; при discard удалена только текущая private запись, upload не создан |
| D05 Files | Импортировать валидный WAV из внешнего provider; отменить picker; выбрать invalid/MP3; повторить одинаковое имя | Частная стабильная копия, validation до POST, без преобразования MP3/M4A; внешний source сохранён |
| D06 upload/recovery | Отправить owner-only и workspace WAV; оборвать сеть при неизвестном исходе; relaunch/retry | 202 и реальные IDs/job version сохранены; повтор использует прежние bytes/options/key; нет двойного job; 400/409/429/503 различаются |
| D07 canonical | Дождаться transcript ready и открыть detail; отдельно summary failed/pending и no_speech | Текст/микросекунды/speakers из canonical; UNKNOWN без выдуманного имени; summary независим; notice один на актуальный job |
| D08 player | Download/play/pause/seek; перейти к записи; удалить во время download/playback | AVAudioSession ownership корректна, playback прекращён, decoder/cache/request освобождены; late response не восстанавливает удалённое |
| D09 export | TXT/PDF/WAV share, cancel и Files save; проверить iPad popover при доступном iPad | Фактическая запись provider подтверждена открытием/bytes/hash; внешний export сохраняется при последующем logout/delete; Cancel не считается save |
| D10 isolation | Оставить active upload/poll/player, logout A→login B; затем 401 A и relaunch B | Capture/listeners/timers/requests закрыты; B не видит A labels/files/jobs/notices; чужие resources сервер отклоняет |
| D11 file policy | Read-back backup exclusion/protection; до/после первого unlock и повторного lock, pending recovery/quota | Native attributes и реальный доступ измерены отдельно; выбранная after-first-unlock policy не выдаётся за недоступность при каждом lock |
| D12 final cleanup | Удалить тестовый result; повторить read/status/original, проверить list после refresh/restart | Реальный backend delete policy подтверждён; UI tombstone/404 очищают detail/player/cache; внешние Files original/export сохранены |

Отдельно снять VoiceOver, крупный текст, duration, app peak RSS и длительность
целевого long-recording сценария на физическом iPhone. Simulator memory и host
widget latency не подменяют эти метрики. Без согласованного long fixture и
целевого envelope этот пункт NOT RUN, краткий smoke не доказывает предел2h.

## Evidence запись

```text
run_id / UTC / operator:
frontend SHA / backend SHA / configuration version:
iPhone model / iOS / Xcode / SDK:
Flutter revision / Dart / lock hashes:
bundle / version / build / signing owner:
scenario ID / fixture duration+bytes+hash:
expected / actual / PASS|FAIL|NOT RUN / reason:
elapsed / peak RSS / safe artifact paths:
cleanup result / remaining account-data / limitations:
```

Пароли/JWT, приватные ключи, personal audio/transcript, device IDs и полный
network body остаются вне Git. Redacted evidence не должно скрывать фактический
FAIL. Прогон завершается отдельным независимым review; приёмка не автоматическая.
