# Albion target-state platform

Net-new, target-state code produced in the **Generate** phase of the
modernisation demo. It supersedes the legacy Teradata/BTEQ, SAS, Informatica,
DataStage, Oracle/PL-SQL and SOAP estate **without modifying any legacy source
file** — every model, test and endpoint references (in comments) the legacy
artifact it replaces.

Two deliverables:

| Directory | What it replaces | README |
|---|---|---|
| [`dbt/`](dbt/) | The whole Teradata/SAS/Informatica/DataStage analytical estate + the DQ registry | [dbt/README.md](dbt/README.md), [dbt/tests/README.md](dbt/tests/README.md) |
| [`api/`](api/) | `api_legacy/soap/PolicyInquiryService.wsdl` + `api_legacy/plsql/pkg_policy_inquiry.sql` | (this file) |

## 1. How the dbt tests replace the DQ registry

The legacy `dq_rules/dq_rules_registry.csv` was a *catalogue* of rules that were
implemented inconsistently (or not at all) across BTEQ, SAS, Informatica and
COBOL — the registry itself documented where each rule diverged. In the target
state the rules become **executable dbt tests**, one canonical assertion per
registry rule, run in CI:

| Registry rule | dbt test | Consolidates |
|---|---|---|
| DQR-007 email | generic `email_format` | Informatica `EXP_EMAIL_DQ`, BTEQ `@`-only, APF none |
| DQR-014 postcode | generic `uk_postcode_format` | 4 divergent validators; LIFE400 no-postcode = documented not_null exemption |
| DQR-021 / AR-118 NINO | generic `no_unmasked_nino` | SAS `mask_nino` (output-only) + the raw-NINO fraud join |
| DQR-030 policy status | `accepted_values(IF,RN,LP,CN,EX)` + singular `dqr_030_legacy_policy_status` | silent SQ drops of CAR/HSE/PD |
| DQR-033 future loss date | singular `dqr_033_loss_date_not_future` | BTEQ rule commented out in 2022 |
| DQR-041 party dedupe | `unique`/`not_null` on `dim_party.party_key` | MDM survivorship (~55% match) |
| DQR-052 date century | generic `single_pivot_date` | pivots 49 / 50 / 40 → one sliding pivot |

Full mapping, including which legacy implementation each test consolidates, is in
[`dbt/tests/README.md`](dbt/tests/README.md). The format chaos those rules police
is normalised **once** in the dbt staging layer (`dbt/macros/albion_dates.sql`,
`dbt/macros/standardise.sql`), not repeated per pipeline.

### The four "active policy" definitions and three earned-premium formulas

- `dbt/models/domains/dim_policy.sql` exposes a single canonical
  `active_policy_flag` plus the four explicit variants (`active_uw`,
  `active_finance`, `active_claims`, `active_life`) so the definitions the
  business genuinely needs are labelled rather than silently conflicting.
- `dbt/models/marts/mart_earned_premium.sql` computes ONE canonical earned
  premium (actuarial 365ths) and keeps `earned_premium_1_12` / `_1_24` as
  labelled reconciliation variants, replacing the three drifting implementations
  in `06_stg_earned_premium.bteq`, `wf_BILLING_PREMIUM_RECON.xml` and
  `06_reserving_triangles.sas`.
- The fraud flag `'S'` is mapped consistently to `'Y'` in one place
  (`dbt/models/staging/stg_claim.sql`), ending the BTEQ-vs-Informatica
  contradiction; the SII LoB mapping is a single seed
  (`dbt/seeds/sii_lob_map.csv`).

## 2. How the API replaces PolicyInquiryService

`target/api/` is a Spring Boot (Java 17) multi-module REST/JSON API that replaces
the frozen rpc/encoded SOAP service and its Oracle backend:

| Legacy | Target |
|---|---|
| `PolicyInquiryService.getPolicySummary` (SOAP) | `GET /policies/{policyNo}` and `GET /policies/{policyNo}/summary` |
| `PolicyInquiryService.getPartyClaims` (SOAP) | `GET /parties/{partyId}` and `GET /parties/{partyId}/claims` |
| (n/a — new) | `GET /claims/{claimNo}` |

Defects fixed (see `pkg_policy_inquiry.sql` for the originals):

- **Overloaded `customerRef` → typed `PartyIdentifier`.** The PL/SQL returned
  `NVL(TO_CHAR(legacy_customer_id), party_id) AS customer_ref`, packing two
  identifier schemes into one string. The API returns a structured
  `{ partyId, sourceScheme, legacyClientNo, apfCustomerId }`
  (`albion-domain/.../PartyIdentifier.java`) — the scheme is always explicit and
  the two schemes never share a field. Enforced by `LegacyContractMigrationTest`.
- **DD/MM/YYYY text → ISO-8601** dates on every resource.
- **Duplicated policy-number re-keying → one shared component.** The `AL/`→`ALB-`
  bordereaux normalisation, previously inline in the PL/SQL, lives once in
  `PolicyNumberNormalizer` (mirrors the dbt `normalise_policy_no` macro).
- **26h-stale ODS → fresh canonical store.** The API reads a fresh canonical
  domain store — in production the dbt marts (`mart_policy_360`, `dim_party`,
  `dim_claim`); in tests an H2 store seeded from the CSV samples via
  `CsvDataLoader`. Staleness is eliminated.

OpenAPI spec: served at `/v3/api-docs` (+ Swagger UI at `/swagger-ui.html`); a
generated snapshot is checked in at [`api/openapi.yaml`](api/openapi.yaml).
Contract tests (REST-assured, H2-seeded) assert response schema, ID-scheme
separation, ISO dates and status-domain values for every endpoint.

## Build & run

```bash
# dbt (see dbt/README.md)
cd dbt && python generate_seeds.py && dbt parse --target ci

# API — Java 17 required
cd api && JAVA_HOME=<jdk17> mvn test        # 17 tests (unit + contract)
JAVA_HOME=<jdk17> mvn -pl albion-app spring-boot:run   # then GET http://localhost:8080/swagger-ui.html
```
