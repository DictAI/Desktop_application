# DictAI Flutter Frontend: текущая архитектура

Снимок исходников на 2026-10-24. Это описание существующего кода, не проект
будущей интеграции. Поведение запущенного приложения и доступность API здесь
не объявляются проверенными. Пути текущего приложения относятся к корню frontend;
исходные ссылки внутри backend-снимков имеют отдельный контекст, описанный ниже.

## Запуск, навигация и структура

| Путь | Существующая ответственность |
|---|---|
| `lib/main.dart` | Flutter binding, ProviderScope, запуск App |
| `lib/app.dart` | MaterialApp.router, тёмная Material 3 тема и routerProvider |
| `lib/core/router/app_router.dart` | GoRouter: /login, /record, /workspaces, /workspaces/:workspaceId, /results; ShellRoute |
| `lib/core/router/auth_listenable.dart` | Обновление router при изменении auth/session |
| `lib/core/shell/main_shell.dart` | Общая оболочка и sidebar |
| `lib/core/theme/` | AppColors и AppTheme |
| `lib/core/network/` | Dio factory и AuthInterceptor |
| `lib/core/storage/secure_storage.dart` | JWT, email и ключ внешнего сервиса через SharedPreferences |
| `lib/core/error/app_exception.dart` | Типы AppException и оставшийся StubException |
| `lib/shared/providers/providers.dart` | Общие storage/session/Dio и feature API providers |
| `lib/features/` | Функциональные области, обычно presentation и data/dto |

Обычный поток: Widget → StateNotifier → feature API → Dio → backend.
Состояния и providers написаны вручную. Отдельного domain/repository/use-case
слоя нет; DTO используются непосредственно в presentation. Notifier-классы
также управляют файлами, таймерами, recorder и внешними процессами.

## Функциональные области

| Каталог | Что есть в коде |
|---|---|
| `lib/features/auth/` | Login/Register, AuthNotifier, AuthApi, request/response DTO |
| `lib/features/workspace/` | Список и детали workspace, участники, UI голосовых профилей |
| `lib/features/voice_profile/data/` | VoiceProfileApi и DTO; отдельного presentation-каталога нет |
| `lib/features/record/` | Обычная/анонимная запись, upload, разметка speakers и воспроизведение фрагментов |
| `lib/features/results/` | Список результатов, статусы, удаление, скачивание summary/transcript PDF и аудио |

В `lib/features/record/presentation/chat_panel.dart` есть ChatPanel, а в
`lib/features/record/data/anthropic_service.dart` — прямой клиент Anthropic.
ChatPanel сейчас не подключён к экранам. Его нельзя считать доступным маршрутом
приложения или источником контекста встреч. Анонимная запись также защищена
общим auth redirect: её название не означает вход без JWT.

## API и данные

Общий backend-клиент создаётся через dioProvider и
`lib/core/network/api_client.dart`. Connect timeout — 10 секунд, receive — 30.
AuthInterceptor добавляет Bearer JWT кроме /auth/login и /auth/register.
При 401 токен удаляется и session notifier инициирует обновление навигации.
AuthApi содержит refresh, но автоматический refresh flow не подключён.

| Клиент | Путь и семейство запросов |
|---|---|
| AuthApi | `lib/features/auth/data/auth_api.dart`; /auth/* |
| WorkspaceApi | `lib/features/workspace/data/workspace_api.dart`; /workspaces/* и participants |
| AudioIngestApi | `lib/features/record/data/audio_ingest_api.dart`; /ingest/audio/upload |
| AnonymousSessionApi | `lib/features/record/data/anonymous_session_api.dart`; anonymous upload/session/fragment/confirm |
| ResultsApi | `lib/features/results/data/results_api.dart`; /meetings/results/* |
| VoiceProfileApi | `lib/features/voice_profile/data/voice_profile_api.dart`; /voice-profiles/* |

JSON маппится ручными fromJson/toJson в DTO-каталогах, например
`lib/features/auth/data/dto` и `lib/features/record/data/dto`; часть ответов имеет
Map<String, dynamic>. Аудио отправляется multipart, документы/фрагменты — bytes.
API-классы преобразуют DioException в AppException. Анонимная сессия опрашивается
раз в 3 секунды, pending results — раз в 5 секунд. Реального streaming-канала
для результатов в текущем frontend нет.

Локального OpenAPI или каталога contracts во frontend нет. В текущем workspace
есть внешний backend-репозиторий: `/Users/verliiar/phiziks_pr`; его HTTP-описание
лежит в `/Users/verliiar/phiziks_pr/contracts/api/openai.yml`.
Это внешние источники, доступность которых на другом компьютере не гарантируется.
Перед конкретной API-задачей проверяй соответствующую актуальную спецификацию
и реализацию read-only. Расхождения OpenAPI с реализацией перечислены в локальном
API-снимке ниже; OpenAPI не следует считать единственным источником DTO.
Совместимость текущего frontend с целевым backend пока не сравнивалась;
backend endpoint/flow не переносится в клиент автоматически.

## Backend: снимки для планирования

Во frontend доступны две неизменённые копии исследований backend от 2026-10-24,
основанные на commit `f639db8d7d2b0d1833ad0fb7dab99cca231e8ea6`:

| Локальный документ | Назначение | Исходное имя в backend docs/ai/research |
|---|---|---|
| [BACKEND_API_CONTRACTS.ru.md](research/BACKEND_API_CONTRACTS.ru.md) | Фактические 25 HTTP-операций, DTO/JSON, авторизация, асинхронные статусы, ограничения и отсутствующие API | `FRONTEND_API_CONTRACTS.ru.md` |
| [BACKEND_TARGET_SCOPE.ru.md](research/BACKEND_TARGET_SCOPE.ru.md) | Согласованный batch-сценарий, backend task ID/зависимости, незавершённые этапы, исключения и разделение frontend-работ по готовности | `FRONTEND_TARGET_SCOPE.ru.md` |

Backend развивается. При следующем планировании читай оба документа: наличие
реализации, качество моделей и production readiness — разные состояния.
Target scope включает согласованные будущие направления, но не делает открытые
вопросы обязательными требованиями. Live остаётся design-only TASK-002.21,
публичного cancel API и полного grant discovery пока нет; профили/confirm
исключены новой моделью. Снимки не изменяют текущую архитектуру Flutter-приложения.

Правила чтения и разрешения ссылок:

1. Копии сохранены побайтово, поэтому заголовки, frontmatter `api_contracts`,
   имена `FRONTEND_*.ru.md`, backend-пути и исторические Verification не переписаны.
   Взаимную ссылку `FRONTEND_API_CONTRACTS.ru.md` следует читать как локальный
   [BACKEND_API_CONTRACTS.ru.md](research/BACKEND_API_CONTRACTS.ru.md);
   для `FRONTEND_TARGET_SCOPE.ru.md` локальное соответствие —
   [BACKEND_TARGET_SCOPE.ru.md](research/BACKEND_TARGET_SCOPE.ru.md).
2. Все остальные относительные Markdown-ссылки внутри копий разрешаются от
   **исходного** каталога `/Users/verliiar/phiziks_pr/docs/ai/research/`.
   Например, `../../../services/...` относится к backend services, а
   `../tasks/TASK-002.17.md` — к backend task-карточке. Backend-файлы во frontend
   не копировались. На другом компьютере используется фактический backend checkout.
3. Даже если `../../../AGENTS.md`, `../active-plan.md`, `../architecture.md`,
   `../decisions.md` или `../tasks` случайно разрешаются во frontend, это ссылки
   на исходные backend-документы. Их нельзя подменять одноимёнными frontend-файлами.
   Непосредственный переход по таким ссылкам из копий не гарантируется.
4. Для работы агента действуют frontend [AGENTS.md](../../AGENTS.md) и
   [WORKFLOW.md](WORKFLOW.md). Backend task ID и команды/evidence в копиях —
   контекст исследования, а не новые frontend-задачи или разрешение их выполнять.
5. Для автономного предварительного плана существенные DTO, сценарии, статусы,
   зависимости и открытые вопросы изложены в самих копиях; backend не нужен
   для их чтения. Проверка source evidence и актуализация после этого SHA требуют
   backend checkout. Без него неизвестные контракты остаются открытыми.

Следующий этап — сравнение frontend с целевым backend и создание плана задач
по отдельному поручению; сейчас план/задачи не создаются. Происхождение копий,
SHA-256 и результаты переноса находятся в [active-plan.md](active-plan.md).

## Конфигурация и инструменты

- `pubspec.yaml` и `pubspec.lock` описывают зависимости; `analysis_options.yaml`
  включает flutter_lints. Riverpod, GoRouter и Dio — основные runtime библиотеки.
- `record`, `audioplayers`, `file_picker`, `path_provider` и `url_launcher`
  используются для аудио, файлов и внешних ссылок.
- build_runner, riverpod_generator и riverpod_annotation объявлены, но
  аннотаций и генерируемых Riverpod part-файлов в lib сейчас нет.
- Backend URL жёстко задан в providers.dart через HTTP. `.vscode/launch.json`
  передаёт dart-define для API и внешнего сервиса, но приложение их не читает.
  Не копируй содержимое конфигурации запуска или значения ключей в отчёты.
- AnthropicService создаёт собственный Dio, использует фиксированную модель
  и ключ из SharedPreferences. Это отдельный клиент от backend Dio.

## Платформы

В репозитории есть macOS и Linux; каталогов Windows, web, Android и iOS нет.
Отдельные Platform.isWindows-проверки не означают готовую Windows-сборку.

macOS: `macos/Runner/AppDelegate.swift` регистрирует MethodChannel
`com.dictai/system_audio`, `macos/Runner/SystemAudioRecorder.swift` реализует
ScreenCaptureKit/AVFoundation для macOS 13+. Dart-обёртка —
`lib/features/record/data/system_audio_service.dart`. Обычная совместная запись
смешивает system+microphone. AnonymousRecordNotifier не использует эту macOS
обёртку; поддержку системного аудио нельзя переносить между сценариями по предположению.
Нативные разрешения описаны в `macos/Runner/Info.plist`,
`macos/Runner/DebugProfile.entitlements` и `macos/Runner/Release.entitlements`.
Сборка использует Xcode/CocoaPods, `macos/Podfile` задаёт macOS 13.0.

Linux: `linux/CMakeLists.txt` и `linux/runner/` задают CMake/GTK оболочку.
Для системного аудио Dart-код вызывает pactl/parec, для смешивания — ffmpeg.
Установка этих программ и фактическая готовность звуковой среды не гарантируются
наличием исходников. Plugin registrants под macos/Flutter и linux/flutter
генерируемые; не следует редактировать их вручную.

## Подтверждённые ограничения исходного состояния

Это наблюдения, не созданные задачи и не разрешение исправлений:

- `test/widget_test.dart` пустой, `macos/RunnerTests/RunnerTests.swift` содержит
  шаблон без содержательной проверки. Тестовое покрытие не установлено.
- В pubspec заявлены Dart >=3.3 и Flutter >=3.19, но текущий lock требует
  Dart >=3.11 и Flutter >=3.35.6. Локально при подготовке документации установлен
  Dart 3.10.0/Flutter 3.38.1. Это несовпадение нужно решить отдельным поручением,
  а не автоматически обновлять SDK/зависимости. Версии окружения со временем меняются.
- SecureStorage фактически использует SharedPreferences; объявленный
  flutter_secure_storage не используется этим классом.
- Общий Dio логирует тела запросов и ответов без ограничения debug-режимом.
  В отслеживаемой конфигурации запуска есть значение API-ключа. Значения здесь
  не воспроизводятся; действительность ключа не проверялась.
- ResultsNotifier вызывает xdg-open без отдельной macOS-ветки.
- В UI есть устаревшие комментарии о STUB и отсутствующем историческом документе
  MISSING_ENDPOINTS.md. Этот документ не существует и не является контрактом.
- CI, task runner, локальный OpenAPI, подключённый CodeGraph и repo skill
  этой системой не создаются. `docs/ai/research/` содержит backend-снимки для
  планирования; новые frontend-исследования добавляются только в выбранном scope.
