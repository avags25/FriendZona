package com.socialworld;

import com.socialworld.auth.AuthProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.MockMvcPrint;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import com.jayway.jsonpath.JsonPath;

@SpringBootTest
@AutoConfigureMockMvc(print = MockMvcPrint.NONE)
class FriendshipIntegrationTest {
    private static final String TEST_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    private static final PostgreSQLContainer POSTGIS = new PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.5").asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("social_world_friends_test").withUsername("test_user").withPassword("test_password");

    static {
        POSTGIS.start();
        Runtime.getRuntime().addShutdownHook(new Thread(POSTGIS::stop, "stop-friends-test-postgis"));
    }

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGIS::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGIS::getUsername);
        registry.add("spring.datasource.password", POSTGIS::getPassword);
        registry.add("social-world.auth.jwt-secret", () -> TEST_SECRET);
    }

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;

    @Test
    void registrationProfileAndLookupExposeUniquePrivateFriendCode() throws Exception {
        Session first = account("code-first");
        Session second = account("code-second");
        assertThat(first.friendCode).matches("SW-[A-Z0-9]{10}").isNotEqualTo(second.friendCode);

        mvc.perform(get("/api/v1/users/me").header("Authorization", bearer(first.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.friendCode").value(first.friendCode));

        mvc.perform(patch("/api/v1/users/me/profile").header("Authorization", bearer(first.accessToken))
                        .contentType(APPLICATION_JSON)
                        .content("{\"displayName\":\"Code Owner Updated\",\"friendCode\":\"SW-AAAAAAAAAA\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.friendCode").value(first.friendCode));

        mvc.perform(get("/api/v1/friends/lookup").param("code", first.friendCode.toLowerCase())
                        .header("Authorization", bearer(second.accessToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(first.userId.toString()))
                .andExpect(jsonPath("$.displayName").value("Code Owner Updated"))
                .andExpect(jsonPath("$.friendCode").value(first.friendCode))
                .andExpect(jsonPath("$.email").doesNotExist());

        mvc.perform(get("/api/v1/friends/lookup").param("code", "SW-0000000000")
                        .header("Authorization", bearer(second.accessToken)))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("FRIEND_CODE_NOT_FOUND"));
        assertThat(jdbc.queryForObject("SELECT friend_code FROM app_user WHERE id = ?", String.class, first.userId))
                .isEqualTo(first.friendCode);
    }

    @Test
    void requestListsArePrivateAndRepeatedRequestsDoNotDuplicateRows() throws Exception {
        Session sender = account("list-sender");
        Session recipient = account("list-recipient");
        Session stranger = account("list-stranger");

        send(sender, recipient.friendCode).andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.friend.userId").value(recipient.userId.toString()))
                .andExpect(jsonPath("$.friend.email").doesNotExist());
        send(sender, recipient.friendCode).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("FRIEND_REQUEST_PENDING"));

        mvc.perform(get("/api/v1/friends/requests/outgoing").header("Authorization", bearer(sender.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].friend.userId").value(recipient.userId.toString()));
        mvc.perform(get("/api/v1/friends/requests/incoming").header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].friend.userId").value(sender.userId.toString()));
        mvc.perform(get("/api/v1/friends/requests/incoming").header("Authorization", bearer(stranger.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
        assertThat(pairCount(sender.userId, recipient.userId)).isEqualTo(1);
    }

    @Test
    void selfRequestInvalidCodeAndUnauthenticatedRequestsAreRejected() throws Exception {
        Session user = account("self");
        send(user, user.friendCode).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("SELF_FRIEND_REQUEST"));
        mvc.perform(get("/api/v1/friends/lookup").param("code", "not-a-code")
                        .header("Authorization", bearer(user.accessToken)))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        mvc.perform(get("/api/v1/friends")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/friends/requests/incoming")).andExpect(status().isUnauthorized());
    }

    @Test
    void onlyRecipientCanAcceptAndAcceptedFriendListsContainMinimalProfiles() throws Exception {
        Session sender = account("accept-sender");
        Session recipient = account("accept-recipient");
        Session stranger = account("accept-stranger");
        UUID requestId = requestId(send(sender, recipient.friendCode).andReturn());

        mvc.perform(post("/api/v1/friends/requests/{id}/accept", requestId)
                        .header("Authorization", bearer(sender.accessToken)))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("FRIEND_REQUEST_RECIPIENT_REQUIRED"));
        mvc.perform(post("/api/v1/friends/requests/{id}/accept", requestId)
                        .header("Authorization", bearer(stranger.accessToken)))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("FRIEND_REQUEST_NOT_FOUND"));
        mvc.perform(get("/api/v1/friends/requests/incoming").header("Authorization", bearer(stranger.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());

        mvc.perform(post("/api/v1/friends/requests/{id}/accept", requestId)
                        .header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/friends/requests/{id}/accept", requestId)
                        .header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("INVALID_FRIEND_REQUEST_STATE"));

        mvc.perform(get("/api/v1/friends").header("Authorization", bearer(sender.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].userId").value(recipient.userId.toString()))
                .andExpect(jsonPath("$[0].email").doesNotExist());
        mvc.perform(get("/api/v1/friends").header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].userId").value(sender.userId.toString()));
        assertThat(pairStatus(sender.userId, recipient.userId)).isEqualTo("ACCEPTED");
    }

    @Test
    void declineAllowsARepeatInvitationAndReusesTheSinglePairRow() throws Exception {
        Session sender = account("decline-sender");
        Session recipient = account("decline-recipient");
        UUID originalId = requestId(send(sender, recipient.friendCode).andReturn());

        mvc.perform(post("/api/v1/friends/requests/{id}/decline", originalId)
                        .header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/friends/requests/outgoing").header("Authorization", bearer(sender.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$").isEmpty());
        send(recipient, sender.friendCode).andExpect(status().isOk())
                .andExpect(jsonPath("$.requestId").value(originalId.toString()))
                .andExpect(jsonPath("$.status").value("PENDING"));
        assertThat(pairCount(sender.userId, recipient.userId)).isEqualTo(1);
        assertThat(pairStatus(sender.userId, recipient.userId)).isEqualTo("PENDING");
    }

    @Test
    void outgoingRequestCanOnlyBeCancelledByItsRequester() throws Exception {
        Session sender = account("cancel-sender");
        Session recipient = account("cancel-recipient");
        Session stranger = account("cancel-stranger");
        UUID requestId = requestId(send(sender, recipient.friendCode).andReturn());

        mvc.perform(delete("/api/v1/friends/requests/{id}", requestId)
                        .header("Authorization", bearer(recipient.accessToken)))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/friends/requests/{id}", requestId)
                        .header("Authorization", bearer(stranger.accessToken)))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/friends/requests/{id}", requestId)
                        .header("Authorization", bearer(sender.accessToken)))
                .andExpect(status().isNoContent());
        assertThat(pairCount(sender.userId, recipient.userId)).isZero();
    }

    @Test
    void onlyParticipantsCanRemoveAnAcceptedFriendship() throws Exception {
        Session first = account("remove-first");
        Session second = account("remove-second");
        Session outsider = account("remove-outsider");
        UUID id = requestId(send(first, second.friendCode).andReturn());
        mvc.perform(post("/api/v1/friends/requests/{id}/accept", id)
                        .header("Authorization", bearer(second.accessToken))).andExpect(status().isNoContent());

        mvc.perform(delete("/api/v1/friends/{id}", second.userId)
                        .header("Authorization", bearer(outsider.accessToken)))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/friends/{id}", first.userId)
                        .header("Authorization", bearer(first.accessToken)))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/v1/friends/{id}", second.userId)
                        .header("Authorization", bearer(first.accessToken)))
                .andExpect(status().isNoContent());
        assertThat(pairCount(first.userId, second.userId)).isZero();
    }

    @Test
    void simultaneousReciprocalRequestsCreateOneAutomaticallyAcceptedRelationship() throws Exception {
        Session first = account("race-first");
        Session second = account("race-second");
        CompletableFuture<Integer> firstRequest = CompletableFuture.supplyAsync(
                () -> requestStatus(first, second.friendCode));
        CompletableFuture<Integer> secondRequest = CompletableFuture.supplyAsync(
                () -> requestStatus(second, first.friendCode));

        assertThat(List.of(firstRequest.join(), secondRequest.join())).containsExactlyInAnyOrder(200, 201);
        assertThat(pairCount(first.userId, second.userId)).isEqualTo(1);
        assertThat(pairStatus(first.userId, second.userId)).isEqualTo("ACCEPTED");
        assertThat(friendCount(first)).isEqualTo(1);
        assertThat(friendCount(second)).isEqualTo(1);
    }

    private Session account(String label) throws Exception {
        String email = label + "-" + UUID.randomUUID() + "@example.test";
        mvc.perform(post("/api/v1/auth/register").contentType(APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"Correct Horse 42!\",\"displayName\":\"" + label + "\"}"))
                .andExpect(status().isCreated());
        String login = mvc.perform(post("/api/v1/auth/login").contentType(APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"Correct Horse 42!\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return new Session(UUID.fromString(JsonPath.read(login, "$.user.id")),
                JsonPath.read(login, "$.accessToken"), JsonPath.read(login, "$.user.friendCode"));
    }

    private org.springframework.test.web.servlet.ResultActions send(Session sender, String code) throws Exception {
        return mvc.perform(post("/api/v1/friends/requests").header("Authorization", bearer(sender.accessToken))
                .contentType(APPLICATION_JSON).content("{\"friendCode\":\"" + code + "\"}"));
    }

    private int requestStatus(Session sender, String code) {
        try { return send(sender, code).andReturn().getResponse().getStatus(); }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private int friendCount(Session session) {
        try {
            String json = mvc.perform(get("/api/v1/friends").header("Authorization", bearer(session.accessToken)))
                    .andReturn().getResponse().getContentAsString();
            return JsonPath.<List<?>>read(json, "$").size();
        } catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private long pairCount(UUID first, UUID second) {
        return jdbc.queryForObject("SELECT count(*) FROM friendship_request WHERE user_low_id = ? AND user_high_id = ?",
                Long.class, lower(first, second), higher(first, second));
    }

    private String pairStatus(UUID first, UUID second) {
        return jdbc.queryForObject("SELECT status FROM friendship_request WHERE user_low_id = ? AND user_high_id = ?",
                String.class, lower(first, second), higher(first, second));
    }

    private UUID requestId(MvcResult result) throws Exception {
        return UUID.fromString(JsonPath.read(result.getResponse().getContentAsString(), "$.requestId"));
    }

    private static String bearer(String token) { return "Bearer " + token; }
    private static UUID lower(UUID first, UUID second) {
        return first.toString().compareTo(second.toString()) < 0 ? first : second;
    }
    private static UUID higher(UUID first, UUID second) {
        return first.toString().compareTo(second.toString()) < 0 ? second : first;
    }

    private record Session(UUID userId, String accessToken, String friendCode) {}
}
