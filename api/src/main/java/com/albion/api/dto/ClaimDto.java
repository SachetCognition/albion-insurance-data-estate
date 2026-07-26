package com.albion.api.dto;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import java.math.BigDecimal;
import java.time.LocalDate;

public record ClaimDto(
    String claimId,
    String policyId,
    LocalDate lossDate,
    LocalDate notifiedDate,
    ClaimStatus status,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal incurredGbp,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal paidGbp,
    FraudFlag fraudFlag) {}
