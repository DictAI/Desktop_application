---
title: "DictAI iOS/iPhone: целевой первый этап"
date: "2026-11-16"
status: "planned"
related_plan: "PLAN-FE-002"
implementation_authorized: false
---

# DictAI для iPhone

Это целевое поведение, не отчёт о работающей iOS-версии. Решение пользователя —
переориентировать план на iOS; реализация ещё не выбрана. Исторический desktop UX
сохранён в [FRONTEND_TARGET_UX](FRONTEND_TARGET_UX.ru.md); при расхождении iOS scope
определяется этим документом и [PLAN-FE-002](../plans/PLAN-FE-002.md).

## Основной сценарий

1. Войти/зарегистрироваться по существующим auth API. JWT хранится в Keychain;
   401/logout очищают сессию. Все запросы — через общий Dio/HTTPS gateway.
2. В мобильной навигации доступны запись, результаты, workspaces. Forms доступны
   с клавиатурой, safe areas, увеличенным текстом/VoiceOver; уход учитывает запись.
3. Выбрать workspace или режим без него, язык/mixed. Контакты — текущий отдельный
   CRUD name/email; они не нужны для записи и не назначают имена Speaker.
4. Начать микрофонную WAV-запись либо импортировать допустимый WAV из Files/iCloud.
   Внешний документ копируется в sandbox; MP3/M4A не переименовываются в WAV.
5. Во время записи работают Pause/Resume и явный Stop. Уход через вкладку/Back/swipe
   запрашивает продолжение либо завершение с отправкой; cancel не останавливает.
   Сворачивание/lock сохраняет активную mic-запись при разрешённом background audio.
   Incoming call/Siri/route change показывают фактическое состояние и безопасное
   восстановление. Force quit не обещает корректный финализированный WAV.
6. Отправить finalized WAV через текущий V2 multipart. Journal сохраняет owned
   bytes/options/Idempotency-Key; network loss/suspend/relaunch допускают безопасный
   retry. После 202 восстанавливается job, не делается новый upload. iOS может
   приостановить сеть; доставка восстанавливается при возвращении приложения.
7. Показать canonical transcript с исходными Speaker labels, таймкодами,
   UNKNOWN/overlap/no_speech. Summary и документы готовы независимо. В ожидающем
   экране открыть transcript, в другом разделе показать in-app notice. При закрытом
   приложении push не обещается, Results обновляется после возвращения.
8. Прослушать original WAV с Play/Pause/seek. Playback уступает capture и прекращается
   в background; текущая mic-запись в background имеет отдельную audio policy.
   Экспортировать доступные TXT/PDF/WAV через system share/Save to Files. Bytes не
   изменяются; файлы/credentials не публикуются через открытые URLs.
9. Удаление результата и logout освобождают owned cache/polls/player/recorder,
   изолируют аккаунты. Пользовательские оригиналы/exports в Files сохраняются.

## Границы первого этапа

Основной target — iPhone; iPad сохраняет адаптивную работоспособность и корректный
share popover. Минимальная iOS версия определяется по toolchain/plugins в .01.
Нужны physical iPhone и доступный разрешённый HTTPS backend для реального E2E;
Simulator/fakes не заменяют аппаратные и серверные проверки.

Нет system audio/call recording, ReplayKit extension, MP3/M4A transcoding,
переименования Speaker, новых contact-assignment API, live/chat, APNs и фонового
network framework. Desktop источники сохраняются как база, их отдельное развитие
не входит в iOS очередь. Публичная публикация требует отдельного поручения,
privacy/review access/account deletion gate описаны в .19.
