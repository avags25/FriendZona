# API

Префикс `/api/v1`, JSON, UUID идентификаторы. Ошибки возвращаются в формате Problem Details с дополнительным `code`. Актёр для защищённых запросов определяется исключительно из проверенного JWT `sub`.

## Этап 2: аутентификация, профиль и друзья

| Метод и путь | Доступ | Назначение |
|---|---|---|
| `POST /api/v1/auth/register` | публичный | Создать аккаунт, HTTP 201 с публичным профилем |
| `POST /api/v1/auth/login` | публичный | Проверить пароль, выдать access JWT и refresh token |
| `POST /api/v1/auth/refresh` | публичный, требуется refresh token в JSON | Однократно ротировать refresh token и выдать новую пару |
| `POST /api/v1/auth/logout` | Bearer access JWT | Отозвать refresh token текущего пользователя; HTTP 204 |
| `GET /api/v1/users/me` | Bearer access JWT | Получить свой профиль, включая постоянный `friendCode` |
| `PATCH /api/v1/users/me/profile` | Bearer access JWT | Изменить своё отображаемое имя |
| `GET /api/v1/friends` | Bearer access JWT | Список друзей текущего пользователя |
| `GET /api/v1/friends/lookup?code=SW-...` | Bearer access JWT | Найти пользователя по коду друга |
| `POST /api/v1/friends/requests` | Bearer access JWT | Создать запрос: `{"friendCode":"SW-..."}` |
| `GET /api/v1/friends/requests/incoming` | Bearer access JWT | Входящие ожидающие запросы |
| `GET /api/v1/friends/requests/outgoing` | Bearer access JWT | Исходящие ожидающие запросы |
| `POST /api/v1/friends/requests/{id}/accept` | Bearer access JWT | Принять адресованный текущему пользователю запрос (204) |
| `POST /api/v1/friends/requests/{id}/decline` | Bearer access JWT | Отклонить адресованный текущему пользователю запрос (204) |
| `DELETE /api/v1/friends/requests/{id}` | Bearer access JWT | Отменить собственный исходящий запрос (204) |
| `DELETE /api/v1/friends/{friendUserId}` | Bearer access JWT | Удалить существующую дружбу (204) |

Регистрация:

```json
{"email":"person@example.com","password":"Correct Horse 42!","displayName":"Alex"}
```

Login/refresh успешны с HTTP 200 и ответом:

```json
{"accessToken":"<signed-jwt>","tokenType":"Bearer","expiresIn":900,"refreshToken":"<opaque-token>","refreshExpiresAt":"<RFC-3339 timestamp>","user":{"id":"<uuid>","email":"person@example.com","displayName":"Alex","friendCode":"SW-XXXXXXXXXX","createdAt":"<RFC-3339 timestamp>"}}
```

Refresh/logout принимают `{"refreshToken":"<opaque-token>"}`. Logout требует также `Authorization: Bearer <accessToken>`. Профиль принимает `{"displayName":"Alex Updated"}`; идентификатор пользователя в запросе не поддерживается.

Email удаляет внешние пробелы и переводится в lowercase перед поиском и записью. Пароль должен содержать не менее 12 символов и не более 72 байт UTF-8. Дубликат регистрации возвращает 409 (`EMAIL_ALREADY_REGISTERED`); неверный email/пароль входа возвращает одинаковый 401 (`INVALID_CREDENTIALS`). Невалидный, истёкший, отозванный или повторно использованный refresh token возвращает 401. Access JWT по умолчанию действует 15 минут, refresh token — 30 дней.

`GET /actuator/health` публичен. Другие маршруты API закрыты, если явно не разрешены. Защищённые endpoints получают UUID владельца из верифицированного JWT, а не из тела/пути запроса.

Код друга уникален, выдаётся сервером и не изменяется через профиль. Lookup и списки друзей возвращают только публичные данные (`userId`, `displayName`, `friendCode`), без email. Для пары пользователей хранится одна строка: повторный запрос той же стороны конфликтует; встречный запрос автоматически переводит ожидающий запрос в дружбу; отклонённую пару можно пригласить снова. Принимать/отклонять может только получатель, отменять — только инициатор.

## Следующие API этапы

План MVP: дружба и запросы, поиск мест, создание/редактирование встреч, ответы участников, пагинация и маршруты. Для встреч клиент присылает place identity/provider snapshot, `startsAt`, IANA `timeZone`, invitee IDs, напоминания и `Idempotency-Key`. Только организатор редактирует встречу/приглашённых; участник меняет только собственный статус. Внешние сервисы подключаются через интерфейсы-провайдеры, mock-результаты маркируются. Эти endpoints ещё не реализованы.
