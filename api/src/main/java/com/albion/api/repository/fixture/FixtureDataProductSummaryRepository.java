package com.albion.api.repository.fixture;
import com.albion.api.dto.DataProductSummaryDto;
import com.albion.api.repository.DataProductSummaryRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(
    name = "albion.datasource", havingValue = "fixtures", matchIfMissing = true)
public class FixtureDataProductSummaryRepository extends FixtureRepositorySupport implements DataProductSummaryRepository {
  private final DataProductSummaryDto summary;

  public FixtureDataProductSummaryRepository(
      ObjectMapper mapper,
      @Value("${albion.fixtures.path:contracts/fixtures}") String path) {
    super(mapper, path);
    summary = mapper.convertValue(read("data_products_summary.json"), DataProductSummaryDto.class);
  }

  public DataProductSummaryDto find() {
    return summary;
  }
}
