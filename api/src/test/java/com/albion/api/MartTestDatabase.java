package com.albion.api;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

/**
 * Builds a throwaway DuckDB database with the same canonical mart tables and column names that the
 * dbt project materialises, so the API can be exercised over its real JDBC path without requiring a
 * dbt build. Test scope only — the running service always reads the dbt-built marts.
 */
final class MartTestDatabase {
  static final int POLICY_COUNT = 25;
  static final String FIRST_POLICY_ID = "ALB-PET-0000001";
  static final String FIRST_POLICY_PARTY_ID = "P0000936";
  static final String SUSPECTED_CLAIM_ID = "CLM00001187";
  static final String AMBIGUOUS_LOSS_DATE_CLAIM_ID = "CLM00001188";

  private static Path database;

  private MartTestDatabase() {}

  static synchronized Path path() {
    if (database == null) {
      database = build();
    }
    return database;
  }

  private static Path build() {
    try {
      Path directory = Files.createTempDirectory("albion-marts");
      Path file = directory.resolve("albion-test.duckdb");
      directory.toFile().deleteOnExit();
      file.toFile().deleteOnExit();
      try (Connection connection = DriverManager.getConnection("jdbc:duckdb:" + file);
          Statement statement = connection.createStatement()) {
        create(statement);
        insertPolicies(statement);
        insertClaims(statement);
        insertDataQuality(statement);
      }
      return file;
    } catch (Exception e) {
      throw new IllegalStateException("Unable to build the test mart database", e);
    }
  }

  private static void create(Statement statement) throws SQLException {
    statement.execute(
        """
        CREATE TABLE policy_360 (
          policy_id VARCHAR, legacy_policy_no VARCHAR, party_id VARCHAR, product_code VARCHAR,
          inception_date DATE, expiry_date DATE, status VARCHAR,
          annual_premium_gbp DECIMAL(15,2), earned_premium_gbp DECIMAL(15,2),
          postcode VARCHAR, postcode_dq_status VARCHAR, broker_id VARCHAR, source_system VARCHAR)
        """);
    statement.execute(
        """
        CREATE TABLE claims_summary (
          claim_id VARCHAR, policy_id VARCHAR, loss_date DATE, notified_date DATE, status VARCHAR,
          incurred_gbp DECIMAL(15,2), paid_gbp DECIMAL(15,2), fraud_flag VARCHAR)
        """);
    statement.execute(
        """
        CREATE TABLE dq_pass_rates (
          rule_id VARCHAR, rule_name VARCHAR, pass_rate DECIMAL(5,4), evaluated_rows BIGINT,
          failed_rows BIGINT, method VARCHAR, as_of_date DATE)
        """);
    statement.execute(
        """
        CREATE TABLE data_product_summary (
          as_of_date DATE, active_policy_count BIGINT, total_earned_premium_gbp DECIMAL(15,2),
          open_claims_count BIGINT, total_incurred_gbp DECIMAL(15,2))
        """);
  }

  private static void insertPolicies(Statement statement) throws SQLException {
    String[] statuses = {"ACTIVE", "LAPSED", "CANCELLED", "EXPIRED"};
    for (int index = 1; index <= POLICY_COUNT; index++) {
      String policyId = index == 1 ? FIRST_POLICY_ID : String.format("ALB-MOT-%07d", index);
      String partyId = index == 1 ? FIRST_POLICY_PARTY_ID : String.format("P%07d", 1000 + index);
      String status = index <= 18 ? "ACTIVE" : statuses[(index - 18) % statuses.length];
      String premium = index == 1 ? "3100.09" : String.format("%d.50", 500 + index);
      statement.execute(
          "INSERT INTO policy_360 VALUES ('"
              + policyId
              + "', '"
              + policyId.replace("-", "")
              + "', '"
              + partyId
              + "', 'PET', DATE '2022-07-30', DATE '2023-07-30', '"
              + status
              + "', "
              + premium
              + ", "
              + premium
              + ", 'CF10 1EP', 'VALID', 'BRK0046', 'PLCYMSTR')");
    }
  }

  private static void insertClaims(Statement statement) throws SQLException {
    statement.execute(
        "INSERT INTO claims_summary VALUES ('"
            + SUSPECTED_CLAIM_ID
            + "', '"
            + FIRST_POLICY_ID
            + "', DATE '2023-07-01', DATE '2023-08-15', 'OPEN', 78107.93, 5663.06, 'SUSPECTED')");
    // Source loss date 09/05/2021 is 9 May 2021 under the canonical DD/MM/YYYY reading (INC0067812).
    statement.execute(
        "INSERT INTO claims_summary VALUES ('"
            + AMBIGUOUS_LOSS_DATE_CLAIM_ID
            + "', '"
            + FIRST_POLICY_ID
            + "', DATE '2021-05-09', DATE '2021-05-11', 'CLOSED', 81518.98, 43400.52, 'N')");
  }

  private static void insertDataQuality(Statement statement) throws SQLException {
    statement.execute(
        "INSERT INTO dq_pass_rates VALUES ('DQR-007', 'Email format valid', 1.0000, 3200, 0,"
            + " 'regex', DATE '2026-01-15')");
    statement.execute(
        "INSERT INTO dq_pass_rates VALUES ('DQR-014', 'UK postcode valid', 0.9746, 5125, 130,"
            + " 'variant A', DATE '2026-01-15')");
    statement.execute(
        "INSERT INTO data_product_summary VALUES (DATE '2026-01-15', 3652, 18081648.57, 405,"
            + " 68392673.71)");
  }
}
