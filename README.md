# Social World

Техническая основа продукта для планирования реальных встреч между друзьями. Backend на Spring Boot/PostgreSQL/PostGIS включает регистрацию, вход, управление refresh-сессией и собственным профилем. В `mobile/` находится Flutter-клиент для регистрации, входа, просмотра/изменения собственного профиля и выхода; iOS runner подготовлен. Клиент проверен на iPhone Duo Simulator (iOS 27.1), включая реальный auth/profile поток к локальному backend. Сценарии встреч ещё не реализованы.

## Быстрый старт

Требуются JDK 21 и Docker Compose. Скопируйте `.env.example` в `.env`, задайте локальный пароль БД и секрет JWT. Секрет можно сгенерировать командой `openssl rand -base64 32`; храните его только в игнорируемом `.env` или secret manager. Maven Wrapper скачает закреплённый Maven 3.9.11 при первом запуске:

```sh
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d
# для нового checkout: задайте DB_PASSWORD и JWT_SECRET в .env;
# секрет генерируется командой openssl rand -base64 32
set -a; source .env; set +a
# если порт 8080 занят, выберите другой, например:
export SERVER_PORT=8081
./mvnw spring-boot:run
```

API этапа 2: `POST /api/v1/auth/register`, `/login`, `/refresh`, авторизованный `/logout`, `GET /api/v1/users/me` и `PATCH /api/v1/users/me/profile`. JWT действует 15 минут, refresh-токен — 30 дней; сроки можно задать через `ACCESS_TOKEN_TTL` и `REFRESH_TOKEN_TTL`. Для полного контракта и примеров ошибок см. [API](docs/API.md) и [безопасность](docs/SECURITY.md). Flyway V2 добавляет пароль и refresh-сессии, не изменяя V1; учётные записи, созданные до этапа 2, не имеют пароля и требуют отдельного безопасного восстановления доступа.

Интеграционные тесты используют отдельный временный PostGIS контейнер и не подключаются к базе Compose. Требуются JDK 21 и Docker daemon. Запустить компиляцию, тесты и проверку пакета: `./mvnw clean verify`. Health endpoint работающего приложения: `curl http://localhost:8080/actuator/health`. Flyway применяет миграции при старте приложения. Проверить журнал Flyway и таблицы можно так:

```sh
docker compose --env-file .env -f infrastructure/docker-compose.yml exec db \
  sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT installed_rank, version, description, success FROM flyway_schema_history;"'
docker compose --env-file .env -f infrastructure/docker-compose.yml exec db \
  sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema() ORDER BY table_name;"'
```

Остановить приложение: `Ctrl+C` в окне backend. Остановить базу, сохранив данные: `docker compose --env-file .env -f infrastructure/docker-compose.yml stop db`. Не используйте `down -v`, если нужно сохранить volume.

## Flutter-клиент

Flutter 3.47.7, Xcode 27.1 и iPhone Duo Simulator установлены. Запустите backend с `SERVER_PORT=8081`, если порт 8080 занят, затем из `mobile/` выполните `flutter pub get` и `flutter run -d <simulator-id> --dart-define=API_BASE_URL=http://127.0.0.1:8081`. Команды анализа, тестов, сборки и интеграционного UI-сценария описаны в [тестировании](docs/TESTING.md); полная настройка — в [документации разработки](docs/DEVELOPMENT_SETUP.md).

Адрес API при будущем запуске мобильного клиента зависит от устройства: iOS Simulator — `http://127.0.0.1:<порт>`, Android Emulator — `http://10.0.2.2:<порт>`, физическое устройство — `http://<LAN-IP-Mac>:<порт>` в той же сети. `10.0.2.2` — специальный alias Android Emulator для loopback хоста ([документация Android](https://developer.android.com/studio/run/emulator-networking-address)). Инструкции по Flutter находятся в [настройке разработки](docs/DEVELOPMENT_SETUP.md).

## Документы

- [PRD](docs/PRD.md), [архитектура](docs/ARCHITECTURE.md), [база данных](docs/DATABASE.md), [API](docs/API.md)
- [Безопасность](docs/SECURITY.md), [дорожная карта](docs/ROADMAP.md), [решения](docs/DECISIONS.md)
- [Настройка разработки](docs/DEVELOPMENT_SETUP.md), [тестирование](docs/TESTING.md)
