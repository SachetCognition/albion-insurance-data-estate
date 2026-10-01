package com.albion.api.dto;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import java.math.BigDecimal;
import java.time.LocalDate;

public record PolicyDto(
    String policyId,
    String legacyPolicyNo,
    String partyId,
    String productCode,
    LocalDate inceptionDate,
    LocalDate expiryDate,
    PolicyStatus status,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal annualPremiumGbp,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal earnedPremiumGbp,
    String postcode,
    PostcodeDqStatus postcodeDqStatus,
    String brokerId,
    SourceSystem sourceSystem) {}
