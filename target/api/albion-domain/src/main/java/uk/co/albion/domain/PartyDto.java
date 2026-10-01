package uk.co.albion.domain;

import java.time.LocalDate;

/**
 * Canonical party view. Replaces the party fields the SOAP service leaked
 * through {@code customerRef}. NINO is masked (DQR-021); dates are ISO-8601.
 */
public record PartyDto(
        PartyIdentifier identifier,
        String firstName,
        String lastName,
        LocalDate dateOfBirth,
        String email,
        String postcode,
        String ninoMasked) {
}
