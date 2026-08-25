# transform/ — dbt migration project (Session 0 foundation)

dbt project for migrating representative samples of the legacy estate
(Teradata BTEQ, SAS, Informatica PowerCenter, DataStage) to Snowflake, with
DuckDB as the free local/CI engine and full before/after golden-parity
validation.

## Engines

| Target      | Engine    | Credentials | Use |
|-------------|-----------|-------------|-----|
| `duckdb` (default) | local `albion.duckdb` file | none | local dev + CI |
| `snowflake` | live account `tojgonb-sf03144` (org `tojgonb`, account `sf03144`) | env vars only | parity vs live warehouse |

## Local flow (zero credentials)

```bash
cd transform
pip install -r requirements.txt
dbt deps    --profiles-dir .
dbt build   --profiles-dir .            # seeds + models + all tests on DuckDB
```

## Snowflake flow

1. One-time bootstrap (idempotent — run as a privileged role):

   ```bash
   snowsql -a tojgonb-sf03144 -u <admin_user> -f snowflake_setup.sql
   ```

   Creates: `TRANSFORM_WH` (XS, `AUTO_SUSPEND=60`, `AUTO_RESUME`,
   `INITIALLY_SUSPENDED`), databases `RAW` + `GOLDEN` with schemas
   `RAW.SOURCE`, `GOLDEN.BASELINE/STAGING/DOMAINS/MARTS`, and the scoped
   `TRANSFORMER` role.

2. Set env vars (never hardcode credentials — see `.env.example`; key-pair
   auth via `SNOWFLAKE_PRIVATE_KEY_PATH` is preferred over password):

   ```bash
   cp .env.example .env   # fill in; .env is gitignored
   source .env
   ```

3. Build:

   ```bash
   dbt build -t snowflake --profiles-dir .
   ```

The warehouse auto-suspends 60s after each run — confirm with
`show warehouses like 'TRANSFORM_WH'` (state `SUSPENDED`).

## Layout & data flow

```
seeds/raw/     -> RAW.SOURCE        raw source tables (data/01_source_tables)
seeds/golden/  -> GOLDEN.BASELINE   IMMUTABLE legacy "before" outputs
                                    (data/02_bteq_staging, data/03_sas_data_products)
models/staging -> GOLDEN.STAGING    rebuilt staging models
models/domains -> GOLDEN.DOMAINS    domain models
models/marts   -> GOLDEN.MARTS      analytics / data products
```

On DuckDB the database split collapses into schema prefixes
(`raw_source`, `golden_baseline`, `golden_staging`, ...) via the
`generate_database_name` / `generate_schema_name` overrides in
`macros/cross_engine.sql`.

## Shared canonical macros (defined ONCE here — never redefine downstream)

| Macro | Replaces | Rule |
|-------|----------|------|
| `standardise_postcode` / `is_valid_uk_postcode` | 5 disagreeing DQR-014 variants | upper+trim, Informatica-style space auto-repair, full UK regex |
| `julian_to_date` | 3 disagreeing DQR-052 pivots (49/50/40) | single group pivot **50** |
| `earned_premium` / `unearned_premium` | Finance 1/12ths vs actuarial 365ths vs Informatica 1/24ths drift | canonical **straight-line 1/12ths**; `day_365ths` / `twenty_fourths` available behind `method=` and must be labelled + documented where used |
| `party_canonical_key` | six identity silos (DQR-041) | scheme-prefixed precedence key stub; Sessions C/D build survivorship/backfill on top |

## Golden-parity testing

`golden_parity` (macros/assert_golden_parity.sql) diffs a rebuilt model
against its immutable `GOLDEN.BASELINE` seed in both directions at full
row/column parity. Options:

- `exclude_columns` — volatile columns (e.g. `load_ts`); document each one.
- `round_columns: {col: decimals}` — documented numeric tolerance for
  float/statistical outputs instead of exact match.
- allow-list — add documented intentional diffs (converged DQ rules) to
  `seeds/parity_allowlist.csv` as `(golden_seed, pipe-joined key, reason)`.

Example (see `models/staging/foundation_smoke/_foundation_smoke.yml`):

```yaml
data_tests:
  - golden_parity:
      arguments:
        golden_seed: golden_stg_customer_360
        key_columns: ['customer_id']
        exclude_columns: ['load_ts']
```

## Parallel-session ownership (avoid file collisions)

| Session | Owns |
|---------|------|
| A (BTEQ) | `models/staging/bteq/` |
| B (SAS)  | `models/marts/`, `models/python/` |
| C (Informatica) | `models/staging/informatica/` |
| D (DataStage + lost-source) | `models/staging/datastage/` |

Sessions must consume the shared macros above, add rows to
`seeds/parity_allowlist.csv` (append-only) for intentional diffs, and pass
`dbt build --select <own models>` on both targets.

## Linting

```bash
sqlfluff lint models macros tests   # dialect=snowflake, config in .sqlfluff
```
