package uk.co.albion.api.seed;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.ApplicationArguments;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import uk.co.albion.api.entity.ClaimEntity;
import uk.co.albion.api.entity.PartyEntity;
import uk.co.albion.api.entity.PolicyEntity;
import uk.co.albion.api.repo.ClaimRepository;
import uk.co.albion.api.repo.PartyRepository;
import uk.co.albion.api.repo.PolicyRepository;
import uk.co.albion.domain.PolicyNumberNormalizer;

/**
 * Seeds the in-memory H2 domain store from the CSV samples under
 * classpath:seed-data/ (derived from data/01_source_tables/ — see
 * target/api/build_seed_data.py). Applies the SAME canonical normalisations as
 * the dbt staging/domain layers, so tests run against faithful canonical data
 * without Snowflake. Also demonstrates staleness elimination: the store is
 * loaded fresh at startup, unlike the 26h-stale ODS behind the SOAP service.
 */
@Component
public class CsvDataLoader implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CsvDataLoader.class);

    private final PartyRepository parties;
    private final PolicyRepository policies;
    private final ClaimRepository claims;
    private final PolicyNumberNormalizer normalizer;

    public CsvDataLoader(PartyRepository parties, PolicyRepository policies,
                         ClaimRepository claims, PolicyNumberNormalizer normalizer) {
        this.parties = parties;
        this.policies = policies;
        this.claims = claims;
        this.normalizer = normalizer;
    }

    @Override
    public void run(ApplicationArguments args) throws IOException {
        if (parties.count() > 0) {
            return;
        }
        loadParties();
        Set<String> openClaimPolicies = loadClaims();
        loadPolicies(openClaimPolicies);
        log.info("Seeded canonical store: {} parties, {} policies, {} claims",
                parties.count(), policies.count(), claims.count());
    }

    private void loadParties() throws IOException {
        for (Map<String, String> r : read("parties.csv")) {
            PartyEntity p = new PartyEntity();
            p.setPartyId(r.get("party_id"));
            p.setFirstName(r.get("first_name"));
            p.setLastName(r.get("last_name"));
            p.setDateOfBirth(CanonicalTransforms.parseDdMmYyyy(r.get("birth_dt")));
            p.setNinoMasked(CanonicalTransforms.maskNino(r.get("nino")));
            p.setEmail(CanonicalTransforms.email(r.get("email_addr")));
            p.setPostcode(CanonicalTransforms.postcode(r.get("postcode")));
            p.setApfCustomerId(parseLong(r.get("legacy_customer_id")));
            // Derived legacy client no (matches the crosswalk convention in generate_seeds.py).
            Long apf = p.getApfCustomerId();
            p.setLegacyClientNo(apf == null ? null : 700000000L + apf);
            parties.save(p);
        }
    }

    /** @return set of policy numbers (canonical) that have an OPEN/REOPENED claim. */
    private Set<String> loadClaims() throws IOException {
        Set<String> openClaimPolicies = new HashSet<>();
        List<ClaimEntity> batch = new ArrayList<>();
        for (Map<String, String> r : read("claims.csv")) {
            ClaimEntity c = new ClaimEntity();
            c.setClaimNo(r.get("claim_no"));
            String canonicalPolicy = normalizer.normalise(r.get("policy_no"));
            c.setPolicyNo(canonicalPolicy);
            c.setClaimantPartyId(r.get("claimant_party_id"));
            c.setLossDate(CanonicalTransforms.parseDdMmYyyy(r.get("loss_dt")));
            c.setNotificationDate(CanonicalTransforms.parseIso(r.get("notification_dt")));
            c.setCauseCd(r.get("cause_cd"));
            c.setClaimStatus(upper(r.get("claim_status")));
            c.setIncurredAmt(parseDecimal(r.get("incurred_amt")));
            c.setPaidAmt(parseDecimal(r.get("paid_amt")));
            c.setOutstandingReserve(parseDecimal(r.get("outstanding_reserve")));
            c.setFraudFlag(CanonicalTransforms.fraudFlag(r.get("fraud_flag")));
            batch.add(c);
            if ("OPEN".equals(c.getClaimStatus()) || "REOPENED".equals(c.getClaimStatus())) {
                openClaimPolicies.add(canonicalPolicy);
            }
        }
        claims.saveAll(batch);
        return openClaimPolicies;
    }

    private void loadPolicies(Set<String> openClaimPolicies) throws IOException {
        List<PolicyEntity> batch = new ArrayList<>();
        for (Map<String, String> r : read("policies.csv")) {
            PolicyEntity p = new PolicyEntity();
            p.setPolicyNo(normalizer.normalise(r.get("policy_no")));
            p.setPartyId(r.get("party_id"));
            p.setProductCd(upper(r.get("product_cd")));
            p.setProductName(r.get("product_name"));
            p.setBrokerId(r.get("broker_id"));
            p.setChannel(r.get("channel"));
            p.setInceptionDate(CanonicalTransforms.parseIso(r.get("inception_dt")));
            p.setExpiryDate(CanonicalTransforms.parseIso(r.get("expiry_dt")));
            String status = upper(r.get("policy_status"));
            p.setPolicyStatus(status);
            p.setAnnualPremiumGbp(parseDecimal(r.get("annual_premium_gbp")));
            p.setIptRate(parseDecimal(r.get("ipt_rate")));
            p.setPaymentPlan(r.get("payment_plan"));
            p.setUwYear(parseInt(r.get("uw_year")));
            p.setSourceSystem(upper(r.get("source_system")));

            // Four explicit "active" variants + single canonical flag.
            boolean activeUw = "IF".equals(status) || "RN".equals(status);
            boolean activeFinance = "IF".equals(status); // prod: mart_policy_360.active_finance (collection <=45d)
            boolean activeClaims = openClaimPolicies.contains(p.getPolicyNo());
            p.setActiveUw(activeUw);
            p.setActiveFinance(activeFinance);
            p.setActiveClaims(activeClaims);
            p.setActivePolicyFlag(activeUw); // canonical for P&C
            batch.add(p);
        }
        policies.saveAll(batch);
    }

    // ---- minimal CSV parsing (quote-aware) ------------------------------------

    private List<Map<String, String>> read(String name) throws IOException {
        List<Map<String, String>> rows = new ArrayList<>();
        try (InputStream in = new ClassPathResource("seed-data/" + name).getInputStream();
             BufferedReader br = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String headerLine = br.readLine();
            if (headerLine == null) {
                return rows;
            }
            String[] headers = splitCsv(headerLine);
            String line;
            while ((line = br.readLine()) != null) {
                if (line.isBlank()) {
                    continue;
                }
                String[] cells = splitCsv(line);
                Map<String, String> row = new HashMap<>();
                for (int i = 0; i < headers.length; i++) {
                    row.put(headers[i], i < cells.length ? cells[i] : "");
                }
                rows.add(row);
            }
        }
        return rows;
    }

    private static String[] splitCsv(String line) {
        List<String> out = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (ch == '"') {
                if (inQuotes && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    cur.append('"');
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                out.add(cur.toString());
                cur.setLength(0);
            } else {
                cur.append(ch);
            }
        }
        out.add(cur.toString());
        return out.toArray(new String[0]);
    }

    private static String upper(String s) {
        return s == null ? null : s.trim().toUpperCase();
    }

    private static Long parseLong(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            return Long.parseLong(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Integer parseInt(String s) {
        Long l = parseLong(s);
        return l == null ? null : l.intValue();
    }

    private static BigDecimal parseDecimal(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            return new BigDecimal(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
