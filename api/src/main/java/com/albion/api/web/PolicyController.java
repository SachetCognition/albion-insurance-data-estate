package com.albion.api.web;
import com.albion.api.dto.ClaimDto;
import com.albion.api.dto.PageResponse;
import com.albion.api.dto.PolicyDto;
import com.albion.api.dto.PolicyStatus;
import com.albion.api.service.ClaimService;
import com.albion.api.service.PolicyService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/policies")
public class PolicyController {
  private final PolicyService policies;
  private final ClaimService claims;

  public PolicyController(PolicyService policies, ClaimService claims) {
    this.policies = policies;
    this.claims = claims;
  }

  @GetMapping("/{policyId}")
  public PolicyDto get(@PathVariable String policyId) {
    return policies.get(policyId);
  }

  @GetMapping
  public PageResponse<PolicyDto> list(
      @RequestParam(required = false) String partyId,
      @RequestParam(required = false) PolicyStatus status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "10") int size) {
    return policies.find(partyId, status, page, size);
  }

  @GetMapping("/{policyId}/claims")
  public List<ClaimDto> claims(@PathVariable String policyId) {
    policies.get(policyId);
    return claims.byPolicy(policyId);
  }
}
