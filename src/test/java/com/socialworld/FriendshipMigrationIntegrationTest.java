package com.socialworld;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class FriendshipMigrationIntegrationTest {
    private static final PostgreSQLContainer POSTGIS = new PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.5").asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("social_world_v3_upgrade_test").withUsername("test_user").withPassword("test_password");

    static {
        POSTGIS.start();
        Runtime.getRuntime().addShutdownHook(new Thread(POSTGIS::stop, "stop-friends-migration-postgis"));
    }

    @Test
    void v3BackfillsFriendCodeWithoutChangingLegacyUserData() {
        DriverManagerDataSource dataSource = new DriverManagerDataSource(
                POSTGIS.getJdbcUrl(), POSTGIS.getUsername(), POSTGIS.getPassword());
        Flyway.configure().dataSource(dataSource).locations("classpath:db/migration")
                .target(MigrationVersion.fromVersion("2")).load().migrate();
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        UUID legacyId = UUID.randomUUID();
        jdbc.update("INSERT INTO app_user(id, email, display_name, password_hash) VALUES (?, ?, ?, ?)",
                legacyId, "legacy@example.test", "Legacy User", null);

        Flyway.configure().dataSource(dataSource).locations("classpath:db/migration").load().migrate();

        var legacy = jdbc.queryForMap("SELECT email, display_name, password_hash, friend_code FROM app_user WHERE id = ?", legacyId);
        assertThat(legacy.get("email")).isEqualTo("legacy@example.test");
        assertThat(legacy.get("display_name")).isEqualTo("Legacy User");
        assertThat(legacy.get("password_hash")).isNull();
        assertThat(legacy.get("friend_code").toString()).matches("SW-[A-Z0-9]{10}");
        assertThat(jdbc.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE version = '3' AND success", Integer.class))
                .isEqualTo(1);
    }
}
