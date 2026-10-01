package uk.co.albion.api.web;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import uk.co.albion.api.service.PartyService;
import uk.co.albion.domain.ClaimDto;
import uk.co.albion.domain.PartyDto;

@RestController
@RequestMapping("/parties")
@Tag(name = "Party", description = "Replaces SOAP PolicyInquiryService.getPartyClaims; typed identifiers")
public class PartyController {

    private final PartyService service;

    public PartyController(PartyService service) {
        this.service = service;
    }

    @GetMapping("/{partyId}")
    @Operation(summary = "Get a canonical party (typed identifier, masked NINO).")
    public PartyDto getParty(@PathVariable String partyId) {
        return service.getParty(partyId);
    }

    @GetMapping("/{partyId}/claims")
    @Operation(summary = "Party claims — the modern replacement for get_party_claims (ISO dates).")
    public List<ClaimDto> getPartyClaims(@PathVariable String partyId) {
        return service.getPartyClaims(partyId);
    }
}
