package uk.co.albion.api;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.oneOf;

import org.junit.jupiter.api.Test;

/** Contract tests for GET /claims/{claimNo}. */
class ClaimContractTest extends ApiContractTestBase {

    @Test
    void getClaimReturnsCanonicalContract() {
        given().when().get("/claims/{no}", "CLM00000013")
            .then()
                .statusCode(200)
                .body("claimNo", equalTo("CLM00000013"))
                .body("policyNo", matchesPattern("^ALB-[A-Z]{3}-\\d+$"))
                .body("lossDate", matchesPattern(ISO_DATE))
                .body("notificationDate", matchesPattern(ISO_DATE))
                .body("fraudFlag", is(oneOf("Y", "N")))
                .body("claimStatus", is(oneOf("OPEN", "REOPENED", "CLOSED", "DECLINED")))
                .body("claimantParty.sourceScheme", equalTo("POLARIS"));
    }

    @Test
    void unknownClaimReturns404() {
        given().when().get("/claims/{no}", "CLM99999999")
            .then().statusCode(404);
    }
}
