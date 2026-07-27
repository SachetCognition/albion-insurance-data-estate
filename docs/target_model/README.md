# ADEM-2 canonical target model

## Reproducible local run

The checked-in local profile is `dbt/profiles.yml`, using DuckDB at
`dbt/target/albion.duckdb`. It has no credentials and is the primary profile.
The loader is the single landing step: it parses fixed-width feeds and
canonical source CSVs into `migration/output/`; dbt reads those landing files
and does not reimplement fixed-width slicing.

```bash
cd /home/ubuntu/repos/albion-insurance-data-estate
python3 migration/load_local.py
cd dbt
/home/ubuntu/venvs/adem2/bin/dbt build --profiles-dir .
```

The as-of date is a dbt variable, defaulting to `2026-01-15` in
`dbt/dbt_project.yml`; this matches the D260115 feeds and makes earned premium,
future-date DQ results, and the summary deterministic.

Environment used for verification:

```text
python3 3.12.8
dbt-duckdb 1.10.1
dbt-core 1.12.0
duckdb 1.5.5
```

Install outside the repository:

```bash
python3 -m venv /home/ubuntu/venvs/adem2
/home/ubuntu/venvs/adem2/bin/pip install dbt-duckdb
```

## Canonical definitions

### Active Policy

Canonical status is the Underwriting policy-state definition: source `IF` and
`RN` map to `ACTIVE`; `LP` maps to `LAPSED`; `CN` maps to `CANCELLED`; `EX`
maps to `EXPIRED`. This is deterministic and expressible in the contract
enum without billing activity. It avoids Finance's non-deterministic
collection-in-45-days rule and Claims MI's classification of cancelled
policies with open claims as active.

Conflicting definitions retained as provenance:

* Finance: `IF` plus a collection in the last 45 days:
  `glossary/finance_data_dictionary.csv:2`.
* Underwriting: `IF` or `RN`, irrespective of collections:
  `glossary/underwriting_data_dictionary.csv:2`.
* Claims MI: any policy with an `OPEN` or `REOPENED` claim, even cancelled:
  `glossary/claims_glossary.md:3-5`.
* Life Operations: `CNTRSTS IN ('AC','GR','RS')`:
  `glossary/life_operations_glossary.md:5-8`.
* Actuarial does not use an active-policy status definition:
  `glossary/actuarial_definitions.md:8`.

Life status mapping is explicit: `AC`, `GR`, `RS` -> `ACTIVE`; `LA` ->
`LAPSED`; `CL` -> `CANCELLED`; `TE` -> `EXPIRED`; `PE` -> `LAPSED`.
Unknown life codes are quarantined under DQR-030. The checked-in POLMSTEX
sample contains `AC`, `GR`, `RS`, `LA`, `CL`, `TE`, and `PE`.

### Earned Premium

Canonical earned premium is actuarial daily pro-rata 365ths, clamped to
`[0, policy_term_days]`:

```text
annual_premium_gbp * least(greatest(as_of_date - inception_date, 0),
                           policy_term_days) / policy_term_days
```

This prevents negative future exposure and caps fully run-off policies.
Finance's 1/12ths definition is in `glossary/finance_data_dictionary.csv:3`;
the actuarial 365ths definition and billing 1/24ths comparison are in
`glossary/actuarial_definitions.md:3-7`. Life's
`MODAL_PREMIUM * PAY_FREQ` Annualised Premium In Force is separate and is not
added to earned premium; the group KPI conflation is documented at
`glossary/life_operations_glossary.md:9-11`.

### Century pivot and dates

There is one shared pivot: `YY <= 39` means `20YY`; otherwise `19YY`.
It applies to PLCYMSTR `YYDDD`, POLMSTEX `PRCDATE`, and `INSDOB`. Pivot 40
keeps life values such as `49` in the past. The implementation is shared in
`migration/load_local.py`; dbt defect test `defect_life_pivot_40` pins
`490420 -> 1949-04-20`.

Loss dates are parsed once as `DD/MM/YYYY` for every source, including
Guidewire. This fixes INC0067812. `defect_loss_date_day_le_12` pins
`09/05/2021 -> 2021-05-09`, not the US-format transpose.

### Fraud and status `S`

Fraud uses `Y | N | SUSPECTED`; blank/NULL becomes `N`, and fraud `S` becomes
`SUSPECTED`. A bordereaux `Status` of `S` is not fraud: it is settled and
becomes claim status `CLOSED`. The targeted dbt test
`defect_fraud_s_vs_bordereaux_status_s` pins both meanings.

### Identity and source systems

`policy_id` is the dashed CSV/POLARIS key; `legacy_policy_no` is its
hyphen-free PLCYMSTR form. PLCYMSTR `CLIENT_NO` joins to
`parties.LEGACY_CUSTOMER_ID`, implementing the XREF semantics. An XREF match
wins; when it misses, the existing canonical source-table party ID is retained
as a fallback. Only rows with neither an XREF match nor a source-table party
remain NULL. All XREF misses remain reported warnings. POLMSTEX has no party
key; `party_id` remains NULL and no fuzzy name+DOB matching is implemented.

Source mapping:

| Estate value | Canonical |
|---|---|
| POLARIS, LEGACY_PAS, mainframe-keyed policy | `PLCYMSTR` |
| POLMSTEX / LIFE400 | `LIFE400` |
| `GUIDEWIRE_CC` | `GUIDEWIRE` |

The landing `policies.csv` contains the 5,200 P&C policies plus the 420
accepted LIFE400 policies. PLCYMSTR feed values override the matching P&C
landing rows, including the feed postcode and XREF-derived party ID; thus the
P&C feed postcode is never sourced from the party address when a feed row is
present. `policy_360` emits both `PLCYMSTR` and `LIFE400` rows.

POLMSTEX modal premium is annualised as `MODAL_PREMIUM * PAY_FREQ`.
`modal_premium` and `pay_frequency` remain separate landing columns. This is
the annualisation basis for the canonical annual premium and is distinct from
the Life API KPI; Life API is not added to earned premium.

## Contract/mart mapping

| Contract field | Canonical/mart column |
|---|---|
| `policyId` | `policy_id` |
| `legacyPolicyNo` | `legacy_policy_no` |
| `partyId` | `party_id` |
| `productCode` | `product_code` |
| `inceptionDate` | `inception_date` |
| `expiryDate` | `expiry_date` |
| `status` | `status` |
| `annualPremiumGbp` | `annual_premium_gbp` |
| `earnedPremiumGbp` | `earned_premium_gbp` |
| `postcode` | `postcode` |
| `postcodeDqStatus` | `postcode_dq_status` |
| `brokerId` | `broker_id` |
| `sourceSystem` | `source_system` |
| `claimId` | `claim_id` |
| `lossDate` | `loss_date` |
| `notifiedDate` | `notified_date` |
| `incurredGbp` | `incurred_gbp` |
| `paidGbp` | `paid_gbp` |
| `fraudFlag` | `fraud_flag` |

Money uses `DECIMAL(15,2)` and dates use `DATE`. Snowflake enum checks are in
`snowflake/ddl/canonical_model.sql`; dbt accepted-value tests mirror them.

## DQ implementation map

| Rule | dbt implementation |
|---|---|
| DQR-007 | `dbt/tests/DQR-007_email_regex.sql`; lowercase full email regex; pass rate in `dq_pass_rates` |
| DQR-014 | `dbt/tests/DQR-014_postcode_regex.sql`; Variant A standardisation and regex, excluding MISSING from the denominator |
| DQR-021 | `dbt/tests/DQR-021_nino_not_projected.sql`; projection-level metadata test proves no NINO or weak NINO hash exists; raw NINO is not landed |
| DQR-030 | `dbt/tests/DQR-030_status_domain.sql`; loader rejects unknown policy/life statuses before landing |
| DQR-033 | Disabled failing test because registry marks it SUSPENDED; `dq_pass_rates` reports observed rate |
| DQR-041 | `dbt/tests/DQR-041_party_duplicate_persons.sql`; party natural-key candidate detection; configured WARN because the sample contains real duplicate natural keys |
| DQR-052 | Shared pivot implementation and `defect_life_pivot_40` test |

`dq_pass_rates` always emits one row for every registry ID, with `rule_id`,
`rule_name`, `pass_rate`, `evaluated_rows`, `failed_rows`, `method`, and
`as_of_date`. Pass rates are decimal(5,4). DQR-014 excludes MISSING postcodes
from its denominator. DQR-021 is 1.0000 by construction. DQR-041 measures
duplicate normalized first-name/last-name/birth-date natural-key rows, not
distinct party IDs. The duplicate-person singular test returns duplicate
natural-key groups and is WARN severity so `dbt build` remains usable while
the signal is visible. DQR-052 is evidenced from the plausible range of
pivot-derived inception dates rather than hard-coded. Its population is only
the 600 PLCYMSTR `YYDDD` rows and 420 POLMSTEX `YYMMDD` rows, marked
`PIVOT_40_JULIAN` or `PIVOT_40_YYMMDD` by the loader; the 5,200 ISO CSV dates
are excluded. The plausibility window is 2000-01-01 through
as-of-plus-365-days, which catches a pivot error's approximately 100-year
shift without treating ordinary near-term feed dates as century failures.

`data_product_summary` emits one row with `as_of_date`,
`active_policy_count`, `total_earned_premium_gbp`, `open_claims_count`, and
`total_incurred_gbp`. `policy_360` has the 13 policy contract columns listed
above; `claims_summary` has the eight claim contract columns. `earned_premium`
contains `policy_id`, `annual_premium_gbp`, `earned_premium_gbp`,
`unearned_premium_gbp`, and `as_of_date`.

## Migration outputs

`migration/load_local.py` writes:

* `migration/output/parties.csv` (NINO is SHA-256 hashed)
* `migration/output/xref_client_party.csv`
* `migration/output/policies.csv`
* `migration/output/claims.csv`
* `migration/output/plcymstr_parsed.csv`
* `migration/output/life_policy.csv`
* `migration/output/rejects.csv`
* `migration/output/reconciliation.csv`

Only `reconciliation.csv` and `rejects.csv` are retained by Git; the
scope-local `migration/output/.gitignore` excludes regenerated landing CSVs.

Reconciliation semantics are additive: `source_rows = loaded_rows +
rejected_rows`. A rejected row is not landed. `warning_rows` are landed rows
with a non-fatal DQ warning and are not included in `rejected_rows`. An
unmatched PLCYMSTR CLIENT_NO is reported as either
`DQR-041_UNMATCHED_CLIENT_NO_FALLBACK_SOURCE_PARTY` or
`DQR-041_UNMATCHED_CLIENT_NO_NO_PARTY`; the former retains the source-table
party ID and the latter remains NULL. Reject records are emitted once per
source line and reason.

The synthetic party table contains 3,200 rows and 2,630 populated legacy
customer IDs. After zero-padding feed CLIENT_NO numerically to ten digits,
74 of 600 PLCYMSTR client numbers match and 526 do not. This is a genuine
synthetic-data coverage result, not a parser mismatch: the feed values are
ten-digit numeric IDs and the matched values agree with the party
`LEGACY_CUSTOMER_ID` values after zero-padding. It differs from the
Informatica documentation's approximate 12% unmatched daily expectation.
Because all 526 unmatched rows have an existing source-table party ID, the
canonical policy landing still retains party IDs for all 5,200 P&C policies.

The loader does not write NINO or `nino_hash` to any canonical landing or
analytical projection. An unsalted SHA-256 NINO hash is not safe
pseudonymisation because the UK NINO keyspace is brute-forceable; DQR-021
therefore verifies absence rather than attempting to strengthen or consume
the hash.

Claims are referentially checked against `policy_360` by
`dbt/tests/claims_policy_referential_integrity.sql`. Bordereaux rows whose
derived policy ID is absent from the policy master are rejected with
`POLICY_NOT_IN_POLICY_MASTER:<policy_id>` rather than landed as silent
orphans.

Malformed loss or notification dates are rejected per source line with
`INVALID_LOSS_DT` or `INVALID_NOTIFICATION_DT`; they cannot abort the full
load. Duplicate policy and claim keys are likewise rejected with explicit
`DUPLICATE_POLICY_NO` or `DUPLICATE_CLAIM_NO` reasons, preserving additive
reconciliation counts.

The loader strips pound signs, commas, and quotes in bordereaux money fields.
POLMSTEX offsets are empirically read as 0-based slices corresponding to the
spec's 1-based positions: status `[35:37]`, DOB `[77:83]`, gender `[83]`,
modal premium `[99:112]`, and pay frequency `[114:116]`. The undocumented
gaps are positions 98-99 and 113-114; the sample's 116-character records
confirm those gaps.

Snowflake deployment entry points are in `migration/copy_into.sql`. The DDL
creates canonical `PARTY`, `XREF_CLIENT_PARTY`, `POLICY`, `CLAIM`, `REJECT`,
and `DQ_PASS_RATES` tables, plus raw fixed-width/CSV landing tables. The
`COPY INTO` statements land raw records first because Snowflake `COPY INTO`
does not perform the fixed-width field slicing; the same canonical slicing and
reject rules are then applied by the transformation layer.

The `dq_pass_rates` pass-rate expression uses true decimal division in DuckDB
and Snowflake; no integer-division workaround is required.
