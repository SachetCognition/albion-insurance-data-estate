package uk.co.albion.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Canonical claim view. Reproduces the rows returned by the legacy
 * {@code get_party_claims} operation, but with ISO-8601 dates (the PL/SQL
 * returned {@code loss_dt} as DD/MM/YYYY text) and the single canonical
 * fraud-flag mapping.
 */
public record ClaimDto(
        String claimNo,
        String policyNo,
        PartyIdentifier claimantParty,
        LocalDate lossDate,
        LocalDate notificationDate,
        String causeCd,
        String claimStatus,
        BigDecimal incurredAmt,
        BigDecimal paidAmt,
        BigDecimal outstandingReserve,
        String fraudFlag) {
}
