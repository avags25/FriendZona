package com.socialworld.friendship;

import com.socialworld.auth.AuthExceptions;
import com.socialworld.auth.UserRepository;
import com.socialworld.friendship.FriendshipModels.FriendCodeRequest;
import com.socialworld.friendship.FriendshipModels.FriendProfile;
import com.socialworld.friendship.FriendshipModels.FriendRequestView;
import com.socialworld.friendship.FriendshipRepository.FriendshipRecord;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.UUID;

import static com.socialworld.friendship.FriendshipExceptions.*;

@Service
public class FriendshipService {
    private static final String CODE_PATTERN = "(?i)^SW-[A-Z0-9]{10}$";

    private final UserRepository users;
    private final FriendshipRepository friendships;

    public FriendshipService(UserRepository users, FriendshipRepository friendships) {
        this.users = users;
        this.friendships = friendships;
    }

    public List<FriendProfile> listFriends(UUID actorId) {
        requireActiveActor(actorId);
        return friendships.friends(actorId);
    }

    public List<FriendRequestView> incoming(UUID actorId) {
        requireActiveActor(actorId);
        return friendships.requests(actorId, true);
    }

    public List<FriendRequestView> outgoing(UUID actorId) {
        requireActiveActor(actorId);
        return friendships.requests(actorId, false);
    }

    public FriendProfile lookup(UUID actorId, String code) {
        requireActiveActor(actorId);
        return users.findActiveByFriendCode(normalizeCode(code))
                .map(FriendshipService::toFriendProfile).orElseThrow(FriendCodeNotFound::new);
    }

    @Transactional
    public Submission sendRequest(UUID actorId, FriendCodeRequest request) {
        requireActiveActor(actorId);
        UUID targetId = users.findActiveByFriendCode(normalizeCode(request.friendCode()))
                .map(UserRepository.FriendRecord::id).orElseThrow(FriendCodeNotFound::new);
        if (actorId.equals(targetId)) throw new SelfRequest();

        UUID low = lower(actorId, targetId);
        UUID high = higher(actorId, targetId);
        friendships.lockPair(low, high);
        FriendshipRecord existing = friendships.findPairForUpdate(low, high).orElse(null);
        if (existing == null) {
            friendships.create(low, high, actorId, targetId);
            return new Submission(view(actorId, low, high), true);
        }

        if (existing.status().equals("PENDING")) {
            if (existing.requesterId().equals(actorId)) throw new RequestPending();
            // A reciprocal invitation confirms the request already waiting for this actor.
            friendships.setStatus(existing.id(), "ACCEPTED");
            return new Submission(view(actorId, low, high), false);
        }
        if (existing.status().equals("ACCEPTED")) throw new AlreadyFriends();

        friendships.reopen(existing.id(), actorId, targetId);
        return new Submission(view(actorId, low, high), false);
    }

    @Transactional
    public void accept(UUID actorId, UUID requestId) {
        FriendshipRecord request = lockRequestForActor(actorId, requestId);
        if (!request.status().equals("PENDING")) throw new InvalidTransition();
        if (!request.recipientId().equals(actorId)) throw new WrongRequestActor();
        friendships.setStatus(requestId, "ACCEPTED");
    }

    @Transactional
    public void decline(UUID actorId, UUID requestId) {
        FriendshipRecord request = lockRequestForActor(actorId, requestId);
        if (!request.status().equals("PENDING")) throw new InvalidTransition();
        if (!request.recipientId().equals(actorId)) throw new WrongRequestActor();
        friendships.setStatus(requestId, "DECLINED");
    }

    @Transactional
    public void cancel(UUID actorId, UUID requestId) {
        FriendshipRecord request = lockRequestForActor(actorId, requestId);
        if (!request.requesterId().equals(actorId)) throw new RequestNotFound();
        if (!request.status().equals("PENDING")) throw new InvalidTransition();
        friendships.delete(requestId);
    }

    @Transactional
    public void removeFriend(UUID actorId, UUID friendId) {
        requireActiveActor(actorId);
        if (actorId.equals(friendId) || users.findActiveById(friendId).isEmpty()) {
            throw new FriendshipNotFound();
        }
        UUID low = lower(actorId, friendId);
        UUID high = higher(actorId, friendId);
        friendships.lockPair(low, high);
        FriendshipRecord relation = friendships.findPairForUpdate(low, high)
                .filter(value -> value.status().equals("ACCEPTED"))
                .orElseThrow(FriendshipNotFound::new);
        friendships.delete(relation.id());
    }

    private FriendshipRecord lockRequestForActor(UUID actorId, UUID requestId) {
        requireActiveActor(actorId);
        FriendshipRecord observed = friendships.findById(requestId).orElseThrow(RequestNotFound::new);
        friendships.lockPair(observed.lowId(), observed.highId());
        FriendshipRecord current = friendships.findByIdForUpdate(requestId).orElseThrow(RequestNotFound::new);
        if (!current.requesterId().equals(actorId) && !current.recipientId().equals(actorId)) {
            throw new RequestNotFound();
        }
        return current;
    }

    private FriendRequestView view(UUID actorId, UUID low, UUID high) {
        UUID requestId = friendships.findPairForUpdate(low, high).orElseThrow().id();
        return friendships.requestView(requestId, actorId).orElseThrow(RequestNotFound::new);
    }

    private void requireActiveActor(UUID actorId) {
        users.findActiveById(actorId).orElseThrow(AuthExceptions.AccountUnavailable::new);
    }

    private static FriendProfile toFriendProfile(UserRepository.FriendRecord user) {
        return new FriendProfile(user.id(), user.displayName(), user.friendCode());
    }

    private static String normalizeCode(String code) {
        if (code == null || !code.strip().matches(CODE_PATTERN)) throw new AuthExceptions.InvalidRequest("Friend code format is invalid");
        return code.strip().toUpperCase(Locale.ROOT);
    }

    private static UUID lower(UUID first, UUID second) {
        return first.toString().compareTo(second.toString()) < 0 ? first : second;
    }

    private static UUID higher(UUID first, UUID second) {
        return first.toString().compareTo(second.toString()) < 0 ? second : first;
    }

    public record Submission(FriendRequestView view, boolean created) {}
}
