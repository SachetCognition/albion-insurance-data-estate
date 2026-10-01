package uk.co.albion.api.repo;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import uk.co.albion.api.entity.ClaimEntity;

public interface ClaimRepository extends JpaRepository<ClaimEntity, String> {

    List<ClaimEntity> findByClaimantPartyIdOrderByLossDateDesc(String claimantPartyId);
}
