package com.socialworld.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class AuthModels {
    private AuthModels() {}

    public record RegisterRequest(
            @NotBlank @Email @Size(max = 320) String email,
            @NotBlank @Size(min = 12, max = 72) String password,
            @NotBlank @Size(max = 80) String displayName) {
        public RegisterRequest { if (email != null) email = email.strip(); }
    }

    public record LoginRequest(@NotBlank @Email @Size(max = 320) String email, @NotBlank String password) {
        public LoginRequest { if (email != null) email = email.strip(); }
    }
    public record RefreshRequest(@NotBlank String refreshToken) {}
    public record LogoutRequest(@NotBlank String refreshToken) {}
    public record ProfilePatchRequest(@NotBlank @Size(max = 80) String displayName) {}

    public record PublicUser(UUID id, String email, String displayName, Instant createdAt) {}
    public record TokenResponse(String accessToken, String tokenType, long expiresIn,
                                String refreshToken, Instant refreshExpiresAt, PublicUser user) {}
}
