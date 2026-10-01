package uk.co.albion.api.repo;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import uk.co.albion.api.entity.PartyEntity;

public interface PartyRepository extends JpaRepository<PartyEntity, String> {

    /** Resolve by the LEGACY_PAS client no crosswalk (the legacy service also accepted this). */
    Optional<PartyEntity> findByLegacyClientNo(Long legacyClientNo);
}
