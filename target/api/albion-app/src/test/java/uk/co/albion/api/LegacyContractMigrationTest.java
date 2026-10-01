package uk.co.albion.api;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;

import io.restassured.response.Response;
import org.junit.jupiter.api.Test;

/**
 * Documents & enforces the migration from the frozen rpc/encoded SOAP contract
 * (api_legacy/soap/PolicyInquiryService.wsdl + pkg_policy_inquiry.sql) to the
 * new typed REST contract.
 *
 * Legacy PolicySummary (SOAP/XSD) exposed a single overloaded string:
 *     <customerRef>...</customerRef>   -- = NVL(legacy_customer_id, party_id)
 * mixing two identifier schemes, plus dates as DD/MM/YYYY text. This test asserts
 * the new contract no longer does either.
 */
class LegacyContractMigrationTest extends ApiContractTestBase {

    @Test
    void typedPartyIdentifierReplacesOverloadedCustomerRef() {
        Response r = given().when().get("/policies/{no}/summary", "ALB-TRV-0000088").andReturn();
        r.then().statusCode(200)
                // the overloaded legacy field is gone...
                .body("customerRef", nullValue())
                .body("customer_ref", nullValue())
                // ...replaced by an explicit, typed identifier
                .body("party.partyId", notNullValue())
                .body("party.sourceScheme", notNullValue());
    }

    @Test
    void datesAreIsoNotLegacyDdMmYyyyText() {
        given().when().get("/policies/{no}/summary", "ALB-TRV-0000088")
            .then().statusCode(200)
                .body("inceptionDate", matchesPattern(ISO_DATE))
                .body("inceptionDate", not(matchesPattern(DDMMYYYY)));
    }

    @Test
    void openApiSpecIsPublished() {
        // The typed contract is discoverable (replacing the frozen WSDL).
        given().when().get("/v3/api-docs")
            .then().statusCode(200)
                .body("openapi", matchesPattern("^3\\..*"));
    }
}
