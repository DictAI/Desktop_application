# iOS candidate и требования выпуска

Подготовительный checklist TASK-FE-002.19, 2026-11-18. Candidate не сформирован:
[TASK-FE-002.18 device/backend gate](IOS_DEVICE_E2E.ru.md) не пройден.
Archive/validation/TestFlight/App Store **NOT RUN**, публикация не выполнялась.
Commit/push исходников не разрешает upload, приглашения или Store release.

## Проверенные текущие настройки

Source: frontend `pubspec.yaml`, Runner Info.plist/project.pbxproj, Podfile/lock,
package config и manifests фактически locked plugins.

| Поле | Actual | Граница |
|---|---|---|
| App version/build | 1.0.0+1 из pubspec; Runner использует FLUTTER_BUILD_NAME/NUMBER | Не выбран Store candidate/build number |
| Bundle / minimum iOS | com.dictai.app / 13.0 | Не подтверждены App Store Connect ownership/registered identifier |
| Signing | DEVELOPMENT_TEAM отсутствует, valid codesigning identities=0 | Archive/install blocked |
| Mic permission | Русское объяснение в NSMicrophoneUsageDescription | Нужны review фактического текста/локализаций и physical permission smoke |
| Background | UIBackgroundModes=audio | Нужен physical recording/interruption/lock evidence |
| Transport | ATS exception dictionary отсутствует; приложение требует HTTPS | Реальный production endpoint/TLS ещё отдельный gate |
| Broad Files sharing | UIFileSharingEnabled/LSSupportsOpeningDocumentsInPlace отсутствуют | Выбранные копии import/export проверяются отдельно |
| App privacy manifest | ios/Runner/PrivacyInfo.xcprivacy отсутствует | Privacy/required-reason audit открыт |

## Gate перед candidate

1. Завершить .18 с фактическими device/backend measurements и независимым review.
   Зафиксировать candidate frontend SHA/clean diff, backend deployed SHA,
   configuration version, locked SDK/dependencies, version/build и bundle.
2. Владелец предоставляет signing team/profile/certificate и подтверждает bundle
   ownership. Секреты/ключи не сохраняются в task records. Не включать automatic
   provisioning updates без отдельного решения владельца.
3. После выбора candidate собрать `flutter build ipa --release --no-pub` тем же
   проверенным SDK и разрешённым HTTPS API_BASE_URL. Записать фактическую команду,
   Xcode/SDK, archive/export paths, hashes и exit result. Не запускать заранее
   ради заведомо отсутствующей подписи и не считать unsigned build архивом.
4. Проверить archive contents, entitlements/permission strings, embedded SDK
   privacy manifests, symbols и фактический режим background audio. Локальная
   сборка, signed archive, export, App Store Connect validation и approval —
   отдельные результаты с отдельным evidence.

## Privacy и данные

Locked plugin audit: shared_preferences_foundation2.5.6 manifest содержит
NSPrivacyAccessedAPICategoryUserDefaults/reason1C8F.1. file_picker8.3.7,
record_darwin1.2.2, flutter_secure_storage9.2.4, path_provider_foundation2.5.1,
url_launcher_ios6.3.6 имеют manifests без declared required-reason categories.
У audioplayers_darwin6.4.0 package manifest при этом audit не найден.
Это не доказывает отсутствие required-reason API: app/import/journal вызывают
File.stat, native file_picker читает attributesOfItem. Нужна сверка actual
linked app/SDK calls и актуальных Apple allowed reasons; выбирать reason по
реальному назначению, а не копировать пустой manifest. Dependency declarations
не закрывают прямые вызовы приложения.

До выпуска владелец подтверждает privacy manifest и App Store privacy answers
по фактическим потокам: email/account identifiers, auth/session, audio,
transcript/summary, contacts/recipient emails, backend model/LLM providers,
retention, backup/file protection и удаление/exports. Просмотреть locked
transitive SDK и network destinations; отсутствие advertising dependencies
само по себе не доказывает ответы «данные не собираются»/«tracking=false».
Store answers, legal policy, export compliance/encryption declarations и
разрешённые required reasons в этом проходе не выдумывались и не валидировались
по актуальному Store review; владелец/оператор предоставляет проверяемый ответ.

## Публичные обязательные inputs

- Проверенные privacy policy/support URLs и contact owner, действительные для
  текущего продукта/хранения/провайдеров. В репозитории они не назначены.
- Review access: доступный reviewer test account/backend и инструкции, отсутствие
  private CA/tunnel prerequisites для reviewer, правдивое описание mic/background.
- Account deletion: в текущем backend нет auth/gateway HTTP capability удаления
  аккаунта. DB DeleteUser helper, logout и delete result не заменяют удаление
  аккаунта. Для приложения с регистрацией это открытый release blocker; проверить
  актуальное требование Apple и подготовить поддержанную возможность отдельно.
- License/model/provider conditions, lawful audio use и privacy labels проверяет
  владелец. Synthetic quality tests не обосновывают рекламные обещания точности.

TestFlight/App Store upload, внешние приглашения и release требуют отдельного
поручения владельца. Готовность checklist не равна candidate или публикации.
При локальной установке Store gate остаётся явно отдельным и не маскируется.

## Evidence перед выпуском

Зафиксировать build/version/bundle/team owner; frontend/backend SHA; completed
.18 run IDs; archive/export hashes и validation result; reviewed privacy answers,
URLs/review access; account deletion outcome; known residual risks и разрешение
владельца на конкретный upload/release. Невыполненные поля остаются NOT RUN/BLOCKED.
