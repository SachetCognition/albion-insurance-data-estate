package uk.co.albion.api;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

/**
 * Provider contract tests run against the live Spring Boot app on a random port,
 * backed by the H2 store seeded from the CSV samples (no Snowflake required).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
abstract class ApiContractTestBase {

    static final String ISO_DATE = "^\\d{4}-\\d{2}-\\d{2}$";
    static final String DDMMYYYY = "^\\d{2}/\\d{2}/\\d{4}$";

    @LocalServerPort
    int port;

    @BeforeEach
    void setUp() {
        RestAssured.port = port;
        RestAssured.basePath = "/";
    }
}
