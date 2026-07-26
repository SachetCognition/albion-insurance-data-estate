package com.albion.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "albion.fixtures.path=src/test/resources/legacy-fixtures")
class LegacyRegressionTest {
  @Autowired private MockMvc mvc;

  @Test
  void mapsUkDateAndSuspectedFlagInHttpResponse() throws Exception {
    mvc.perform(get("/api/v1/claims/LEGACY-1"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lossDate").value("2023-07-01"))
        .andExpect(jsonPath("$.fraudFlag").value("SUSPECTED"))
        .andExpect(jsonPath("$.incurredGbp").value("1.00"));
  }
}
