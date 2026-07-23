package uk.co.albion.api.web;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.co.albion.api.service.PolicyService;
import uk.co.albion.domain.PolicyDto;
import uk.co.albion.domain.PolicySummaryDto;

@RestController
@RequestMapping("/policies")
@Tag(name = "Policy", description = "Replaces SOAP PolicyInquiryService.getPolicySummary")
public class PolicyController {

    private final PolicyService service;

    public PolicyController(PolicyService service) {
        this.service = service;
    }

    @GetMapping("/{policyNo}")
    @Operation(summary = "Get full canonical policy by policy number (any format; normalised once).")
    public PolicyDto getPolicy(@PathVariable String policyNo) {
        return service.getPolicy(policyNo);
    }

    @GetMapping("/{policyNo}/summary")
    @Operation(summary = "Policy summary — the modern replacement for get_policy_summary.")
    public PolicySummaryDto getPolicySummary(@PathVariable String policyNo) {
        return service.getPolicySummary(policyNo);
    }
}
