package com.socialworld.auth;

import com.socialworld.auth.AuthModels.LoginRequest;
import com.socialworld.auth.AuthModels.PublicUser;
import com.socialworld.auth.AuthModels.RegisterRequest;
import com.socialworld.auth.AuthModels.TokenResponse;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static com.socialworld.auth.AuthExceptions.*;

@Service
class AuthenticationService {
    private final UserRepository users;
    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final AuthProperties properties;
    private final String dummyPasswordHash;

    AuthenticationService(UserRepository users, JdbcTemplate jdbc, PasswordEncoder passwordEncoder,
                          TokenService tokens, AuthProperties properties) {
        this.users = users;
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.properties = properties;
        this.dummyPasswordHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    @Transactional
    PublicUser register(RegisterRequest request) {
        String normalizedEmail = UserRepository.normalizeEmail(request.email());
        validatePassword(request.password());
        if (users.emailExists(normalizedEmail)) throw new EmailAlreadyRegistered();
        try {
            return users.create(normalizedEmail, request.displayName(), passwordEncoder.encode(request.password())).toPublic();
        } catch (DuplicateKeyException duplicate) {
            // The functional unique index is the concurrency-safe authority for registrations.
            throw new EmailAlreadyRegistered();
        }
    }

    @Transactional
    TokenResponse login(LoginRequest request) {
        Optional<UserRepository.UserRecord> found = users.findByEmail(request.email());
        UserRepository.UserRecord user = found.orElse(null);
        boolean passwordMatches = passwordEncoder.matches(request.password(),
                user == null || user.passwordHash() == null ? dummyPasswordHash : user.passwordHash());
        if (user == null || user.deletedAt() != null || user.passwordHash() == null || !passwordMatches) {
            throw new InvalidCredentials();
        }
        return createSession(user, Instant.now());
    }

    @Transactional
    TokenResponse refresh(String refreshToken) {
        String tokenHash = tokens.hashRefreshToken(refreshToken);
        RefreshSession session = findSessionForUpdate(tokenHash).orElseThrow(InvalidRefreshToken::new);
        Instant now = Instant.now();
        if (session.revokedAt() != null || !session.expiresAt().isAfter(now) || session.deletedAt() != null) {
            throw new InvalidRefreshToken();
        }

        String replacementToken = tokens.newRefreshToken();
        UUID replacementId = UUID.randomUUID();
        Instant refreshExpiresAt = now.plus(properties.getRefreshTokenTtl());
        jdbc.update("INSERT INTO refresh_session(id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
                replacementId, session.userId(), tokens.hashRefreshToken(replacementToken), Timestamp.from(refreshExpiresAt));
        int revoked = jdbc.update("""
                UPDATE refresh_session SET revoked_at = ?, replaced_by_session_id = ?
                WHERE id = ? AND revoked_at IS NULL
                """, Timestamp.from(now), replacementId, session.id());
        if (revoked != 1) throw new InvalidRefreshToken();

        PublicUser user = new PublicUser(session.userId(), session.email(), session.displayName(), session.userCreatedAt());
        return response(user, replacementToken, refreshExpiresAt, now);
    }

    @Transactional
    void logout(UUID userId, String refreshToken) {
        jdbc.update("""
                UPDATE refresh_session SET revoked_at = now()
                WHERE token_hash = ? AND user_id = ? AND revoked_at IS NULL
                """, tokens.hashRefreshToken(refreshToken), userId);
    }

    private TokenResponse createSession(UserRepository.UserRecord user, Instant now) {
        String refreshToken = tokens.newRefreshToken();
        Instant expiresAt = now.plus(properties.getRefreshTokenTtl());
        jdbc.update("INSERT INTO refresh_session(id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)",
                UUID.randomUUID(), user.id(), tokens.hashRefreshToken(refreshToken), Timestamp.from(expiresAt));
        return response(user.toPublic(), refreshToken, expiresAt, now);
    }

    private TokenResponse response(PublicUser user, String refreshToken, Instant refreshExpiresAt, Instant now) {
        return new TokenResponse(tokens.createAccessToken(user.id(), now), "Bearer",
                properties.getAccessTokenTtl().toSeconds(), refreshToken, refreshExpiresAt, user);
    }

    private Optional<RefreshSession> findSessionForUpdate(String tokenHash) {
        return jdbc.query("""
                SELECT rs.id, rs.user_id, rs.expires_at, rs.revoked_at,
                       u.email, u.display_name, u.created_at AS user_created_at, u.deleted_at
                FROM refresh_session rs JOIN app_user u ON u.id = rs.user_id
                WHERE rs.token_hash = ? FOR UPDATE OF rs
                """, REFRESH_SESSION_MAPPER, tokenHash).stream().findFirst();
    }

    private static void validatePassword(String password) {
        if (password.codePointCount(0, password.length()) < 12 ||
                password.getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new InvalidRequest("Password must contain at least 12 characters and no more than 72 UTF-8 bytes");
        }
    }

    private static final RowMapper<RefreshSession> REFRESH_SESSION_MAPPER = AuthenticationService::mapSession;

    private static RefreshSession mapSession(ResultSet rs, int row) throws SQLException {
        Timestamp revoked = rs.getTimestamp("revoked_at");
        Timestamp deleted = rs.getTimestamp("deleted_at");
        return new RefreshSession(rs.getObject("id", UUID.class), rs.getObject("user_id", UUID.class),
                rs.getTimestamp("expires_at").toInstant(), revoked == null ? null : revoked.toInstant(),
                rs.getString("email"), rs.getString("display_name"), rs.getTimestamp("user_created_at").toInstant(),
                deleted == null ? null : deleted.toInstant());
    }

    private record RefreshSession(UUID id, UUID userId, Instant expiresAt, Instant revokedAt, String email,
                                  String displayName, Instant userCreatedAt, Instant deletedAt) {}
}
