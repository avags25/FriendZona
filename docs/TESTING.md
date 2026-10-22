# Тестирование

## Интеграционные тесты

`src/test/java/com/socialworld/DatabaseIntegrationTest.java` содержит 5 проверок: старт полного контекста, применение Flyway без повторных записей, фактическую схему/ограничения, PostGIS/geography/GIST и health endpoint.

`src/test/java/com/socialworld/AuthenticationIntegrationTest.java` содержит 22 проверки: регистрацию и уникальность email (включая параллельный запрос), валидацию, хранение пароля-хэша, единообразные ошибки login, выпуск JWT, защиту от отсутствующего/поддельного/истёкшего access token, ротацию/срок действия и параллельное повторное использование refresh-токена, logout/владение сессией, профиль и защиту от подмены пользователя, удалённый аккаунт и health. Вместе с тестами дружбы в Maven lifecycle 36 проверок.

Оба набора запускают отдельный временный `postgis/postgis:16-3.5` Testcontainers контейнер с тестовыми учётными данными и собственным `social_world_test`-подобным database name. Конфигурация подменяется через `@DynamicPropertySource`; production/dev `.env` и Compose база не читаются и не меняются. Секрет JWT тестовый и существует только в тестовом коде. Контейнеры сохраняются до конца JVM, чтобы не завершиться раньше Spring context.

PostGIS выбран вместо H2, потому что тесты применяют те же Flyway SQL и проверяют настоящие расширение, `GEOGRAPHY(POINT,4326)`, PostGIS version и GiST-индекс. H2 этого поведения не воспроизводит.

## Запуск

Нужны JDK 21, Maven Wrapper и Docker daemon, доступный Testcontainers. При первом запуске необходима сеть к Maven Central и Docker Registry.

```sh
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"
./mvnw clean verify
```

Проверки входят в Maven `verify`; достаточно запускать команду из корня репозитория. Тесты не подключаются к локальной базе и не удаляют volumes. Существующие development Compose контейнеры/данные для Testcontainers не используются.

## Результаты и неполадки

В Maven-выводе смотрите `Tests run`, `Failures`, `Errors`, `Skipped` и итог `BUILD SUCCESS`. Подробные отчёты находятся в `target/surefire-reports/`; XML содержит результаты отдельно для каждого класса. Для ожидаемого успешного запуска оба класса должны завершиться с нулём ошибок/падений/пропусков.

Если Docker недоступен, тест завершается ошибкой Testcontainers с причиной обнаружения daemon; проверка не отключается и не пропускается. Проверьте, что Docker Desktop/daemon запущен и текущий процесс имеет доступ к сокету, затем повторите `./mvnw clean verify`. Если Docker Registry недоступен, ошибка будет содержать имя образа и ошибку pull. При проблеме Maven Central Maven выведет конкретный артефакт и URL; восстановите доступ к сети или используйте настроенный корпоративный mirror, затем повторите команду. Не подменяйте PostGIS на H2 и не направляйте тесты на локальную БД.

Для тестовых контекстов передаётся тестовый ключ JWT; обычный `spring-boot:run` требует непустой `JWT_SECRET` из окружения. См. `docs/DEVELOPMENT_SETUP.md` и `docs/SECURITY.md`.

## Последняя проверка

2026-10-20: `./mvnw clean verify` на JDK 21.0.12.1 завершился `BUILD SUCCESS`: 27 тестов, 0 failures, 0 errors, 0 skipped. На Apple Silicon оба Testcontainers PostGIS контейнера запускались как amd64 под Docker эмуляцией. Flyway чистой тестовой базы успешно выполнил V1 и V2; повторный `flyway.migrate()` не добавил повторные записи.

## Локальный HTTP smoke test

2026-10-20 backend был запущен с JDK 21 на порту 8081 и подключился к существующему Compose PostgreSQL 16.9. Flyway применил V2 к схеме v1 после read-only проверки, что таблица пользователей пуста и коллизий нормализованного email нет. Порт 8080 был занят существующим процессом; он и база не останавливались. Smoke test использовал случайный временный email и пароль, а выводил только статусы.

| Запрос | Результат |
|---|---:|
| `GET /actuator/health` | 200, JSON `status: UP` |
| Регистрация нового аккаунта | 201 |
| Повторная регистрация с нормализованным email | 409 |
| Невалидная регистрация | 400 |
| Вход с правильным паролем | 200 |
| Вход с неправильным паролем | 401 |
| `GET /api/v1/users/me` без токена / с access token | 401 / 200 |
| Изменение `displayName` | 200 |
| Refresh / повтор старого refresh token | 200 / 401 |
| Logout / refresh после logout | 204 / 401 |

Тестовый аккаунт и две отозванные refresh-сессии остались в development базе; они не удалялись. Docker volume сохранён. Smoke-test процесс backend на 8081 остановлен после завершения проверки.

## Оставшееся покрытие

Ограничение частоты запросов, восстановление доступа/email-подтверждение и отзывание уже выданных access JWT до истечения пока не покрыты. API встреч и соответствующая мобильная функциональность ещё не реализованы.

## Flutter-клиент

В `mobile/test/` находятся 13 unit/widget-проверок API-моделей, валидации, ошибок и управления сессией. `mobile/integration_test/auth_flow_test.dart` выполняет UI-сценарий на iOS Simulator через настоящий backend: регистрация, выход, вход, загрузка профиля, изменение имени и повторный выход. Учётная запись создаётся с уникальным email; пароль и токены в вывод теста не записываются. Интеграционная проверка требует доступного backend с рабочей базой и использует контракт из `docs/API.md`.

Для запуска нужны Flutter 3.47.7+, Xcode/iOS Simulator (или для обычных проверок — только Flutter SDK), JDK 21 и Docker/PostgreSQL для backend. В текущей среде Flutter SDK расположен в `~/development/flutter/bin`, iOS runner создан в `mobile/ios/`, симулятор — iPhone Duo с iOS 27.1.

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
cd mobile
flutter pub get
dart format .
flutter analyze
flutter test
flutter build ios --simulator --dart-define=API_BASE_URL=http://127.0.0.1:8081
flutter test integration_test/auth_flow_test.dart -d <simulator-id> \
  --dart-define=API_BASE_URL=http://127.0.0.1:8081
flutter run -d <simulator-id> --dart-define=API_BASE_URL=http://127.0.0.1:8081
```

Перед интеграционным тестом проверьте `GET /actuator/health` и доступность auth routes. Для текущей конфигурации backend запускается на `SERVER_PORT=8081`, потому что порт 8080 занят другим Java-процессом; перед повторным запуском проверьте порт и не останавливайте неизвестный процесс. iOS Simulator обращается к Mac через `127.0.0.1`; Android Emulator — через `10.0.2.2`. Клиент выполняет реальные HTTP-запросы, а не подменяет backend mock API.

Пакеты разрешены в `mobile/pubspec.lock`; интеграционный target использует `integration_test` из Flutter SDK. Запуск integration test на симуляторе собирает iOS test runner отдельно от `flutter build ios --simulator`.

## Результаты Flutter-проверок (2026-10-21)

- `flutter pub get` — успешно, lockfile обновлён для `integration_test`.
- `dart format .` — успешно; после добавления теста отформатированы файлы проекта.
- `flutter analyze` — `No issues found`.
- `flutter test` — 13 passed, 0 failed.
- `flutter build ios --simulator --dart-define=API_BASE_URL=http://127.0.0.1:8081` — успешно; создан `mobile/build/ios/iphonesimulator/Runner.app`.
- `flutter test integration_test/auth_flow_test.dart -d 14DA36B7-8AAB-49CD-8EF3-2BBF150AAAE0 --dart-define=API_BASE_URL=http://127.0.0.1:8081` — 1 passed, 0 failed.
- `flutter run -d 14DA36B7-8AAB-49CD-8EF3-2BBF150AAAE0 --dart-define=API_BASE_URL=http://127.0.0.1:8081` — приложение запущено на iPhone Duo; Flutter VM service активен.
- Social World health на 8081 вернул HTTP 200. В тестовой интеграции реально прошли регистрация, login, `GET /api/v1/users/me`, `PATCH /api/v1/users/me/profile` и logout. Текущие сессии/учётная запись созданы в локальной development базе и не удалялись.

Сначала был проверен занятой 8080: health отвечал, но Social World auth routes возвращали 404, поэтому процесс оставлен без изменений. На свободном 8081 запущен этот Spring Boot backend с локальным `.env`; Flyway сообщил, что схема версии 2 актуальна. Если Docker/сеть недоступны, integration test должен завершиться ошибкой подключения или сборки с причиной; он не пропускается и не подключается к development DB через Testcontainers.
# Дружеские сценарии

Backend `FriendshipIntegrationTest` запускает полный Spring контекст на отдельном PostgreSQL/PostGIS Testcontainers и проверяет lookup, приватность профиля, создание/повтор запросов, принятие, отказ, отмену, удаление, IDOR/права, встречные запросы и actuator. `FriendshipMigrationIntegrationTest` поднимает схему до V2, создаёт legacy-пользователя и применяет V3, подтверждая сохранность его исходных данных и выдачу кода. Существующие auth и database интеграционные проверки остаются в lifecycle.

Flutter-тесты проверяют отображение/сохранение friend code и разбор DTO/ошибок API; UI использует настоящий backend через общий Dio с auth/refresh interceptor. Интеграционный контракт использует реальный PostgreSQL/PostGIS, поэтому H2 не подходит: он не может подтвердить Flyway/PostGIS или PostgreSQL ограничения и конкурентные транзакции.

Требуются JDK 21 и доступный Docker daemon; тестовая БД создаётся как временный контейнер и не использует `.env` или compose volume. Запуск из корня: `./mvnw clean verify`. Для мобильного клиента из `mobile/`: `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, `flutter build ios --simulator`. Если Docker недоступен, Testcontainers выдаёт ошибку `Could not find a valid Docker environment`; запустите Docker Desktop/daemon и повторите команду. Если сеть недоступна при загрузке Maven/Flutter зависимостей, сохраните конкретное сообщение и повторите после восстановления доступа к Maven Central/pub.dev; тесты не пропускаются автоматически.

## Результат системы друзей (2026-10-22)

- JDK 21.0.12.1: `./mvnw clean verify` — `BUILD SUCCESS`, 36 passed, 0 failures/errors/skipped. В тестовой базе PostgreSQL 16.9/PostGIS успешно применены V1–V3; отдельный migration test подтвердил backfill friend code существующему аккаунту без изменения legacy полей.
- Flutter 3.47.7: `pub get`, `dart format .`, `flutter analyze` и `flutter test` завершились успешно; 16 тестов прошли. `flutter build ios --simulator` создал `mobile/build/ios/iphonesimulator/Runner.app`; приложение запущено на iPhone Duo Simulator.
- Development Compose DB сохранила данные; при старте backend на свободном 8081 Flyway применил V3. `/actuator/health` вернул `{"groups":["liveness","readiness"],"status":"UP"}`. Полный ручной двухпользовательский UI сценарий не запускался; его базовые состояния и права покрыты backend integration tests.
