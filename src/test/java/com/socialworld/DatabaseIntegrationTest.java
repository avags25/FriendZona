package com.socialworld;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import org.flywaydb.core.Flyway;

import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class DatabaseIntegrationTest {

    private static final DockerImageName POSTGIS_IMAGE = DockerImageName
            .parse("postgis/postgis:16-3.5")
            .asCompatibleSubstituteFor("postgres");

    private static final PostgreSQLContainer POSTGIS = new PostgreSQLContainer(POSTGIS_IMAGE)
            .withDatabaseName("social_world_test")
            .withUsername("test_user")
            .withPassword("test_password");

    static {
        POSTGIS.start();
        Runtime.getRuntime().addShutdownHook(new Thread(POSTGIS::stop, "stop-test-postgis"));
    }

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGIS::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGIS::getUsername);
        registry.add("spring.datasource.password", POSTGIS::getPassword);
        registry.add("social-world.auth.jwt-secret", () -> "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=");
    }

    @Autowired
    private org.springframework.context.ApplicationContext applicationContext;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private Flyway flyway;

    @Autowired
    private MockMvc mockMvc;

    @Test
    void startsSpringApplicationContext() {
        assertThat(applicationContext).isNotNull();
        assertThat(POSTGIS.isRunning()).isTrue();
    }

    @Test
    void appliesV1OnceAndSubsequentMigrationCheckIsIdempotent() {
        Integer successfulV1Rows = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM flyway_schema_history
                WHERE version = '1' AND description = 'initial schema' AND success = true
                """, Integer.class);
        assertThat(successfulV1Rows).isEqualTo(1);
        assertThat(flyway.info().pending()).isEmpty();
        Integer successfulV2Rows = jdbcTemplate.queryForObject("""
                SELECT count(*) FROM flyway_schema_history
                WHERE version = '2' AND description = 'authentication sessions' AND success = true
                """, Integer.class);
        assertThat(successfulV2Rows).isEqualTo(1);

        flyway.migrate();

        Integer successfulV1RowsAfterRepeat = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM flyway_schema_history
                WHERE version = '1' AND description = 'initial schema' AND success = true
                """, Integer.class);
        Integer failedRows = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE success = false", Integer.class);
        Integer successfulV2RowsAfterRepeat = jdbcTemplate.queryForObject("""
                SELECT count(*) FROM flyway_schema_history
                WHERE version = '2' AND description = 'authentication sessions' AND success = true
                """, Integer.class);
        assertThat(successfulV1RowsAfterRepeat).isEqualTo(1);
        assertThat(successfulV2RowsAfterRepeat).isEqualTo(1);
        assertThat(failedRows).isZero();
    }

    @Test
    void createsRequiredTablesAndConstraints() {
        Set<String> tables = jdbcTemplate.queryForList("""
                        SELECT table_name FROM information_schema.tables
                        WHERE table_schema = current_schema()
                        """, String.class)
                .stream().collect(Collectors.toSet());
        assertThat(tables).contains("app_user", "meeting", "meeting_participant", "refresh_session", "friendship_request");

        assertConstraintDefinition("app_user", "app_user_pkey", "PRIMARY KEY (id)");
        assertConstraintDefinition("app_user", "app_user_email_key", "UNIQUE (email)");
        assertConstraintDefinition("meeting", "meeting_pkey", "PRIMARY KEY (id)");
        assertConstraintDefinition("meeting", "meeting_organizer_id_fkey",
                "FOREIGN KEY (organizer_id) REFERENCES app_user(id)");
        assertThat(constraintDefinition("meeting", "meeting_status_check"))
                .contains("SCHEDULED", "CANCELLED", "COMPLETED");
        assertConstraintDefinition("meeting_participant", "meeting_participant_pkey",
                "PRIMARY KEY (meeting_id, user_id)");
        assertConstraintDefinition("meeting_participant", "meeting_participant_meeting_id_fkey",
                "FOREIGN KEY (meeting_id) REFERENCES meeting(id) ON DELETE CASCADE");
        assertConstraintDefinition("meeting_participant", "meeting_participant_user_id_fkey",
                "FOREIGN KEY (user_id) REFERENCES app_user(id)");
        assertThat(constraintDefinition("meeting_participant", "meeting_participant_response_check"))
                .contains("INVITED", "GOING", "MAYBE", "DECLINED", "ON_THE_WAY", "ARRIVED", "LATE");
        assertConstraintDefinition("refresh_session", "refresh_session_user_id_fkey",
                "FOREIGN KEY (user_id) REFERENCES app_user(id) ON DELETE CASCADE");
        assertConstraintDefinition("refresh_session", "refresh_session_pkey", "PRIMARY KEY (id)");
        assertConstraintDefinition("refresh_session", "refresh_session_token_hash_key", "UNIQUE (token_hash)");
        assertThat(jdbcTemplate.queryForObject("""
                SELECT count(*) FROM pg_indexes
                WHERE schemaname = current_schema() AND indexname = 'app_user_email_normalized_uidx'
                  AND indexdef ILIKE '%UNIQUE%' AND indexdef ILIKE '%lower%'
                  AND indexdef ILIKE '%btrim%' AND indexdef ILIKE '%email%'
                """, Integer.class)).isEqualTo(1);

        assertConstraintDefinition("app_user", "app_user_friend_code_key", "UNIQUE (friend_code)");
        assertThat(constraintDefinition("app_user", "app_user_friend_code_format_check"))
                .contains("SW-", "10");
        assertConstraintDefinition("friendship_request", "friendship_request_pair_key",
                "UNIQUE (user_low_id, user_high_id)");
        assertThat(constraintDefinition("friendship_request", "friendship_request_status_check"))
                .contains("PENDING", "ACCEPTED", "DECLINED");
        assertThat(constraintDefinition("friendship_request", "friendship_request_pair_order_check"))
                .contains("user_low_id < user_high_id");
    }

    @Test
    void enablesPostgisGeographyAndSpatialIndex() {
        String postgisVersion = jdbcTemplate.queryForObject("SELECT PostGIS_Full_Version()", String.class);
        assertThat(postgisVersion).contains("POSTGIS=");

        String columnType = jdbcTemplate.queryForObject("""
                SELECT udt_name FROM information_schema.columns
                WHERE table_schema = current_schema() AND table_name = 'meeting' AND column_name = 'location'
                """, String.class);
        assertThat(columnType).isEqualTo("geography");

        var geographyColumn = jdbcTemplate.queryForMap("""
                SELECT type, srid, coord_dimension FROM geography_columns
                WHERE f_table_schema = current_schema() AND f_table_name = 'meeting' AND f_geography_column = 'location'
                """);
        assertThat(geographyColumn.get("type")).isEqualTo("Point");
        assertThat(((Number) geographyColumn.get("srid")).intValue()).isEqualTo(4326);

        String spatialIndexMethod = jdbcTemplate.queryForObject("""
                SELECT am.amname
                FROM pg_index i
                JOIN pg_class idx ON idx.oid = i.indexrelid
                JOIN pg_am am ON am.oid = idx.relam
                WHERE idx.relname = 'meeting_location_gix'
                """, String.class);
        assertThat(spatialIndexMethod).isEqualTo("gist");
    }

    @Test
    void actuatorHealthReportsUp() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("UP")));
    }

    private void assertConstraintDefinition(String tableName, String constraintName, String expectedDefinition) {
        assertThat(constraintDefinition(tableName, constraintName))
                .as("definition of constraint %s on table %s", constraintName, tableName)
                .contains(expectedDefinition);
    }

    private String constraintDefinition(String tableName, String constraintName) {
        return jdbcTemplate.queryForObject("""
                SELECT pg_get_constraintdef(oid) FROM pg_constraint
                WHERE conrelid = to_regclass(?) AND conname = ?
                """, String.class, tableName, constraintName);
    }
}
