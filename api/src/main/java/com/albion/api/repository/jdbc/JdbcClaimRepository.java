package com.albion.api.repository.jdbc;

import com.albion.api.dto.ClaimDto;
import com.albion.api.dto.ClaimStatus;
import com.albion.api.dto.FraudFlag;
import com.albion.api.repository.ClaimRepository;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcClaimRepository implements ClaimRepository {
  private static final String COLUMNS =
      "claim_id, policy_id, loss_date, notified_date, status, incurred_gbp, paid_gbp, fraud_flag";

  private final JdbcTemplate jdbc;

  public JdbcClaimRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  @Override
  public Optional<ClaimDto> findById(String id) {
    return jdbc.query("SELECT " + COLUMNS + " FROM claims_summary WHERE claim_id = ?", MAPPER, id)
        .stream()
        .findFirst();
  }

  @Override
  public List<ClaimDto> findByPolicyId(String policyId) {
    return jdbc.query(
        "SELECT " + COLUMNS + " FROM claims_summary WHERE policy_id = ? ORDER BY claim_id",
        MAPPER,
        policyId);
  }

  private static final RowMapper<ClaimDto> MAPPER =
      (ResultSet rs, int row) ->
          new ClaimDto(
              rs.getString("claim_id"),
              rs.getString("policy_id"),
              date(rs, "loss_date"),
              date(rs, "notified_date"),
              ClaimStatus.valueOf(rs.getString("status")),
              rs.getBigDecimal("incurred_gbp"),
              rs.getBigDecimal("paid_gbp"),
              FraudFlag.valueOf(rs.getString("fraud_flag")));

  private static LocalDate date(ResultSet rs, String column) throws SQLException {
    Date value = rs.getDate(column);
    return value == null ? null : value.toLocalDate();
  }
}
