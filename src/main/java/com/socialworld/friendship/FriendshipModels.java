package com.socialworld.friendship;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

import java.time.Instant;
import java.util.UUID;

public final class FriendshipModels {
    private FriendshipModels() {}

    public record FriendCodeRequest(
            @NotBlank @Pattern(regexp = "(?i)^SW-[A-Z0-9]{10}$") String friendCode) {}

    public record FriendProfile(UUID userId, String displayName, String friendCode) {}

    public record FriendRequestView(UUID requestId, FriendProfile friend, String status,
                                    Instant createdAt, Instant updatedAt) {}
}
