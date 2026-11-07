# Конфигурация gateway DictAI

TASK-FE-001.05: `API_BASE_URL` обязателен и задаётся через `--dart-define`.
Разрешён только origin gateway: HTTPS, host и optional port, без path/query/fragment,
credentials или токенов. Нет встроенного адреса стенда/production и HTTP fallback.
Без валидной конфигурации создание API-клиента явно завершается config error;
экран настройки окружения этой задачей не добавляется.

```sh
flutter run -d macos --dart-define=API_BASE_URL=https://gateway.example.invalid
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=ALLOW_INSECURE_LOCALHOST=true
```

`example.invalid` — placeholder, не стенд. Для HTTP нужны **оба** условия: debug build
и явный `ALLOW_INSECURE_LOCALHOST=true`; разрешены только localhost/127.0.0.1/::1.
Profile/release требуют HTTPS даже при флаге. Launch/example настроены только на
явный локальный debug origin; для реального стенда оператор даёт URL и доверенную PKI.
Проверка TLS стандартная: нет `badCertificateCallback`, bypass/pinning неизвестного
сертификата или коммита приватного ключа. Не добавлять credentials в defines.

`HTTP_DIAGNOSTICS=true` включает .03 diagnostics только в debug: local numeric
request ID, allowlisted method/status. URL, headers, body и raw errors не логируются.
Release всегда отключает diagnostics. Auth/JWT остаётся в общем AuthInterceptor.

Перед чтением JWT общий клиент проверяет exact scheme/host/effective port;
relative paths разрешены, foreign absolute/scheme-relative URLs и embedded credentials
запрещены. Automatic redirects отключены и не могут быть включены per-request: JWT
не должен перейти на другой origin через 302. Ссылки original/documents не signed
public downloads и не разрешение direct MinIO/NATS/model доступа.

Timeout policy: connect 10 s; обычные API/status 30 s; multipart/V2 upload send/receive
15 min; document/original/bytes/stream receive 15 min. Это локальные пределы, не SLA:
server context upload 15 min и внешний proxy может завершить раньше. Длинный download
в дальнейшем будет streaming-to-file (.30), здесь он не реализуется.

**Автоматических retries/replay нет**, включая GET/POST и 401 refresh. Потерянный
upload response не доказывает отказ: .20/.25 добавят journal/idempotency/backoff
по известному контракту. Server reprocess/cancel не предлагаются. Отдельные feature
timeouts могут быть пересмотрены только в соответствующем scope, без скрытого bypass.

Тесты — `flutter test --no-pub test/core/config/app_config_test.dart`:
fake adapters и два ephemeral loopback HTTP сервера только для redirect regression,
без настоящего backend/credentials. Linux/macOS/TLS deployment smoke отдельно.
