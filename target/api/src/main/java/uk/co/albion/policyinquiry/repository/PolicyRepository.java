package uk.co.albion.policyinquiry.repository;

import java.util.List;
import java.util.Optional;

import uk.co.albion.policyinquiry.model.Claim;
import uk.co.albion.policyinquiry.model.PolicySummary;

public interface PolicyRepository {

    Optional<PolicySummary> findPolicyByPolicyNo(String policyNo);

    List<Claim> findClaimsByPartyId(String partyId);
}
