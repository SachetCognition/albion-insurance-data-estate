package uk.co.albion.policyinquiry.web;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Contract tests for the shared Policy JSON contract (mirrors the policy_360
 * dbt mart columns) served from real mart export data.
 */
@SpringBootTest
@AutoConfigureMockMvc
class PolicyInquiryContractTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void policyEndpointServesFullSharedContract() throws Exception {
        mockMvc.perform(get("/api/v1/policies/ALB-PET-0000001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.policyNo").value("ALB-PET-0000001"))
                .andExpect(jsonPath("$.partyId").value("P0000936"))
                .andExpect(jsonPath("$.productCd").value("PET"))
                .andExpect(jsonPath("$.channel").value("DIRECT"))
                .andExpect(jsonPath("$.inceptionDt").value(matchesPattern("\\d{4}-\\d{2}-\\d{2}")))
                .andExpect(jsonPath("$.expiryDt").value(matchesPattern("\\d{4}-\\d{2}-\\d{2}")))
                .andExpect(jsonPath("$.policyStatus").value("IF"))
                .andExpect(jsonPath("$.activePolicyFlag").value("Y"))
                .andExpect(jsonPath("$.annualPremiumGbp").value(3100.09))
                .andExpect(jsonPath("$.earnedPremiumGbp", notNullValue()))
                .andExpect(jsonPath("$.postcode").value("CF10 1EP"))
                .andExpect(jsonPath("$.postcodeDqStatus").value("VALID"))
                .andExpect(jsonPath("$.emailDqStatus").value("VALID"))
                .andExpect(jsonPath("$.brokerName", notNullValue()));
    }

    @Test
    void identifiersAreSeparateFieldsNotALegacyCustomerRef() throws Exception {
        mockMvc.perform(get("/api/v1/policies/ALB-HOM-0000002"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.partyId").value("P0002309"))
                .andExpect(jsonPath("$.legacyCustomerId").value(321))
                .andExpect(jsonPath("$.customerRef").doesNotExist());
    }

    @Test
    void legacyCustomerIdIsNullWhenCrosswalkIsMissing() throws Exception {
        mockMvc.perform(get("/api/v1/policies/ALB-PET-0000001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.legacyCustomerId", nullValue()));
    }

    @Test
    void policyLookupIsCaseInsensitive() throws Exception {
        mockMvc.perform(get("/api/v1/policies/alb-pet-0000001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.policyNo").value("ALB-PET-0000001"));
    }

    @Test
    void unknownPolicyReturns404() throws Exception {
        mockMvc.perform(get("/api/v1/policies/ALB-XXX-9999999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void partyClaimsServeIsoDatesAndSingleIdentifier() throws Exception {
        mockMvc.perform(get("/api/v1/parties/P0001800/claims"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].claimNo", notNullValue()))
                .andExpect(jsonPath("$[0].partyId").value("P0001800"))
                .andExpect(jsonPath("$[*].lossDt", everyItem(matchesPattern("\\d{4}-\\d{2}-\\d{2}"))))
                .andExpect(jsonPath("$[0].claimStatus", notNullValue()));
    }

    @Test
    void partyWithNoClaimsReturnsEmptyList() throws Exception {
        mockMvc.perform(get("/api/v1/parties/P9999999/claims"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void openApiDocumentsBothEndpoints() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/v1/policies/{policyNo}']", notNullValue()))
                .andExpect(jsonPath("$.paths['/api/v1/parties/{partyId}/claims']", notNullValue()));
    }
}
