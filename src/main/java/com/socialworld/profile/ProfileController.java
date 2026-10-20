package com.socialworld.profile;

import com.socialworld.auth.AuthModels.ProfilePatchRequest;
import com.socialworld.auth.AuthModels.PublicUser;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users/me")
public class ProfileController {
    private final ProfileService profiles;

    ProfileController(ProfileService profiles) { this.profiles = profiles; }

    @GetMapping
    public PublicUser getOwnProfile(@AuthenticationPrincipal Jwt jwt) {
        return profiles.getOwnProfile(UUID.fromString(jwt.getSubject()));
    }

    @PatchMapping("/profile")
    public PublicUser updateOwnProfile(@AuthenticationPrincipal Jwt jwt,
                                       @Valid @RequestBody ProfilePatchRequest request) {
        return profiles.updateOwnProfile(UUID.fromString(jwt.getSubject()), request);
    }
}
