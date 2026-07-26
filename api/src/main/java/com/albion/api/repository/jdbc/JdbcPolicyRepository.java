package com.albion.api.repository.jdbc;

import com.albion.api.dto.PageResponse;
import com.albion.api.dto.PolicyDto;
import com.albion.api.dto.PolicyStatus;
import com.albion.api.dto.PostcodeDqStatus;
import com.albion.api.repository.PolicyRepository;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcPolicyRepository implements PolicyRepository {
  private static final String COLUMNS =
      "policy_id, legacy_policy_no, party_id, product_code, inception_date, expiry_date, status,"
          + " annual_premium_gbp, earned_premium_gbp, postcode, postcode_dq_status, broker_id,"
          + " source_system";

  private final JdbcTemplate jdbc;

  public JdbcPolicyRepository(JdbcTemplate jdbc) {
    this.jdbc = jdbc;
  }

  @Override
  public Optional<PolicyDto> findById(String id) {
    return jdbc.query(
            "SELECT " + COLUMNS + " FROM policy_360 WHERE policy_id = ?", MAPPER, id)
        .stream()
        .findFirst();
  }

  @Override
  public PageResponse<PolicyDto> findAll(String partyId, PolicyStatus status, int page, int size) {
    StringBuilder where = new StringBuilder(" WHERE 1 = 1");
    List<Object> arguments = new ArrayList<>();
    if (partyId != null) {
      where.append(" AND party_id = ?");
      arguments.add(partyId);
    }
    if (status != null) {
      where.append(" AND status = ?");
      arguments.add(status.name());
    }
    Long total =
        jdbc.queryForObject(
            "SELECT count(*) FROM policy_360" + where, Long.class, arguments.toArray());
    long totalElements = total == null ? 0L : total;
    List<Object> pageArguments = new ArrayList<>(arguments);
    pageArguments.add(size);
    pageArguments.add((long) page * size);
    List<PolicyDto> content =
        jdbc.query(
            "SELECT " + COLUMNS + " FROM policy_360" + where + " ORDER BY policy_id LIMIT ? OFFSET ?",
            MAPPER,
            pageArguments.toArray());
    int totalPages = size <= 0 ? 0 : (int) Math.ceil(totalElements / (double) size);
    return new PageResponse<>(content, page, size, totalElements, totalPages);
  }

  private static final RowMapper<PolicyDto> MAPPER =
      (ResultSet rs, int row) ->
          new PolicyDto(
              rs.getString("policy_id"),
              rs.getString("legacy_policy_no"),
              rs.getString("party_id"),
              rs.getString("product_code"),
              date(rs, "inception_date"),
              date(rs, "expiry_date"),
              PolicyStatus.valueOf(rs.getString("status")),
              rs.getBigDecimal("annual_premium_gbp"),
              rs.getBigDecimal("earned_premium_gbp"),
              rs.getString("postcode"),
              PostcodeDqStatus.valueOf(rs.getString("postcode_dq_status")),
              rs.getString("broker_id"),
              com.albion.api.dto.SourceSystem.valueOf(rs.getString("source_system")));

  private static LocalDate date(ResultSet rs, String column) throws SQLException {
    Date value = rs.getDate(column);
    return value == null ? null : value.toLocalDate();
  }
}
