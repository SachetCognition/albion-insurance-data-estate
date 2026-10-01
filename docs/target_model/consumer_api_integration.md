# Consumer API over the canonical marts (ADEM-2)

The Spring Boot service in `api/` reads the dbt-built canonical marts directly over
JDBC. There is no fixture, mock or seeded copy of the data in the runtime: the
repository interfaces in `com.albion.api.repository` have exactly one
implementation set, `com.albion.api.repository.jdbc`, and it queries the mart
tables by name.

| Contract endpoint | Mart table | Columns |
|---|---|---|
| `GET /api/v1/policies/{policyId}` | `policy_360` | `policy_id`, `legacy_policy_no`, `party_id`, `product_code`, `inception_date`, `expiry_date`, `status`, `annual_premium_gbp`, `earned_premium_gbp`, `postcode`, `postcode_dq_status`, `broker_id`, `source_system` |
| `GET /api/v1/policies?partyId=&status=&page=&size=` | `policy_360` | filter on `party_id` / `status`, `ORDER BY policy_id` with `LIMIT`/`OFFSET` |
| `GET /api/v1/policies/{policyId}/claims` | `claims_summary` | filter on `policy_id` |
| `GET /api/v1/claims/{claimId}` | `claims_summary` | filter on `claim_id` |
| `GET /api/v1/data-products/summary` | `data_product_summary` + `dq_pass_rates` | headline measures plus one `pass_rate` per `DQR-*` id |

## Running end to end

```bash
python3 migration/load_local.py                       # land the legacy feeds
cd dbt && dbt build --profiles-dir .                   # build the canonical marts
cd .. && mvn -f api/pom.xml spring-boot:run            # serve the API and dashboard on :8080
```

The service resolves `albion.marts.database` (default `dbt/target/albion.duckdb`)
from the working directory upwards and opens it read-only, so an unbuilt mart
fails fast with the commands above rather than silently serving stale or
substitute data. Pointing the property at another JDBC target is the only change
needed to serve the same contract from Snowflake once `snowflake/ddl/` is
deployed.

## Tests

`mvn -f api/pom.xml verify` builds a throwaway DuckDB database with the same mart
table and column names (`MartTestDatabase`, test scope only) and drives every
endpoint through the same JDBC repositories. The transformation semantics
themselves are pinned in dbt: `defect_loss_date_day_le_12`,
`defect_fraud_s_vs_bordereaux_status_s` and `defect_life_pivot_40`.
