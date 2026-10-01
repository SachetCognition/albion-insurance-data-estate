package com.albion.api.web;
import com.albion.api.dto.ClaimDto;
import com.albion.api.service.ClaimService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/claims")
public class ClaimController {
  private final ClaimService claims;

  public ClaimController(ClaimService claims) {
    this.claims = claims;
  }

  @GetMapping("/{claimId}")
  public ClaimDto get(@PathVariable String claimId) {
    return claims.get(claimId);
  }
}
