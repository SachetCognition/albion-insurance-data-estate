package uk.co.albion.policyinquiry.repository;

import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import jakarta.annotation.PostConstruct;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Repository;

import uk.co.albion.policyinquiry.model.Claim;
import uk.co.albion.policyinquiry.model.PolicySummary;

/**
 * Repository backed by the CSV exports of the dbt marts
 * (target/dbt/exports/policy_360.csv and party_claims.csv). Locations are
 * configurable so a deployment can point straight at the dbt export
 * directory instead of the bundled classpath copies.
 */
@Repository
public class CsvMartPolicyRepository implements PolicyRepository {

    private static final CSVFormat FORMAT = CSVFormat.DEFAULT.builder()
            .setHeader()
            .setSkipHeaderRecord(true)
            .setIgnoreHeaderCase(true)
            .setTrim(true)
            .build();

    private final ResourceLoader resourceLoader;
    private final String policyCsvLocation;
    private final String claimsCsvLocation;

    private Map<String, PolicySummary> policiesByPolicyNo;
    private Map<String, List<Claim>> claimsByPartyId;

    public CsvMartPolicyRepository(
            ResourceLoader resourceLoader,
            @Value("${albion.data.policy-360:classpath:data/policy_360.csv}") String policyCsvLocation,
            @Value("${albion.data.party-claims:classpath:data/party_claims.csv}") String claimsCsvLocation) {
        this.resourceLoader = resourceLoader;
        this.policyCsvLocation = policyCsvLocation;
        this.claimsCsvLocation = claimsCsvLocation;
    }

    @PostConstruct
    void load() {
        policiesByPolicyNo = parse(policyCsvLocation, CsvMartPolicyRepository::toPolicy).stream()
                .collect(Collectors.toUnmodifiableMap(
                        p -> p.policyNo().toUpperCase(Locale.ROOT), p -> p));
        claimsByPartyId = parse(claimsCsvLocation, CsvMartPolicyRepository::toClaim).stream()
                .collect(Collectors.groupingBy(
                        c -> c.partyId().toUpperCase(Locale.ROOT), Collectors.toUnmodifiableList()));
    }

    @Override
    public Optional<PolicySummary> findPolicyByPolicyNo(String policyNo) {
        return Optional.ofNullable(
                policiesByPolicyNo.get(policyNo.trim().toUpperCase(Locale.ROOT)));
    }

    @Override
    public List<Claim> findClaimsByPartyId(String partyId) {
        return claimsByPartyId.getOrDefault(
                partyId.trim().toUpperCase(Locale.ROOT), List.of());
    }

    private <T> List<T> parse(String location, java.util.function.Function<CSVRecord, T> mapper) {
        Resource resource = resourceLoader.getResource(location);
        try (Reader reader = new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8);
             CSVParser parser = CSVParser.parse(reader, FORMAT)) {
            List<T> rows = new ArrayList<>();
            for (CSVRecord record : parser) {
                rows.add(mapper.apply(record));
            }
            return rows;
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to load mart export: " + location, e);
        }
    }

    private static PolicySummary toPolicy(CSVRecord r) {
        return new PolicySummary(
                r.get("policy_no"),
                r.get("party_id"),
                toLong(r.get("legacy_customer_id")),
                r.get("product_cd"),
                r.get("channel"),
                toDate(r.get("inception_dt")),
                toDate(r.get("expiry_dt")),
                r.get("policy_status"),
                r.get("active_policy_flag"),
                toDecimal(r.get("annual_premium_gbp")),
                toDecimal(r.get("earned_premium_gbp")),
                emptyToNull(r.get("postcode")),
                r.get("postcode_dq_status"),
                r.get("email_dq_status"),
                emptyToNull(r.get("broker_name")));
    }

    private static Claim toClaim(CSVRecord r) {
        return new Claim(
                r.get("claim_no"),
                r.get("policy_no"),
                r.get("party_id"),
                toDate(r.get("loss_dt")),
                toDate(r.get("notification_dt")),
                r.get("cause_cd"),
                r.get("claim_status"),
                toDecimal(r.get("incurred_amt")),
                toDecimal(r.get("paid_amt")),
                toDecimal(r.get("outstanding_reserve")));
    }

    private static String emptyToNull(String value) {
        return value == null || value.isEmpty() ? null : value;
    }

    private static Long toLong(String value) {
        return value == null || value.isEmpty() ? null : Long.valueOf(value);
    }

    private static BigDecimal toDecimal(String value) {
        return value == null || value.isEmpty() ? null : new BigDecimal(value);
    }

    private static LocalDate toDate(String value) {
        return value == null || value.isEmpty() ? null : LocalDate.parse(value);
    }
}
