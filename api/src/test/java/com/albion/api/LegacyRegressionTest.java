package com.albion.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class LegacyRegressionTest extends MartBackedTest {
  @Autowired private MockMvc mvc;

  /** INC0067812: the UK DD/MM/YYYY loss date 09/05/2021 must surface as 9 May, not 5 September. */
  @Test
  void serialisesAmbiguousLossDateWithUkDayFirstReading() throws Exception {
    mvc.perform(get("/api/v1/claims/CLM00001188"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lossDate").value("2021-05-09"))
        .andExpect(jsonPath("$.notifiedDate").value("2021-05-11"));
  }

  /** Legacy fraud indicator 'S' resolves to exactly one contract value across every consumer. */
  @Test
  void serialisesLegacySuspectedFraudFlagConsistently() throws Exception {
    mvc.perform(get("/api/v1/claims/CLM00001187"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.fraudFlag").value("SUSPECTED"));
    mvc.perform(get("/api/v1/policies/ALB-PET-0000001/claims"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].fraudFlag").value("SUSPECTED"))
        .andExpect(jsonPath("$[1].fraudFlag").value("N"));
  }

  /** Money must never serialise as a JSON number. */
  @Test
  void serialisesMoneyAsDecimalStrings() throws Exception {
    mvc.perform(get("/api/v1/claims/CLM00001187"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.incurredGbp").value("78107.93"))
        .andExpect(jsonPath("$.paidGbp").value("5663.06"));
  }
}
