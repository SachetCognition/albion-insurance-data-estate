# Target-State Slice — Policy-360 mart + Policy Inquiry API

First target-state slice of the Albion modernization (DJ-58). Both components
are built against one shared contract: the `policy_360` mart columns are the
Policy JSON fields served by the API.

## Shared contract

`policy_no, party_id, legacy_customer_id, product_cd, channel, inception_dt,
expiry_dt, policy_status, active_policy_flag, annual_premium_gbp,
earned_premium_gbp, postcode, postcode_dq_status, email_dq_status, broker_name`

Governed definitions (collapsing legacy drift):

* **active_policy_flag** — `policy_status IN ('IF','RN')`. Chosen as the group
  definition because it is deterministic from policy state alone (no billing
  or claims dependency), replacing the four conflicting legacy variants.
* **earned_premium_gbp** — straight-line monthly 1/12ths, the Finance
  convention already used by the BTEQ scripts; replaces 1/24ths (Informatica)
  and 365ths (SAS).
* **DQR-007 (email) / DQR-014 (UK postcode)** — one implementation each, in
  `dbt/macros/dq_rules.sql`, used both to derive the mart's `*_dq_status`
  columns and as dbt generic tests.

## dbt (`target/dbt/`)

Replaces `teradata/bteq/04_stg_policy_360.bteq` and
`teradata/bteq/06_stg_earned_premium.bteq`. Seeds are local copies of
`data/01_source_tables/*.csv`; the local profile is DuckDB (a Snowflake target
can be added to `profiles.yml`).

```bash
pip install dbt-duckdb
cd target/dbt
dbt build --profiles-dir .        # seeds + models + tests
dbt docs generate --profiles-dir . # lineage docs
```

`dbt build` also writes CSV exports of the marts to `target/dbt/exports/`
(`policy_360.csv`, `party_claims.csv`).

## API (`target/api/`)

Spring Boot 3 replacement for `api_legacy/soap/PolicyInquiryService.wsdl` +
`api_legacy/plsql/pkg_policy_inquiry.sql`:

* `GET /api/v1/policies/{policyNo}` — shared Policy contract. `partyId` and
  `legacyCustomerId` are separate fields (no legacy `customer_ref` dual-identifier hack).
* `GET /api/v1/parties/{partyId}/claims` — ISO-8601 dates, canonical
  `party_id` key only.
* Swagger UI at `/swagger-ui.html`.

```bash
cd target/api
./mvnw verify          # build + contract tests
./mvnw spring-boot:run # serve on :8080
```

The repository reads the dbt mart exports. Bundled copies live in
`src/main/resources/data/`; point at a fresh dbt build with:

```bash
./mvnw spring-boot:run -Dspring-boot.run.arguments="\
  --albion.data.policy-360=file:../dbt/exports/policy_360.csv \
  --albion.data.party-claims=file:../dbt/exports/party_claims.csv"
```
