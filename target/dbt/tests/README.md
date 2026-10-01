# dbt tests → DQ registry mapping

Each canonical dbt test below replaces one rule in
[`dq_rules/dq_rules_registry.csv`](../../../dq_rules/dq_rules_registry.csv) and
consolidates the drifted/duplicated legacy implementations of that rule into a
single, version-controlled assertion. The registry documented *where* rules were
implemented (and how they disagreed); these tests make one implementation the
enforced truth.

| Registry rule | dbt test | Where applied | Legacy implementations consolidated |
|---|---|---|---|
| **DQR-007** Email format | generic `email_format` (`tests/generic/email_format.sql`) | `stg_party.email`, `stg_customers.email`, `mart_policy_360.email` | Informatica `EXP_EMAIL_DQ` (regex+lower); BTEQ `04_stg_policy_360` (`@`-only); APF banking (none). Email lowercased once in `macros/standardise.sql` → `standardise_email`. |
| **DQR-014** UK postcode | generic `uk_postcode_format` (`tests/generic/uk_postcode_format.sql`) | `stg_party.postcode`, `stg_broker.postcode`, `stg_plcymstr.postcode`, `mart_policy_360.postcode` | Informatica variant A (auto-repair space); BTEQ (requires space); SAS `check_uk_postcode.sas` (case-sensitive PRX, never registered); COBOL `PLCYMSTR` 88-level (first-char-alpha, PR4471). Standardised once via `standardise_postcode`. **5th variant** — LIFE400 has no postcode field — is a documented **not_null exemption**: LIFE400 parties carry `postcode = null` by design, so nulls pass. |
| **DQR-021 / AR-118** NINO masked | generic `no_unmasked_nino` (`tests/generic/no_unmasked_nino.sql`) | `dim_party.nino_masked`, `mart_policy_360.nino_masked` | Informatica `EXP_NINO_MASK` (marts only); SAS `mask_nino.sas` (output only — `05_claims_fraud_scoring.sas` joined RAW NINO, AR-118). Masking applied in the **domain** layer (`macros/standardise.sql` → `mask_nino`); `nino_raw` is never selected past staging, so no unmasked NINO can reach a domain/mart consumer. |
| **DQR-030** Policy status domain | built-in `accepted_values(IF,RN,LP,CN,EX)` on `stg_policy.policy_status` + singular `dqr_030_legacy_policy_status.sql` | `stg_policy`, `stg_plcymstr` | Previously "none" registered; retired CAR/HSE product-as-status and life `PD` (paid-up) codes were dropped silently by SQ filters. Now flagged. |
| **DQR-033** Loss date not future | singular `dqr_033_loss_date_not_future.sql` | `dim_claim.loss_dt` | BTEQ `05_stg_claims_summary` (commented out 2022, no active impl). Re-instated. |
| **DQR-041** Party dedupe | built-in `unique` + `not_null` on `dim_party.party_key` | `dim_party` | MDM survivorship `wf_PARTY_MDM_SYNC` (~55% match; 41k unworked suspects). The canonical surrogate key is unique by construction. |
| **DQR-052** Date century (single pivot) | generic `single_pivot_date` (`tests/generic/single_pivot_date.sql`) | `stg_party.birth_dt`, `stg_plcymstr.inception_dt`, `stg_life_policy.insured_dob`, `stg_claim.loss_dt`, `dim_party.birth_dt`, `dim_claim.loss_dt` | Informatica pivot 49; SAS `julian_to_date.sas` pivot 50; LIFE400/DataStage/`V_LIFE_POLICY` pivot 40. All replaced by the **single sliding pivot** in `macros/albion_dates.sql`. The test asserts no future year and no `<1900` (+100y DOB shift) year. |

## The single Y2K pivot (DQR-052)

`macros/albion_dates.sql` resolves any two-digit year `yy` to `2000+yy` when that
year is `<=` the current calendar year, otherwise `1900+yy`. This is one agreed
rule for the whole estate and guarantees the two properties `single_pivot_date`
checks. It backs `parse_ddmmyyyy_text`, `julian_yyddd_to_date` and
`yymmdd_to_date`.

## Running the tests

```bash
cd target/dbt
python generate_seeds.py            # (re)build seeds from the sample data
dbt deps                            # (no external packages required)
dbt seed --target dev
dbt run  --target dev
dbt test --target dev               # runs generic + singular + schema tests
```

Set the `SNOWFLAKE_*` environment variables referenced in
`profiles.example.yml` first (copy it to `~/.dbt/profiles.yml`).
