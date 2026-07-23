package uk.co.albion.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Full canonical policy view (GET /policies/{policyNo}). Dates are ISO-8601. */
public record PolicyDto(
        String policyNo,
        PartyIdentifier party,
        String productCd,
        String productName,
        String brokerId,
        String channel,
        LocalDate inceptionDate,
        LocalDate expiryDate,
        String policyStatus,
        boolean activePolicyFlag,
        boolean activeUw,
        boolean activeFinance,
        boolean activeClaims,
        BigDecimal annualPremiumGbp,
        BigDecimal iptRate,
        String paymentPlan,
        Integer uwYear,
        String sourceSystem) {
}
