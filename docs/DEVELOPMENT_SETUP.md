# Настройка разработки

Backend требует JDK 21, Maven Wrapper 3.9.11, Docker Compose и PostgreSQL/PostGIS. Для обычного запуска обязательны параметры БД и Base64 JWT secret минимум 32 байта. Храните их в локальном `.env` (он исключён из Git) или secret manager, не в коде.

## Запуск backend

```sh
cp .env.example .env
# задайте DB_PASSWORD и JWT_SECRET; JWT_SECRET создайте командой `openssl rand -base64 32`
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d
set -a; source .env; set +a
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH
./mvnw clean verify
./mvnw spring-boot:run
```

Если `8080` занят, задайте `export SERVER_PORT=8081` после загрузки `.env`. Проверка сервера и API:

```sh
curl -sS http://localhost:8080/actuator/health
```

Замените порт в URL, если выбрали другой. При остановке нажмите Ctrl+C только в окне backend. PostgreSQL остановите, сохранив данные, командой `docker compose --env-file .env -f infrastructure/docker-compose.yml stop db`. Не выполняйте `down -v` для обычной остановки.

Flyway применяет миграции при старте. Историю можно проверить в контейнере:

```sh
docker compose --env-file .env -f infrastructure/docker-compose.yml exec db \
  sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT installed_rank, version, description, success FROM flyway_schema_history ORDER BY installed_rank;"'
```

## Фактическая проверка локального backend (2026-10-20)

- В shell по умолчанию обнаружена Java 24; для запуска backend явно выбран JDK 21.0.12.1. Maven Wrapper — 3.9.11.
- Docker Engine 29.3.1, Docker Compose 5.1.1. Существующий `infrastructure-db-1` был healthy; PostgreSQL 16.9, база `social_world`.
- `.env` отсутствовал. Создан локальный файл с правами `0600`: DB-параметры взяты из работающего Compose контейнера, JWT secret сгенерирован случайно. Значения не выводились; `.env` игнорируется Git.
- До запуска read-only preflight подтвердил Flyway V1, 0 строк пользователей и 0 коллизий нормализованного email. Backend подключился к БД и применил V2; данные и volume не очищались.
- Порт 8080 уже был занят другим Java-процессом и не останавливался. Новый backend запущен на 8081 и остановлен после smoke test. Полные результаты HTTP-проверки приведены в `docs/TESTING.md`.

## Flutter-клиент на macOS

Flutter 3.47.7 и Dart 3.13.5 доступны в `~/development/flutter/bin`; Xcode 27.1, CocoaPods 1.17.0 и симулятор iPhone Duo (iOS 27.1) настроены. В стандартном shell PATH SDK может отсутствовать, поэтому добавьте его при необходимости:

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
flutter --version
flutter devices
```

Нативный iOS runner находится в `mobile/ios/`. Его Debug-конфигурация использует `Runner/Info-Debug.plist` для локального HTTP; Release/Profile используют `Runner/Info.plist`. Android debug cleartext разрешён только в `mobile/android/app/src/debug/AndroidManifest.xml`.

Запустите backend из корня репозитория, загрузив `.env`, и выберите свободный порт. В этой среде порт 8080 занят сторонним Java-процессом, который не следует останавливать; Social World запускается на 8081:

```sh
set -a; source .env; set +a
export SERVER_PORT=8081
./mvnw spring-boot:run
```

Проверьте, что health возвращает `UP`, прежде чем запускать клиент:

```sh
curl -sS http://127.0.0.1:8081/actuator/health
```

В другом терминале запустите iOS приложение:

```sh
cd mobile
flutter pub get
flutter run -d <simulator-id> --dart-define=API_BASE_URL=http://127.0.0.1:8081
```

ID устройства можно взять из `flutter devices`. Для Android Emulator URL хоста — `http://10.0.2.2:8081`; физическое устройство использует LAN-IP Mac. Если backend слушает другой порт, согласуйте `SERVER_PORT` и `API_BASE_URL`. Не останавливайте неизвестный процесс, если порт занят. Команды сборки и проверки UI описаны в `docs/TESTING.md`.
