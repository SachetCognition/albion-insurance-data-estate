package com.albion.api.repository;
import com.albion.api.dto.PageResponse;
import com.albion.api.dto.PolicyDto;
import com.albion.api.dto.PolicyStatus;
import java.util.Optional;

public interface PolicyRepository {
  Optional<PolicyDto> findById(String id);

  PageResponse<PolicyDto> findAll(String partyId, PolicyStatus status, int page, int size);
}
