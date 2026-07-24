package uk.co.albion.policyinquiry.model;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Shared Policy contract — field set mirrors the policy_360 dbt mart
 * (target/dbt/models/marts/policy_360.sql).
 *
 * partyId and legacyCustomerId are deliberately separate fields; the legacy
 * SOAP service collapsed both identifier schemes into one customerRef field.
 */
public record PolicySummary(
        String policyNo,
        String partyId,
        Long legacyCustomerId,
        String productCd,
        String channel,
        LocalDate inceptionDt,
        LocalDate expiryDt,
        String policyStatus,
        String activePolicyFlag,
        BigDecimal annualPremiumGbp,
        BigDecimal earnedPremiumGbp,
        String postcode,
        String postcodeDqStatus,
        String emailDqStatus,
        String brokerName) {
}
