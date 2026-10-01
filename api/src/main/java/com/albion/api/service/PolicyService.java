package com.albion.api.service;
import com.albion.api.dto.PageResponse;
import com.albion.api.dto.PolicyDto;
import com.albion.api.dto.PolicyStatus;
import com.albion.api.repository.PolicyRepository;
import org.springframework.stereotype.Service;

@Service
public class PolicyService {
  private final PolicyRepository repository;

  public PolicyService(PolicyRepository repository) {
    this.repository = repository;
  }

  public PolicyDto get(String id) {
    return repository.findById(id).orElseThrow(() -> new PolicyNotFoundException(id));
  }

  public PageResponse<PolicyDto> find(String partyId, PolicyStatus status, int page, int size) {
    return repository.findAll(partyId, status, page, size);
  }
}
