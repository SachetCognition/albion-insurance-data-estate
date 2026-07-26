package com.albion.api.dto;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

public record DataProductSummaryDto(
    LocalDate asOfDate,
    Integer activePolicyCount,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal totalEarnedPremiumGbp,
    Integer openClaimsCount,
    @JsonSerialize(using = MoneySerializer.class) BigDecimal totalIncurredGbp,
    @JsonSerialize(contentUsing = RateSerializer.class) Map<String, BigDecimal> dqPassRates) {}
