package uk.co.albion.policyinquiry.web;

import java.util.List;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uk.co.albion.policyinquiry.model.Claim;
import uk.co.albion.policyinquiry.model.PolicySummary;
import uk.co.albion.policyinquiry.repository.PolicyRepository;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "Policy Inquiry", description = "REST replacement for the legacy SOAP PolicyInquiryService")
public class PolicyInquiryController {

    private final PolicyRepository repository;

    public PolicyInquiryController(PolicyRepository repository) {
        this.repository = repository;
    }

    @Operation(summary = "Get a policy summary by policy number",
            description = "Serves the shared Policy contract from the policy_360 mart. "
                    + "partyId and legacyCustomerId are separate fields.")
    @GetMapping("/policies/{policyNo}")
    public PolicySummary getPolicy(@PathVariable String policyNo) {
        return repository.findPolicyByPolicyNo(policyNo)
                .orElseThrow(() -> new PolicyNotFoundException(policyNo));
    }

    @Operation(summary = "List claims for a party",
            description = "Claims keyed by canonical partyId only; the legacy dual-key "
                    + "(partyId or legacy client number) lookup is not supported.")
    @GetMapping("/parties/{partyId}/claims")
    public List<Claim> getPartyClaims(@PathVariable String partyId) {
        return repository.findClaimsByPartyId(partyId);
    }
}
