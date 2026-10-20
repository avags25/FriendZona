# API

Префикс `/api/v1`, JSON, UUID идентификаторы. Ошибки возвращаются в формате Problem Details с дополнительным `code`. Актёр для защищённых запросов определяется исключительно из проверенного JWT `sub`.

## Этап 2: аутентификация и профиль

| Метод и путь | Доступ | Назначение |
|---|---|---|
| `POST /api/v1/auth/register` | публичный | Создать аккаунт, HTTP 201 с публичным профилем |
| `POST /api/v1/auth/login` | публичный | Проверить пароль, выдать access JWT и refresh token |
| `POST /api/v1/auth/refresh` | публичный, требуется refresh token в JSON | Однократно ротировать refresh token и выдать новую пару |
| `POST /api/v1/auth/logout` | Bearer access JWT | Отозвать refresh token текущего пользователя; HTTP 204 |
| `GET /api/v1/users/me` | Bearer access JWT | Получить свой профиль |
| `PATCH /api/v1/users/me/profile` | Bearer access JWT | Изменить своё отображаемое имя |

Регистрация:

```json
{"email":"person@example.com","password":"Correct Horse 42!","displayName":"Alex"}
```

Login/refresh успешны с HTTP 200 и ответом:

```json
{"accessToken":"<signed-jwt>","tokenType":"Bearer","expiresIn":900,"refreshToken":"<opaque-token>","refreshExpiresAt":"<RFC-3339 timestamp>","user":{"id":"<uuid>","email":"person@example.com","displayName":"Alex","createdAt":"<RFC-3339 timestamp>"}}
```

Refresh/logout принимают `{"refreshToken":"<opaque-token>"}`. Logout требует также `Authorization: Bearer <accessToken>`. Профиль принимает `{"displayName":"Alex Updated"}`; идентификатор пользователя в запросе не поддерживается.

Email удаляет внешние пробелы и переводится в lowercase перед поиском и записью. Пароль должен содержать не менее 12 символов и не более 72 байт UTF-8. Дубликат регистрации возвращает 409 (`EMAIL_ALREADY_REGISTERED`); неверный email/пароль входа возвращает одинаковый 401 (`INVALID_CREDENTIALS`). Невалидный, истёкший, отозванный или повторно использованный refresh token возвращает 401. Access JWT по умолчанию действует 15 минут, refresh token — 30 дней.

`GET /actuator/health` публичен. Другие маршруты API закрыты, если явно не разрешены. Защищённые endpoints получают UUID владельца из верифицированного JWT, а не из тела/пути запроса.

## Следующие API этапы

План MVP: дружба и запросы, поиск мест, создание/редактирование встреч, ответы участников, пагинация и маршруты. Для встреч клиент присылает place identity/provider snapshot, `startsAt`, IANA `timeZone`, invitee IDs, напоминания и `Idempotency-Key`. Только организатор редактирует встречу/приглашённых; участник меняет только собственный статус. Внешние сервисы подключаются через интерфейсы-провайдеры, mock-результаты маркируются. Эти endpoints ещё не реализованы.
