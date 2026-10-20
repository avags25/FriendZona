package com.socialworld.profile;

import com.socialworld.auth.AuthModels.ProfilePatchRequest;
import com.socialworld.auth.AuthModels.PublicUser;
import com.socialworld.auth.AuthExceptions;
import com.socialworld.auth.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class ProfileService {
    private final UserRepository users;

    ProfileService(UserRepository users) { this.users = users; }

    public PublicUser getOwnProfile(UUID userId) {
        return users.findActiveById(userId).orElseThrow(AuthExceptions.AccountUnavailable::new).toPublic();
    }

    @Transactional
    public PublicUser updateOwnProfile(UUID userId, ProfilePatchRequest request) {
        try {
            return users.updateDisplayName(userId, request.displayName()).toPublic();
        } catch (org.springframework.dao.EmptyResultDataAccessException missing) {
            throw new AuthExceptions.AccountUnavailable();
        }
    }
}
