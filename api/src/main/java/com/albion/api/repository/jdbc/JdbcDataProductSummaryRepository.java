package com.albion.api.repository.jdbc;

import com.albion.api.dto.DataProductSummaryDto;
import com.albion.api.repository.DataProductSummaryRepository;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcDataProductSummaryRepository implements DataProductSummaryRepository {
  private final JdbcTemplate jdbc;

  public JdbcDataProductSummaryRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  @Override
  public DataProductSummaryDto find() {
    Map<String, java.math.BigDecimal> passRates = new LinkedHashMap<>();
    jdbc.query(
        "SELECT rule_id, pass_rate FROM dq_pass_rates ORDER BY rule_id",
        rs -> {
          passRates.put(rs.getString("rule_id"), rs.getBigDecimal("pass_rate"));
        });
    return jdbc.queryForObject(
        "SELECT as_of_date, active_policy_count, total_earned_premium_gbp, open_claims_count,"
            + " total_incurred_gbp FROM data_product_summary",
        (rs, row) ->
            new DataProductSummaryDto(
                rs.getDate("as_of_date").toLocalDate(),
                rs.getInt("active_policy_count"),
                rs.getBigDecimal("total_earned_premium_gbp"),
                rs.getInt("open_claims_count"),
                rs.getBigDecimal("total_incurred_gbp"),
                passRates));
  }
}
