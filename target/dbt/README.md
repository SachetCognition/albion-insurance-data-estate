# Albion Target — Snowflake + dbt

Target-state analytical model for Albion General Insurance Group, superseding the
legacy Teradata BTEQ / SAS / Informatica / DataStage estate. **Net-new code — no
legacy source file is modified.** Every model and test references (in comments)
the legacy artifact it replaces.

## Layering

```
seeds (raw_*)                      sample data / raw landing (see generate_seeds.py)
   │
models/staging/  (views)           one view per raw source; ALL format chaos
   │                               normalised ONCE here (dates, postcode, email,
   │                               money) — the single canonical place
models/domains/  (tables)          canonical PARTY / POLICY / CLAIM / PREMIUM /
   │                               REINSURANCE dimensions; identity unification;
   │                               NINO masking
models/marts/    (tables)          earned-premium, policy-360, claims-summary
```

### Staging (`models/staging/`)
One view per raw source: `stg_party`, `stg_policy`, `stg_broker`, `stg_claim`,
`stg_premium_transactions`, `stg_treaty`, `stg_xref_client_party`,
`stg_customers`, `stg_life_policy`, and `stg_plcymstr` (the LEGACY_PAS PLCYMSTR
flat feed). The format chaos is normalised in one canonical place:
DD/MM/YYYY text and Julian YYDDD and LIFE YYMMDD dates → `DATE` via a **single
agreed Y2K pivot** (replacing the 49/50/40 divergence, DQR-052); postcodes,
emails and money standardised once (DQR-014, DQR-007).

### Domains (`models/domains/`)
- `dim_party` — unifies the six identity schemes (CUSTOMER_ID / PARTY_ID /
  CLIENT_NO / customer_ref / LIFE_POLICY_ID / MKTG_CUST_ID) into one surrogate
  `party_key` with source-system lineage; **NINO masked** here (DQR-021 / AR-118).
- `dim_policy` — single canonical `active_policy_flag` + four explicit variant
  flags (`active_uw` / `active_finance` / `active_claims` / `active_life`).
- `dim_claim`, `dim_premium`, `dim_reinsurance`.

### Marts (`models/marts/`)
- `mart_earned_premium` — ONE canonical earned premium (actuarial 365ths) plus
  labelled `earned_premium_1_12` and `earned_premium_1_24` variants.
- `mart_policy_360`, `mart_claims_summary`.
- Single canonical SII LoB mapping via seed `sii_lob_map`.

## Tests
See [`tests/README.md`](tests/README.md) for the full mapping of each dbt test
back to its `dq_rules/dq_rules_registry.csv` rule and the legacy implementations
it consolidates.

## Quickstart

```bash
python generate_seeds.py                 # build seeds from data/01_source_tables + data/inbound_feeds
cp profiles.example.yml ~/.dbt/profiles.yml   # then set SNOWFLAKE_* env vars
dbt seed && dbt run && dbt test
```

`dbt parse --target ci` validates the project without a live warehouse.
