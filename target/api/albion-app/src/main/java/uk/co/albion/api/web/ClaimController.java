package uk.co.albion.api.web;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.co.albion.api.service.ClaimService;
import uk.co.albion.domain.ClaimDto;

@RestController
@RequestMapping("/claims")
@Tag(name = "Claim")
public class ClaimController {

    private final ClaimService service;

    public ClaimController(ClaimService service) {
        this.service = service;
    }

    @GetMapping("/{claimNo}")
    @Operation(summary = "Get a canonical claim by claim number (ISO dates, canonical fraud flag).")
    public ClaimDto getClaim(@PathVariable String claimNo) {
        return service.getClaim(claimNo);
    }
}
