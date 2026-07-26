package com.albion.api.repository.fixture;
import com.albion.api.dto.ClaimDto;
import com.albion.api.repository.ClaimRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(
    name = "albion.datasource", havingValue = "fixtures", matchIfMissing = true)
public class FixtureClaimRepository extends FixtureRepositorySupport implements ClaimRepository {
  private final List<ClaimDto> claims;

  public FixtureClaimRepository(
      ObjectMapper mapper,
      @Value("${albion.fixtures.path:contracts/fixtures}") String path) {
    super(mapper, path);
    claims = readList("claims.json", ClaimDto.class);
  }

  public Optional<ClaimDto> findById(String id) {
    return claims.stream().filter(claim -> claim.claimId().equals(id)).findFirst();
  }

  public List<ClaimDto> findByPolicyId(String policyId) {
    return claims.stream().filter(claim -> claim.policyId().equals(policyId)).toList();
  }
}
