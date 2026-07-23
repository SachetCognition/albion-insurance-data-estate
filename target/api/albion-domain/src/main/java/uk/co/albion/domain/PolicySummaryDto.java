package uk.co.albion.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Reproduces the legacy {@code get_policy_summary} operation
 * ({@code pkg_policy_inquiry.sql}) as a clean, typed contract:
 *  - {@code party} is a structured {@link PartyIdentifier} (NOT the overloaded
 *    {@code customerRef} string);
 *  - {@code inceptionDate} is ISO-8601 (not DD/MM/YYYY text);
 *  - {@code activePolicyFlag} is the SINGLE canonical flag, with the labelled
 *    variants exposed separately so the four "active" definitions never conflate.
 */
public record PolicySummaryDto(
        String policyNo,
        PartyIdentifier party,
        String productCd,
        String policyStatus,
        boolean activePolicyFlag,
        boolean activeUw,
        boolean activeFinance,
        boolean activeClaims,
        BigDecimal annualPremiumGbp,
        LocalDate inceptionDate) {
}
