package uk.co.albion.api;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.oneOf;

import org.junit.jupiter.api.Test;

/** Contract tests for GET /parties/** (replaces get_party_claims). */
class PartyContractTest extends ApiContractTestBase {

    @Test
    void getPartyReturnsTypedIdentifierAndMaskedNino() {
        given().when().get("/parties/{id}", "P0000003")
            .then()
                .statusCode(200)
                .body("identifier.partyId", equalTo("P0000003"))
                .body("identifier.sourceScheme", equalTo("POLARIS"))
                // legacy identifiers are SEPARATE typed fields, not merged into one
                .body("identifier.apfCustomerId", notNullValue())
                // NINO masked (DQR-021) — never the raw NN999999N shape
                .body("ninoMasked", matchesPattern("^.{2}\\*{5}.{2}$"))
                .body("ninoMasked", not(matchesPattern("^[A-Z]{2}\\d{6}[A-Z]$")))
                .body("dateOfBirth", matchesPattern(ISO_DATE));
    }

    @Test
    void getPartyClaimsReturnsIsoDatesAndCanonicalDomains() {
        given().when().get("/parties/{id}/claims", "P0001488")
            .then()
                .statusCode(200)
                .body("lossDate", everyItem(matchesPattern(ISO_DATE)))
                .body("fraudFlag", everyItem(is(oneOf("Y", "N"))))
                .body("claimStatus", everyItem(is(oneOf("OPEN", "REOPENED", "CLOSED", "DECLINED"))))
                .body("claimantParty.sourceScheme", everyItem(equalTo("POLARIS")));
    }

    @Test
    void unknownPartyReturns404() {
        given().when().get("/parties/{id}", "P9999999")
            .then().statusCode(404);
    }
}
