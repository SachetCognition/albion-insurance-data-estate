package com.albion.api.repository.fixture;
import com.albion.api.dto.PageResponse;
import com.albion.api.dto.PolicyDto;
import com.albion.api.dto.PolicyStatus;
import com.albion.api.repository.PolicyRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(
    name = "albion.datasource", havingValue = "fixtures", matchIfMissing = true)
public class FixturePolicyRepository extends FixtureRepositorySupport implements PolicyRepository {
  private static final int MAX_PAGE_SIZE = 100;
  private final List<PolicyDto> policies;

  public FixturePolicyRepository(
      ObjectMapper mapper,
      @Value("${albion.fixtures.path:contracts/fixtures}") String path) {
    super(mapper, path);
    policies = readList("policies.json", PolicyDto.class);
  }

  public Optional<PolicyDto> findById(String id) {
    return policies.stream().filter(policy -> policy.policyId().equals(id)).findFirst();
  }

  public PageResponse<PolicyDto> findAll(
      String partyId, PolicyStatus status, int page, int size) {
    page = Math.max(0, page);
    size = Math.min(Math.max(1, size), MAX_PAGE_SIZE);
    List<PolicyDto> filtered =
        policies.stream()
            .filter(policy -> partyId == null || partyId.equals(policy.partyId()))
            .filter(policy -> status == null || status == policy.status())
            .collect(Collectors.toList());
    long offset = (long) page * size;
    int from = offset >= filtered.size() ? filtered.size() : (int) offset;
    long end = Math.min(offset + size, (long) filtered.size());
    int to = (int) end;
    int pages = (int) Math.ceil(filtered.size() / (double) size);
    return new PageResponse<>(filtered.subList(from, to), page, size, filtered.size(), pages);
  }
}
