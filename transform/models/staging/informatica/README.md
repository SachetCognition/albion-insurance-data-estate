# Informatica PowerCenter ports (Session C)

Ports of three representative PowerCenter workflows from `informatica/XML/` into
dbt models. Each model has one CTE per PowerCenter transformation instance and
the CTEs keep the legacy instance names, so the XML and the SQL can be read side
by side.

| Workflow XML | Mapping / target | dbt model |
| --- | --- | --- |
| `wf_POLICY_MASTER_DAILY.xml` | `m_POLICY_MASTER_DAILY` → `STG_POLICY_MASTER` | `stg_informatica_policy_master` |
| `wf_PARTY_MDM_SYNC.xml` | `m_PARTY_MDM_SYNC` (party golden record) | `stg_informatica_party_mdm` (+ `stg_informatica_party_match_rate`) |
| `wf_BILLING_PREMIUM_RECON.xml` | `m_BILLING_PREMIUM_RECON` | `stg_informatica_billing_premium_recon` |

## Transformation coverage

**wf_POLICY_MASTER_DAILY**

- `SQ_PLCYMSTR_DAILY` — source qualifier over the `LEGACY_PAS` nightly policy
  master extract (1,498 policies in the sample). The fixed-width file carried
  the inception date as a `YYDDD` julian string, so the julian value is
  reconstructed from the seeded ISO date and then converted back, exercising the
  conversion rule rather than bypassing it.
- `EXP_POLICY_DATES` — shared `julian_to_date` macro (DQR-052, pivot 50).
- `EXP_POSTCODE_DQ` — shared `standardise_postcode` / `is_valid_uk_postcode`
  macros (DQR-014).
- `EXP_POLICY_FLAGS` — underwriting active-policy definition (`IF` / `RN`).
- `LKP_XREF_CLIENT_PARTY` — `CLIENT_NO` → `PARTY_ID`, `Use First Value` on
  multiple match, unmatched rows pass through with a null `PARTY_ID` and
  `xref_unmatched_flag = 'Y'` (673 of 1,498 rows in the sample).

**wf_PARTY_MDM_SYNC**

- `EXP_EMAIL_DQ` (DQR-007 variant B), `EXP_NINO_MASK` (DQR-021),
  `EXP_XMATCH_APF` (name/DOB cross-match into the APF banking customer book).
- Survivorship: most-recent-update wins for the cluster survivor, **except**
  email where the longest standardised string wins (the undocumented 2020
  decision, retained and labelled). Clusters are `NINO` exact where present,
  otherwise surname block + exact DOB.
- Identity: the canonical key always comes from the shared
  `party_canonical_key` macro. Six schemes are in scope; `PARTY`, `LEGACY`,
  `APF` and `NINO` are populated from the sample, `LIFE400` (`CLIENT_NO`) and
  `MKTG` (`MKTG_CUST_ID`) have no column in the sample sources and are passed
  as nulls.

**wf_BILLING_PREMIUM_RECON**

- Premium aggregation (written / net-written / collected / IPT / commission),
  `LKP_APF_ACCOUNTS` across the Teradata ↔ core-banking boundary (orphan APF
  references are flagged, not written to a dead `BAD_APF_MATCH` file),
  `EXP_IPT_RECALC`, `EXP_EARNED_24THS`.
- Earned premium consumes the shared `earned_premium` macro **twice**: the
  legacy figure with `method='twenty_fourths'` (labelled via
  `earned_premium_method_label = 'EARNED_24THS_LEGACY_DWH_RECON'`) and the
  canonical `twelfths` figure, with the difference exposed as
  `earned_premium_method_drift_gbp` (sample total: £86,278.16 over 5,200
  policies).
- `SYSDATE` is replaced by the deterministic var `informatica_recon_as_at_dt`
  (default `2026-06-30`).

## Validation approach

`transform/seeds/golden/` only contains baselines for the BTEQ `stg_*` tables
and the SAS data products; there is **no** GOLDEN baseline for any Informatica
Teradata staging target, so `golden_parity` is not applicable to these models.
Validation is therefore:

- schema DQ tests — `not_null`, `unique`, `accepted_values`, `relationships`
  back to the raw seeds (see `_informatica_models.yml`);
- singular tests in `transform/tests/informatica/` — earned-premium bounds and
  method ordering, DQR-014 consistency between the two ports, and MDM
  match-rate non-regression against the legacy 55% baseline.

If a GOLDEN baseline for `STG_POLICY_MASTER` or the MDM hub is later seeded,
each model needs only a `golden_parity` block (`key_columns: ['policy_no']` /
`['party_id']`, `exclude_columns: ['load_ts']`).

## MDM match rate vs the legacy 55%

`stg_informatica_party_match_rate` (single row) measures it:

| measure | value |
| --- | --- |
| parties | 3,200 |
| legacy `LEGACY_CUSTOMER_ID` xref matches | 1,760 → **55.00%** |
| converged matches (xref → email → surname+DOB) | 1,760 → **55.00%** |
| delta | **0.00pp** |
| legacy links corroborated by a converged rule | 500 (0 conflicting customer ids) |
| suspect-queue analogue (unmatched) | 1,440 |

The converged rules add no new matches: every party without a
`LEGACY_CUSTOMER_ID` also has no email and no surname+DOB counterpart in the APF
book. The 45% gap is missing source coverage, not weak matching logic — which
is the actionable finding for the 41k-row `MDM_SUSPECT_QUEUE`.

## Intentional converged-rule diffs

Documented in `transform/seeds/parity_allowlist.csv`:

- **DQR-014** — the converged postcode rule collapses internal whitespace
  before re-inserting the single space, so double-spaced mainframe postcodes
  (`'M1  1AE'`) standardise to `'M1 1AE'` and flip `INVALID` → `VALID`
  (25 policies, 38 party rows).
- **DQR-052** — converged pivot 50 vs the Informatica `EXP_POLICY_DATES` pivot
  49; `50ddd` julian values now resolve to 2050 instead of 1950 (0 rows
  affected in the current sample).
- **SOUNDEX** — the legacy fuzzy blocking key was `SOUNDEX(surname)`; DuckDB has
  no `SOUNDEX`, so the port blocks on the upper-cased 4-character surname
  prefix, which keeps the match rate identical on both engines.
- **IPT rate** — the legacy 12% hardcode is kept as
  `ipt_expected_legacy_gbp`; `ipt_expected_policy_rate_gbp` additionally applies
  `POLICY.IPT_RATE`, which the legacy mapping ignored.
