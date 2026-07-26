package com.albion.api.service;
import com.albion.api.dto.ClaimDto;
import com.albion.api.repository.ClaimRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ClaimService {
  private final ClaimRepository repository;

  public ClaimService(ClaimRepository repository) {
    this.repository = repository;
  }

  public ClaimDto get(String id) {
    return repository.findById(id).orElseThrow(() -> new ClaimNotFoundException(id));
  }

  public List<ClaimDto> byPolicy(String id) {
    return repository.findByPolicyId(id);
  }
}
