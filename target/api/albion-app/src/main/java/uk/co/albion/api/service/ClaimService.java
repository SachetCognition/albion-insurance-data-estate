package uk.co.albion.api.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.co.albion.api.entity.ClaimEntity;
import uk.co.albion.api.repo.ClaimRepository;
import uk.co.albion.api.repo.PartyRepository;
import uk.co.albion.api.web.ResourceNotFoundException;
import uk.co.albion.domain.ClaimDto;

@Service
@Transactional(readOnly = true)
public class ClaimService {

    private final ClaimRepository claims;
    private final PartyRepository parties;
    private final DomainMapper mapper;

    public ClaimService(ClaimRepository claims, PartyRepository parties, DomainMapper mapper) {
        this.claims = claims;
        this.parties = parties;
        this.mapper = mapper;
    }

    public ClaimDto getClaim(String claimNo) {
        ClaimEntity c = claims.findById(claimNo)
                .orElseThrow(() -> new ResourceNotFoundException("Claim not found: " + claimNo));
        var claimant = c.getClaimantPartyId() == null ? null
                : parties.findById(c.getClaimantPartyId()).orElse(null);
        return mapper.toClaimDto(c, claimant);
    }
}
