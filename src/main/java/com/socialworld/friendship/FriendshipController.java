package com.socialworld.friendship;

import com.socialworld.friendship.FriendshipModels.FriendCodeRequest;
import com.socialworld.friendship.FriendshipModels.FriendProfile;
import com.socialworld.friendship.FriendshipModels.FriendRequestView;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/friends")
public class FriendshipController {
    private final FriendshipService friendships;

    public FriendshipController(FriendshipService friendships) { this.friendships = friendships; }

    @GetMapping
    public List<FriendProfile> listFriends(@AuthenticationPrincipal Jwt jwt) {
        return friendships.listFriends(userId(jwt));
    }

    @GetMapping("/lookup")
    public FriendProfile lookup(@AuthenticationPrincipal Jwt jwt, @RequestParam String code) {
        return friendships.lookup(userId(jwt), code);
    }

    @PostMapping("/requests")
    public ResponseEntity<FriendRequestView> sendRequest(@AuthenticationPrincipal Jwt jwt,
                                                          @Valid @RequestBody FriendCodeRequest request) {
        FriendshipService.Submission submission = friendships.sendRequest(userId(jwt), request);
        return ResponseEntity.status(submission.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(submission.view());
    }

    @GetMapping("/requests/incoming")
    public List<FriendRequestView> incoming(@AuthenticationPrincipal Jwt jwt) {
        return friendships.incoming(userId(jwt));
    }

    @GetMapping("/requests/outgoing")
    public List<FriendRequestView> outgoing(@AuthenticationPrincipal Jwt jwt) {
        return friendships.outgoing(userId(jwt));
    }

    @PostMapping("/requests/{requestId}/accept")
    public ResponseEntity<Void> accept(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID requestId) {
        friendships.accept(userId(jwt), requestId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/requests/{requestId}/decline")
    public ResponseEntity<Void> decline(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID requestId) {
        friendships.decline(userId(jwt), requestId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/requests/{requestId}")
    public ResponseEntity<Void> cancel(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID requestId) {
        friendships.cancel(userId(jwt), requestId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{friendUserId}")
    public ResponseEntity<Void> removeFriend(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID friendUserId) {
        friendships.removeFriend(userId(jwt), friendUserId);
        return ResponseEntity.noContent().build();
    }

    private static UUID userId(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
}
