package com.socialworld;

import com.socialworld.auth.AuthProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.util.List;
import java.util.UUID;
import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.concurrent.CompletableFuture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import com.jayway.jsonpath.JsonPath;

@SpringBootTest
@AutoConfigureMockMvc
class AuthenticationIntegrationTest {
    private static final String TEST_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    private static final PostgreSQLContainer POSTGIS = new PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.5").asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("social_world_auth_test").withUsername("test_user").withPassword("test_password");

    static {
        POSTGIS.start();
        Runtime.getRuntime().addShutdownHook(new Thread(POSTGIS::stop, "stop-auth-test-postgis"));
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
    @Autowired AuthProperties authProperties;
    @Autowired JwtEncoder jwtEncoder;

    @Test
    void registersWithCanonicalEmailAndStoresOnlyPasswordHash() throws Exception {
        String email = "  MixedCase-" + id() + "@example.test  ";
        String password = "Correct Horse 42!";
        mvc.perform(registerRequest(email, password, "Sergey"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value(email.strip().toLowerCase()))
                .andExpect(jsonPath("$.displayName").value("Sergey"));

        String stored = jdbc.queryForObject("SELECT password_hash FROM app_user WHERE email = ?",
                String.class, email.strip().toLowerCase());
        assertThat(stored).isNotEqualTo(password).startsWith("$2");
    }

    @Test
    void rejectsDuplicateEmailRegardlessOfCaseAndWhitespace() throws Exception {
        String email = "duplicate-" + id() + "@example.test";
        mvc.perform(registerRequest(email, "Correct Horse 42!", "First")).andExpect(status().isCreated());
        mvc.perform(registerRequest("  " + email.toUpperCase() + " ", "Different Password 42!", "Second"))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("EMAIL_ALREADY_REGISTERED"));
    }

    @Test
    void rejectsMalformedRegistrationEmail() throws Exception {
        mvc.perform(registerRequest("not-an-email", "Correct Horse 42!", "Name"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void rejectsShortAndOverlongUtf8Passwords() throws Exception {
        mvc.perform(registerRequest("short-" + id() + "@example.test", "Short123!", "Name"))
                .andExpect(status().isBadRequest());
        mvc.perform(registerRequest("bytes-" + id() + "@example.test", "🙂".repeat(19), "Name"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void rejectsBlankOrOversizedDisplayName() throws Exception {
        mvc.perform(registerRequest("blank-" + id() + "@example.test", "Correct Horse 42!", "   "))
                .andExpect(status().isBadRequest());
        mvc.perform(registerRequest("long-" + id() + "@example.test", "Correct Horse 42!", "x".repeat(81)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void returnsGenericUnauthorizedForUnknownEmailAndWrongPassword() throws Exception {
        String unknown = performBody(loginRequest("missing-" + id() + "@example.test", "Wrong Password 123!"))
                .andExpect(status().isUnauthorized()).andReturn().getResponse().getContentAsString();
        String email = "wrong-password-" + id() + "@example.test";
        mvc.perform(registerRequest(email, "Correct Horse 42!", "Name")).andExpect(status().isCreated());
        String wrong = performBody(loginRequest(email, "Incorrect Password 123!"))
                .andExpect(status().isUnauthorized()).andReturn().getResponse().getContentAsString();
        assertThat(JsonPath.<String>read(unknown, "$.detail")).isEqualTo(JsonPath.read(wrong, "$.detail"));
        assertThat(JsonPath.<String>read(unknown, "$.code")).isEqualTo("INVALID_CREDENTIALS");
    }

    @Test
    void loginIssuesShortLivedJwtAndRefreshToken() throws Exception {
        String email = "login-" + id() + "@example.test";
        String password = "Correct Horse 42!";
        mvc.perform(registerRequest(email, password, "Login User")).andExpect(status().isCreated());
        String body = performBody(loginRequest(email, password)).andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(authProperties.getAccessTokenTtl().toSeconds()))
                .andExpect(jsonPath("$.user.email").value(email)).andReturn().getResponse().getContentAsString();
        assertThat(JsonPath.<String>read(body, "$.accessToken")).contains(".");
        String refresh = JsonPath.read(body, "$.refreshToken");
        assertThat(refresh).isNotBlank();
        assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_session", Integer.class)).isPositive();
    }

    @Test
    void invalidLoginEmailIsRejectedAsBadRequest() throws Exception {
        mvc.perform(loginRequest("bad-email", "Correct Horse 42!"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void refreshRotatesStoredTokenAndRejectsPreviousToken() throws Exception {
        Session session = createSession("rotate");
        String refreshed = performBody(post("/api/v1/auth/refresh").contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + session.refreshToken + "\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String replacement = JsonPath.read(refreshed, "$.refreshToken");
        assertThat(replacement).isNotEqualTo(session.refreshToken);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM refresh_session WHERE user_id = ? AND revoked_at IS NOT NULL",
                Integer.class, session.userId)).isEqualTo(1);
        mvc.perform(refreshRequest(session.refreshToken)).andExpect(status().isUnauthorized());
        mvc.perform(refreshRequest(replacement)).andExpect(status().isOk());
    }

    @Test
    void concurrentRefreshOfSameTokenSucceedsOnlyOnce() throws Exception {
        Session session = createSession("refresh-race");
        CompletableFuture<Integer> first = CompletableFuture.supplyAsync(() -> refreshStatus(session.refreshToken));
        CompletableFuture<Integer> second = CompletableFuture.supplyAsync(() -> refreshStatus(session.refreshToken));
        List<Integer> statuses = List.of(first.join(), second.join()).stream().sorted().toList();
        assertThat(statuses).containsExactly(200, 401);
    }

    @Test
    void rejectsUnknownRefreshToken() throws Exception {
        mvc.perform(refreshRequest("unknown-refresh-token"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void rejectsExpiredRefreshToken() throws Exception {
        Session session = createSession("expired-refresh");
        jdbc.update("""
                UPDATE refresh_session SET created_at = now() - interval '2 days',
                    expires_at = now() - interval '1 day'
                WHERE token_hash = ?
                """, hashToken(session.refreshToken));
        mvc.perform(refreshRequest(session.refreshToken)).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesRefreshTokenAndIsIdempotent() throws Exception {
        Session session = createSession("logout");
        mvc.perform(logoutRequest(session.accessToken, session.refreshToken)).andExpect(status().isNoContent());
        mvc.perform(refreshRequest(session.refreshToken)).andExpect(status().isUnauthorized());
        mvc.perform(logoutRequest(session.accessToken, session.refreshToken)).andExpect(status().isNoContent());
    }

    @Test
    void logoutCannotRevokeAnotherUsersSession() throws Exception {
        Session owner = createSession("owner");
        Session other = createSession("other");
        mvc.perform(logoutRequest(owner.accessToken, other.refreshToken)).andExpect(status().isNoContent());
        mvc.perform(refreshRequest(other.refreshToken)).andExpect(status().isOk());
    }

    @Test
    void profileAndLogoutRequireAuthentication() throws Exception {
        mvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/users/me").header("Authorization", bearer("not-a-jwt")))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/logout").contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"opaque\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void expiredAccessTokenCannotReadProfile() throws Exception {
        Instant now = Instant.now();
        String expired = jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(),
                JwtClaimsSet.builder().issuer(authProperties.getIssuer()).subject(UUID.randomUUID().toString())
                        .issuedAt(now.minusSeconds(120)).expiresAt(now.minusSeconds(60)).build())).getTokenValue();
        mvc.perform(get("/api/v1/users/me").header("Authorization", bearer(expired)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void readsOwnProfileFromVerifiedJwtSubject() throws Exception {
        Session session = createSession("profile");
        mvc.perform(get("/api/v1/users/me").header("Authorization", bearer(session.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(session.userId.toString()))
                .andExpect(jsonPath("$.email").value(session.email));
    }

    @Test
    void patchesOnlyOwnProfile() throws Exception {
        Session session = createSession("patch");
        mvc.perform(patch("/api/v1/users/me/profile").header("Authorization", bearer(session.accessToken))
                        .contentType(APPLICATION_JSON).content("{\"displayName\":\"Updated Name\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.displayName").value("Updated Name"));
        assertThat(jdbc.queryForObject("SELECT display_name FROM app_user WHERE id = ?", String.class, session.userId))
                .isEqualTo("Updated Name");
    }

    @Test
    void callerSuppliedUserIdCannotChangeAnotherProfile() throws Exception {
        Session first = createSession("first");
        Session second = createSession("second");
        mvc.perform(get("/api/v1/users/me").queryParam("userId", second.userId.toString())
                        .header("Authorization", bearer(first.accessToken)))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(first.userId.toString()));
        mvc.perform(patch("/api/v1/users/me/profile").header("Authorization", bearer(first.accessToken))
                        .contentType(APPLICATION_JSON).content("{\"displayName\":\"Alice Changed\",\"userId\":\"" +
                                second.userId + "\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.id").value(first.userId.toString()));
        assertThat(jdbc.queryForObject("SELECT display_name FROM app_user WHERE id = ?", String.class, second.userId))
                .isEqualTo("User second");
    }

    @Test
    void deletedAccountCannotUsePreviouslyIssuedAccessToken() throws Exception {
        Session session = createSession("deleted");
        jdbc.update("UPDATE app_user SET deleted_at = now() WHERE id = ?", session.userId);
        mvc.perform(get("/api/v1/users/me").header("Authorization", bearer(session.accessToken)))
                .andExpect(status().isUnauthorized());
        mvc.perform(refreshRequest(session.refreshToken)).andExpect(status().isUnauthorized());
    }

    @Test
    void concurrentRegistrationsKeepEmailUnique() throws Exception {
        String email = "race-" + id() + "@example.test";
        CompletableFuture<Integer> first = CompletableFuture.supplyAsync(() -> registrationStatus(email));
        CompletableFuture<Integer> second = CompletableFuture.supplyAsync(() -> registrationStatus(email));
        List<Integer> statuses = List.of(first.join(), second.join()).stream().sorted().toList();
        assertThat(statuses).containsExactly(201, 409);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM app_user WHERE lower(btrim(email)) = ?",
                Integer.class, email)).isEqualTo(1);
    }

    @Test
    void actuatorHealthIsPublicAndReportsDatabaseBackedUpStatus() throws Exception {
        mvc.perform(get("/actuator/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("UP"));
        assertThat(jdbc.queryForObject("SELECT 1", Integer.class)).isEqualTo(1);
    }

    private Session createSession(String label) throws Exception {
        String email = label + "-" + id() + "@example.test";
        mvc.perform(registerRequest(email, "Correct Horse 42!", "User " + label)).andExpect(status().isCreated());
        String body = performBody(loginRequest(email, "Correct Horse 42!"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        UUID userId = UUID.fromString(JsonPath.read(body, "$.user.id"));
        return new Session(userId, email, JsonPath.read(body, "$.accessToken"), JsonPath.read(body, "$.refreshToken"));
    }

    private int registrationStatus(String email) {
        try { return mvc.perform(registerRequest(email, "Correct Horse 42!", "Concurrent"))
                .andReturn().getResponse().getStatus(); }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private int refreshStatus(String refreshToken) {
        try { return mvc.perform(refreshRequest(refreshToken)).andReturn().getResponse().getStatus(); }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private static String hashToken(String token) {
        try { return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(token.getBytes(StandardCharsets.UTF_8))); }
        catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }

    private MockHttpServletRequestBuilder registerRequest(String email, String password, String displayName) {
        return post("/api/v1/auth/register").contentType(APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\",\"displayName\":\"" + displayName + "\"}");
    }

    private MockHttpServletRequestBuilder loginRequest(String email, String password) {
        return post("/api/v1/auth/login").contentType(APPLICATION_JSON)
                .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}");
    }

    private MockHttpServletRequestBuilder refreshRequest(String token) {
        return post("/api/v1/auth/refresh").contentType(APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + token + "\"}");
    }

    private MockHttpServletRequestBuilder logoutRequest(String accessToken, String refreshToken) {
        return post("/api/v1/auth/logout").header("Authorization", bearer(accessToken))
                .contentType(APPLICATION_JSON).content("{\"refreshToken\":\"" + refreshToken + "\"}");
    }

    private org.springframework.test.web.servlet.ResultActions performBody(MockHttpServletRequestBuilder request)
            throws Exception { return mvc.perform(request); }

    private static String bearer(String token) { return "Bearer " + token; }
    private static String id() { return UUID.randomUUID().toString().replace("-", ""); }
    private record Session(UUID userId, String email, String accessToken, String refreshToken) {}
}
