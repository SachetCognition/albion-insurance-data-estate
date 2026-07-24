package uk.co.albion.policyinquiry.model;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Claim contract — field set mirrors the party_claims dbt mart. Dates are
 * ISO-8601 (the legacy service returned lossDt as DD/MM/YYYY text).
 */
public record Claim(
        String claimNo,
        String policyNo,
        String partyId,
        LocalDate lossDt,
        LocalDate notificationDt,
        String causeCd,
        String claimStatus,
        BigDecimal incurredAmt,
        BigDecimal paidAmt,
        BigDecimal outstandingReserve) {
}
