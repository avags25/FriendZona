package com.socialworld.auth;

import com.socialworld.auth.AuthModels.PublicUser;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Repository
public class UserRepository {
    private final JdbcTemplate jdbc;

    public UserRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public Optional<UserRecord> findByEmail(String email) {
        return optional(() -> jdbc.queryForObject("""
                SELECT id, email, display_name, password_hash, created_at, deleted_at
                FROM app_user WHERE lower(btrim(email)) = ?
                """, UserRepository::mapUser, normalizeEmail(email)));
    }

    public Optional<UserRecord> findActiveById(UUID id) {
        return optional(() -> jdbc.queryForObject("""
                SELECT id, email, display_name, password_hash, created_at, deleted_at
                FROM app_user WHERE id = ? AND deleted_at IS NULL
                """, UserRepository::mapUser, id));
    }

    public boolean emailExists(String email) {
        Boolean exists = jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM app_user WHERE lower(btrim(email)) = ?)",
                Boolean.class, normalizeEmail(email));
        return Boolean.TRUE.equals(exists);
    }

    public UserRecord create(String email, String displayName, String passwordHash) {
        return jdbc.queryForObject("""
                INSERT INTO app_user(id, email, display_name, password_hash)
                VALUES (?, ?, ?, ?) RETURNING id, email, display_name, password_hash, created_at, deleted_at
                """, UserRepository::mapUser, UUID.randomUUID(), normalizeEmail(email), displayName.strip(), passwordHash);
    }

    public UserRecord updateDisplayName(UUID id, String displayName) {
        return jdbc.queryForObject("""
                UPDATE app_user SET display_name = ? WHERE id = ? AND deleted_at IS NULL
                RETURNING id, email, display_name, password_hash, created_at, deleted_at
                """, UserRepository::mapUser, displayName.strip(), id);
    }

    public static String normalizeEmail(String email) { return email.strip().toLowerCase(Locale.ROOT); }

    public static PublicUser publicUser(UserRecord user) {
        return new PublicUser(user.id(), user.email(), user.displayName(), user.createdAt());
    }

    private static UserRecord mapUser(ResultSet rs, int row) throws SQLException {
        return new UserRecord(rs.getObject("id", UUID.class), rs.getString("email"), rs.getString("display_name"),
                rs.getString("password_hash"), rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("deleted_at") == null ? null : rs.getTimestamp("deleted_at").toInstant());
    }

    private static Optional<UserRecord> optional(RecordSupplier supplier) {
        try { return Optional.of(supplier.get()); }
        catch (EmptyResultDataAccessException ignored) { return Optional.empty(); }
    }

    @FunctionalInterface private interface RecordSupplier { UserRecord get(); }

    public record UserRecord(UUID id, String email, String displayName, String passwordHash, Instant createdAt, Instant deletedAt) {
        public PublicUser toPublic() { return publicUser(this); }
    }
}
