package com.albion.api.repository;
import com.albion.api.dto.ClaimDto;
import java.util.List;
import java.util.Optional;

public interface ClaimRepository {
  Optional<ClaimDto> findById(String id);

  List<ClaimDto> findByPolicyId(String policyId);
}
