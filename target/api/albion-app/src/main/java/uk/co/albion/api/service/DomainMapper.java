package uk.co.albion.api.service;

import org.springframework.stereotype.Component;
import uk.co.albion.api.entity.ClaimEntity;
import uk.co.albion.api.entity.PartyEntity;
import uk.co.albion.api.entity.PolicyEntity;
import uk.co.albion.domain.ClaimDto;
import uk.co.albion.domain.IdentityScheme;
import uk.co.albion.domain.PartyDto;
import uk.co.albion.domain.PartyIdentifier;
import uk.co.albion.domain.PolicyDto;
import uk.co.albion.domain.PolicySummaryDto;

/** Maps canonical entities to the typed API DTOs. */
@Component
public class DomainMapper {

    public PartyIdentifier identifier(PartyEntity p) {
        return PartyIdentifier.polaris(p.getPartyId(), p.getLegacyClientNo(), p.getApfCustomerId());
    }

    private PartyIdentifier identifierFor(PartyEntity p, String fallbackPartyId) {
        if (p != null) {
            return identifier(p);
        }
        // claimant party not in store (e.g. third-party / life fuzzy) — still typed.
        return new PartyIdentifier(fallbackPartyId, IdentityScheme.POLARIS, null, null);
    }

    public PartyDto toPartyDto(PartyEntity p) {
        return new PartyDto(
                identifier(p),
                p.getFirstName(),
                p.getLastName(),
                p.getDateOfBirth(),
                p.getEmail(),
                p.getPostcode(),
                p.getNinoMasked());
    }

    public PolicySummaryDto toPolicySummary(PolicyEntity e, PartyEntity party) {
        return new PolicySummaryDto(
                e.getPolicyNo(),
                identifierFor(party, e.getPartyId()),
                e.getProductCd(),
                e.getPolicyStatus(),
                e.isActivePolicyFlag(),
                e.isActiveUw(),
                e.isActiveFinance(),
                e.isActiveClaims(),
                e.getAnnualPremiumGbp(),
                e.getInceptionDate());
    }

    public PolicyDto toPolicyDto(PolicyEntity e, PartyEntity party) {
        return new PolicyDto(
                e.getPolicyNo(),
                identifierFor(party, e.getPartyId()),
                e.getProductCd(),
                e.getProductName(),
                e.getBrokerId(),
                e.getChannel(),
                e.getInceptionDate(),
                e.getExpiryDate(),
                e.getPolicyStatus(),
                e.isActivePolicyFlag(),
                e.isActiveUw(),
                e.isActiveFinance(),
                e.isActiveClaims(),
                e.getAnnualPremiumGbp(),
                e.getIptRate(),
                e.getPaymentPlan(),
                e.getUwYear(),
                e.getSourceSystem());
    }

    public ClaimDto toClaimDto(ClaimEntity c, PartyEntity claimant) {
        return new ClaimDto(
                c.getClaimNo(),
                c.getPolicyNo(),
                identifierFor(claimant, c.getClaimantPartyId()),
                c.getLossDate(),
                c.getNotificationDate(),
                c.getCauseCd(),
                c.getClaimStatus(),
                c.getIncurredAmt(),
                c.getPaidAmt(),
                c.getOutstandingReserve(),
                c.getFraudFlag());
    }
}
