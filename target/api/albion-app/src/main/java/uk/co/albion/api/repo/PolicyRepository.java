package uk.co.albion.api.repo;

import org.springframework.data.jpa.repository.JpaRepository;
import uk.co.albion.api.entity.PolicyEntity;

public interface PolicyRepository extends JpaRepository<PolicyEntity, String> {
}
