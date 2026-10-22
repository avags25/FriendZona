package com.socialworld.friendship;

import com.socialworld.friendship.FriendshipModels.FriendProfile;
import com.socialworld.friendship.FriendshipModels.FriendRequestView;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class FriendshipRepository {
    private final JdbcTemplate jdbc;

    public FriendshipRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public void lockPair(UUID first, UUID second) {
        List<UUID> locked = jdbc.query("""
                SELECT id FROM app_user WHERE id IN (?, ?) AND deleted_at IS NULL ORDER BY id FOR UPDATE
                """, (rs, row) -> rs.getObject("id", UUID.class), first, second);
        if (locked.size() != 2) throw new com.socialworld.auth.AuthExceptions.AccountUnavailable();
    }

    public Optional<FriendshipRecord> findPairForUpdate(UUID low, UUID high) {
        return jdbc.query("""
                SELECT id, user_low_id, user_high_id, requester_id, recipient_id, status, created_at, updated_at
                FROM friendship_request WHERE user_low_id = ? AND user_high_id = ? FOR UPDATE
                """, FriendshipRepository::mapRecord, low, high).stream().findFirst();
    }

    public Optional<FriendshipRecord> findById(UUID requestId) {
        return jdbc.query("""
                SELECT id, user_low_id, user_high_id, requester_id, recipient_id, status, created_at, updated_at
                FROM friendship_request WHERE id = ?
                """, FriendshipRepository::mapRecord, requestId).stream().findFirst();
    }

    public Optional<FriendshipRecord> findByIdForUpdate(UUID requestId) {
        return jdbc.query("""
                SELECT id, user_low_id, user_high_id, requester_id, recipient_id, status, created_at, updated_at
                FROM friendship_request WHERE id = ? FOR UPDATE
                """, FriendshipRepository::mapRecord, requestId).stream().findFirst();
    }

    public FriendshipRecord create(UUID low, UUID high, UUID requester, UUID recipient) {
        return jdbc.queryForObject("""
                INSERT INTO friendship_request(id, user_low_id, user_high_id, requester_id, recipient_id)
                VALUES (?, ?, ?, ?, ?)
                RETURNING id, user_low_id, user_high_id, requester_id, recipient_id, status, created_at, updated_at
                """, FriendshipRepository::mapRecord, UUID.randomUUID(), low, high, requester, recipient);
    }

    public FriendshipRecord reopen(UUID id, UUID requester, UUID recipient) {
        return jdbc.queryForObject("""
                UPDATE friendship_request
                SET requester_id = ?, recipient_id = ?, status = 'PENDING', created_at = now(), updated_at = now()
                WHERE id = ?
                RETURNING id, user_low_id, user_high_id, requester_id, recipient_id, status, created_at, updated_at
                """, FriendshipRepository::mapRecord, requester, recipient, id);
    }

    public void setStatus(UUID id, String status) {
        jdbc.update("UPDATE friendship_request SET status = ?, updated_at = now() WHERE id = ?", status, id);
    }

    public void delete(UUID id) {
        jdbc.update("DELETE FROM friendship_request WHERE id = ?", id);
    }

    public List<FriendProfile> friends(UUID userId) {
        return jdbc.query("""
                SELECT u.id AS user_id, u.display_name, u.friend_code
                FROM friendship_request f
                JOIN app_user u ON u.id = CASE WHEN f.user_low_id = ? THEN f.user_high_id ELSE f.user_low_id END
                WHERE (f.user_low_id = ? OR f.user_high_id = ?) AND f.status = 'ACCEPTED'
                  AND u.deleted_at IS NULL
                ORDER BY lower(u.display_name), u.id
                """, FriendshipRepository::mapFriend, userId, userId, userId);
    }

    public List<FriendRequestView> requests(UUID userId, boolean incoming) {
        String direction = incoming ? "f.recipient_id = ?" : "f.requester_id = ?";
        String other = incoming ? "f.requester_id" : "f.recipient_id";
        return jdbc.query("""
                SELECT f.id, f.status, f.created_at, f.updated_at, u.id AS user_id,
                       u.display_name, u.friend_code
                FROM friendship_request f
                JOIN app_user u ON u.id = %s
                WHERE %s AND f.status = 'PENDING' AND u.deleted_at IS NULL
                ORDER BY f.created_at DESC, f.id
                """.formatted(other, direction), (rs, row) -> new FriendRequestView(
                rs.getObject("id", UUID.class), mapFriend(rs, row), rs.getString("status"),
                rs.getTimestamp("created_at").toInstant(), rs.getTimestamp("updated_at").toInstant()), userId);
    }

    public Optional<FriendRequestView> requestView(UUID requestId, UUID actorId) {
        return jdbc.query("""
                SELECT f.id, f.status, f.created_at, f.updated_at, u.id AS user_id,
                       u.display_name, u.friend_code
                FROM friendship_request f
                JOIN app_user u ON u.id = CASE WHEN f.requester_id = ? THEN f.recipient_id ELSE f.requester_id END
                WHERE f.id = ? AND (f.requester_id = ? OR f.recipient_id = ?) AND u.deleted_at IS NULL
                """, (rs, row) -> new FriendRequestView(rs.getObject("id", UUID.class), mapFriend(rs, row),
                rs.getString("status"), rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()), actorId, requestId, actorId, actorId).stream().findFirst();
    }

    private static FriendProfile mapFriend(ResultSet rs, int row) throws SQLException {
        return new FriendProfile(rs.getObject("user_id", UUID.class),
                rs.getString("display_name"), rs.getString("friend_code"));
    }

    private static FriendshipRecord mapRecord(ResultSet rs, int row) throws SQLException {
        return new FriendshipRecord(rs.getObject("id", UUID.class), rs.getObject("user_low_id", UUID.class),
                rs.getObject("user_high_id", UUID.class), rs.getObject("requester_id", UUID.class),
                rs.getObject("recipient_id", UUID.class), rs.getString("status"),
                rs.getTimestamp("created_at").toInstant(), rs.getTimestamp("updated_at").toInstant());
    }

    public record FriendshipRecord(UUID id, UUID lowId, UUID highId, UUID requesterId, UUID recipientId,
                                   String status, Instant createdAt, Instant updatedAt) {}
}
