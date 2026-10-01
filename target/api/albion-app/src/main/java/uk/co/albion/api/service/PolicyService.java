package uk.co.albion.api.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.co.albion.api.entity.PartyEntity;
import uk.co.albion.api.entity.PolicyEntity;
import uk.co.albion.api.repo.PolicyRepository;
import uk.co.albion.api.repo.PartyRepository;
import uk.co.albion.api.web.ResourceNotFoundException;
import uk.co.albion.domain.PolicyDto;
import uk.co.albion.domain.PolicyNumberNormalizer;
import uk.co.albion.domain.PolicySummaryDto;

@Service
@Transactional(readOnly = true)
public class PolicyService {

    private final PolicyRepository policies;
    private final PartyRepository parties;
    private final DomainMapper mapper;
    private final PolicyNumberNormalizer normalizer;

    public PolicyService(PolicyRepository policies, PartyRepository parties,
                         DomainMapper mapper, PolicyNumberNormalizer normalizer) {
        this.policies = policies;
        this.parties = parties;
        this.mapper = mapper;
        this.normalizer = normalizer;
    }

    private PolicyEntity require(String policyNo) {
        // Policy-number normalisation happens ONCE, here, via the shared component.
        String canonical = normalizer.normalise(policyNo);
        return policies.findById(canonical)
                .orElseThrow(() -> new ResourceNotFoundException("Policy not found: " + policyNo));
    }

    private PartyEntity party(PolicyEntity p) {
        return p.getPartyId() == null ? null : parties.findById(p.getPartyId()).orElse(null);
    }

    public PolicyDto getPolicy(String policyNo) {
        PolicyEntity p = require(policyNo);
        return mapper.toPolicyDto(p, party(p));
    }

    public PolicySummaryDto getPolicySummary(String policyNo) {
        PolicyEntity p = require(policyNo);
        return mapper.toPolicySummary(p, party(p));
    }
}
