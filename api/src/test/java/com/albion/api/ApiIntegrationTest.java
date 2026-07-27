package com.albion.api;

import static org.hamcrest.Matchers.isA;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class ApiIntegrationTest {
  @Autowired private MockMvc mvc;

  @Test
  void getsPolicyById() throws Exception {
    mvc.perform(get("/api/v1/policies/ALB-PET-0000001"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.policyId").value("ALB-PET-0000001"));
  }

  @Test
  void listsPoliciesWithDefaultPage() throws Exception {
    mvc.perform(get("/api/v1/policies"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.page").value(0))
        .andExpect(jsonPath("$.size").value(10))
        .andExpect(jsonPath("$.content.length()").value(10));
  }

  @Test
  void paginatesPolicies() throws Exception {
    mvc.perform(get("/api/v1/policies?page=1&size=5"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.page").value(1))
        .andExpect(jsonPath("$.size").value(5))
        .andExpect(jsonPath("$.totalElements").value(25))
        .andExpect(jsonPath("$.totalPages").value(5));
  }

  @Test
  void filtersPoliciesByPartyId() throws Exception {
    mvc.perform(get("/api/v1/policies?partyId=P0000936"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.totalElements").value(1))
        .andExpect(jsonPath("$.content[0].partyId").value("P0000936"));
  }

  @Test
  void filtersPoliciesByStatus() throws Exception {
    mvc.perform(get("/api/v1/policies?status=EXPIRED"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content[0].status").value("EXPIRED"));
  }

  @Test
  void rejectsInvalidStatusWithProblemJson() throws Exception {
    mvc.perform(get("/api/v1/policies?status=NOT_A_STATUS"))
        .andExpect(status().isBadRequest())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.status").value(400));
  }

  @Test
  void rejectsNegativePageWithProblemJson() throws Exception {
    mvc.perform(get("/api/v1/policies?page=-1"))
        .andExpect(status().isBadRequest())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.type").value("https://albion.example/problems/invalid-request"))
        .andExpect(jsonPath("$.title").value("Invalid request"))
        .andExpect(jsonPath("$.status").value(400))
        .andExpect(jsonPath("$.detail").value("Parameter 'page' must be greater than or equal to 0"))
        .andExpect(jsonPath("$.instance").value("/api/v1/policies"));
  }

  @Test
  void rejectsZeroSizeWithProblemJson() throws Exception {
    mvc.perform(get("/api/v1/policies?size=0"))
        .andExpect(status().isBadRequest())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.type").value("https://albion.example/problems/invalid-request"))
        .andExpect(jsonPath("$.title").value("Invalid request"))
        .andExpect(jsonPath("$.status").value(400))
        .andExpect(jsonPath("$.detail").value("Parameter 'size' must be greater than or equal to 1"))
        .andExpect(jsonPath("$.instance").value("/api/v1/policies"));
  }

  @Test
  void rejectsOverLimitSizeWithProblemJson() throws Exception {
    mvc.perform(get("/api/v1/policies?size=101"))
        .andExpect(status().isBadRequest())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.type").value("https://albion.example/problems/invalid-request"))
        .andExpect(jsonPath("$.title").value("Invalid request"))
        .andExpect(jsonPath("$.status").value(400))
        .andExpect(jsonPath("$.detail").value("Parameter 'size' must be less than or equal to 100"))
        .andExpect(jsonPath("$.instance").value("/api/v1/policies"));
  }

  @Test
  void getsPolicyClaims() throws Exception {
    mvc.perform(get("/api/v1/policies/ALB-PET-0000001/claims"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].claimId").value("CLM00001187"));
  }

  @Test
  void getsClaimById() throws Exception {
    mvc.perform(get("/api/v1/claims/CLM00001187"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lossDate").value("2023-07-01"))
        .andExpect(jsonPath("$.fraudFlag").value("SUSPECTED"));
  }

  @Test
  void getsSummaryIncludingDqRates() throws Exception {
    mvc.perform(get("/api/v1/data-products/summary"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.totalEarnedPremiumGbp").value("121068.77"))
        .andExpect(jsonPath("$.dqPassRates.DQR-014").value("0.8800"));
  }

  @Test
  void returnsPolicyNotFoundProblem() throws Exception {
    mvc.perform(get("/api/v1/policies/ALB-XXX-9999999"))
        .andExpect(status().isNotFound())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.type").value("https://albion.example/problems/policy-not-found"))
        .andExpect(jsonPath("$.title").value("Policy not found"))
        .andExpect(jsonPath("$.detail").value("No policy exists with id 'ALB-XXX-9999999'"))
        .andExpect(jsonPath("$.instance").value("/api/v1/policies/ALB-XXX-9999999"));
  }

  @Test
  void returnsClaimNotFoundProblem() throws Exception {
    mvc.perform(get("/api/v1/claims/CLM99999999"))
        .andExpect(status().isNotFound())
        .andExpect(content().contentTypeCompatibleWith("application/problem+json"))
        .andExpect(jsonPath("$.type").value("https://albion.example/problems/claim-not-found"))
        .andExpect(jsonPath("$.detail").value("No claim exists with id 'CLM99999999'"));
  }

  @Test
  void serializesMoneyAsString() throws Exception {
    mvc.perform(get("/api/v1/policies/ALB-PET-0000001"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.annualPremiumGbp", isA(String.class)))
        .andExpect(jsonPath("$.annualPremiumGbp").value("3100.09"));
  }
}
