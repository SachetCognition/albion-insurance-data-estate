package uk.co.albion.api;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.oneOf;

import org.junit.jupiter.api.Test;

/** Contract tests for GET /policies/** (replaces get_policy_summary). */
class PolicyContractTest extends ApiContractTestBase {

    private static final String POLICY = "ALB-TRV-0000088";

    @Test
    void getPolicyReturnsTypedContract() {
        given().accept("application/json")
            .when().get("/policies/{no}", POLICY)
            .then()
                .statusCode(200)
                .body("policyNo", equalTo(POLICY))
                // typed party identifier — NOT an overloaded customerRef string
                .body("party.partyId", notNullValue())
                .body("party.sourceScheme", equalTo("POLARIS"))
                .body("customerRef", nullValue())
                // ISO-8601 dates, not DD/MM/YYYY text
                .body("inceptionDate", matchesPattern(ISO_DATE))
                .body("expiryDate", matchesPattern(ISO_DATE))
                // status domain (DQR-030)
                .body("policyStatus", is(oneOf("IF", "RN", "LP", "CN", "EX")));
    }

    @Test
    void policyNumberIsNormalisedOnce() {
        // Mainframe hyphen-stripped form ALBTRV0000088 resolves to the same
        // canonical policy via the shared PolicyNumberNormalizer.
        given().when().get("/policies/{no}", "ALBTRV0000088")
            .then().statusCode(200).body("policyNo", equalTo(POLICY));
    }

    @Test
    void getPolicySummaryExposesExplicitActiveFlags() {
        given().when().get("/policies/{no}/summary", POLICY)
            .then()
                .statusCode(200)
                .body("policyNo", equalTo(POLICY))
                .body("party.sourceScheme", equalTo("POLARIS"))
                .body("activePolicyFlag", notNullValue())
                .body("activeUw", notNullValue())
                .body("activeFinance", notNullValue())
                .body("activeClaims", notNullValue())
                .body("inceptionDate", matchesPattern(ISO_DATE));
    }

    @Test
    void unknownPolicyReturns404() {
        given().when().get("/policies/{no}", "ALB-XXX-9999999")
            .then().statusCode(404);
    }
}
