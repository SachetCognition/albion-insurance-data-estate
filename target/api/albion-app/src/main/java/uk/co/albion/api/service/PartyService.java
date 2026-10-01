package uk.co.albion.api.service;

import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.co.albion.api.entity.PartyEntity;
import uk.co.albion.api.repo.ClaimRepository;
import uk.co.albion.api.repo.PartyRepository;
import uk.co.albion.api.web.ResourceNotFoundException;
import uk.co.albion.domain.ClaimDto;
import uk.co.albion.domain.PartyDto;

@Service
@Transactional(readOnly = true)
public class PartyService {

    private final PartyRepository parties;
    private final ClaimRepository claims;
    private final DomainMapper mapper;

    public PartyService(PartyRepository parties, ClaimRepository claims, DomainMapper mapper) {
        this.parties = parties;
        this.claims = claims;
        this.mapper = mapper;
    }

    private PartyEntity require(String partyRef) {
        // Accept either the canonical POLARIS party id or a legacy client no
        // (the legacy get_party_claims accepted either key), but resolve to the
        // single canonical party — never conflating the two schemes.
        if (partyRef != null) {
            var byId = parties.findById(partyRef);
            if (byId.isPresent()) {
                return byId.get();
            }
            if (partyRef.matches("\\d+")) {
                var byLegacy = parties.findByLegacyClientNo(Long.parseLong(partyRef));
                if (byLegacy.isPresent()) {
                    return byLegacy.get();
                }
            }
        }
        throw new ResourceNotFoundException("Party not found: " + partyRef);
    }

    public PartyDto getParty(String partyRef) {
        return mapper.toPartyDto(require(partyRef));
    }

    public List<ClaimDto> getPartyClaims(String partyRef) {
        PartyEntity party = require(partyRef);
        return claims.findByClaimantPartyIdOrderByLossDateDesc(party.getPartyId()).stream()
                .map(c -> mapper.toClaimDto(c, party))
                .toList();
    }
}
