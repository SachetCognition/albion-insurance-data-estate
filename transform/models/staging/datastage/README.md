# DataStage ports + LIFE_POLICY_LOAD lost-source recovery

Everything here is built from the legacy artefacts in this repository only.
Shared canonical macros (`standardise_postcode`, `is_valid_uk_postcode`,
`julian_to_date`, `party_canonical_key`, `regexp_full_match`) are consumed,
never re-implemented.

Seeds are regenerated with:

```bash
python3 transform/scripts/datastage/build_datastage_seeds.py
```

which also rewrites this workstream's rows in `seeds/parity_allowlist.csv`
(rows for other golden seeds are preserved untouched).

## Part 1 — ported DataStage jobs

| Model | Legacy job / stage |
|---|---|
| `stg_ds_transactions` | `RETAIL_DATA_MART_Job` → `Transaction_File` sequential-file stage |
| `stg_ds_retail_data_mart` | `RETAIL_DATA_MART_Job` → 3 × `PxJoin`, `PxFilter`, transformer |
| `stg_ds_customer_transaction_counts` | `Count_Customer_Transactions_Job` → `PxAggregator` |

Stage logic taken from the `.dsx` exports:

* Joins are inner joins on `CustomerID`, then `Stockid`, then `productid`.
* Filter predicate, verbatim from the export:
  `-where 'customertype like "citizen" or customertype like "foriegn"'`
  (no wildcards, so it behaves as equality — kept as `like` for fidelity).
* The transformer is pass-through/column-reorder only; there is no `Upcase`,
  `Trim` or `Convert` derivation in the export. The upper-cased, space-free
  values in the baseline output come from the source files themselves.
* The aggregator groups on `-key 'CustomerID' -key 'Stockid'` and emits
  `total_orders_num` as a row count over `RETAIL_DATA_MART.txt`, so the dbt
  port aggregates the mart model rather than re-reading the file.

### Documented intentional diffs (part 1)

* **DS-OVERFLOW-01 — 14 records.** The legacy links type `InvoiceDate` as
  `int32`, so 14 records land in `RETAIL_DATA_MART.txt` as `2147483647`. The
  port keeps the source value as `bigint`; the 14 records are allow-listed.
* **Reject visibility.** One record of `transactiondata.txt` has an unescaped
  comma inside `Description` (10 delimited fields instead of 9). The legacy
  stage rejected it silently; `stg_ds_transactions` keeps it with
  `is_rejected = true` and a `reject_reason`, and excludes it from the mart —
  so row-level parity is unaffected but the loss is now auditable.

## Part 2 — LIFE_POLICY_LOAD reconstruction (source lost since 2018)

Reconstructed from `as400_life/feed_specs/POLMSTEX_feed_spec.md` (FD-010),
`mainframe/feed_specs/PLCYMSTR_feed_spec.md` (FD-001),
`teradata/ddl/04_life_db.sql` (`LIFE_DB.LIFE_POLICY` + `V_LIFE_POLICY`),
`as400_life/LIFE400/QCPYSRC/POLDATA.cpy`,
`as400_life/LIFE400/QDDSSRC/POLMST.pf` and
`as400_life/extracts/LIFEXTR.clle`.

| Model | Rebuilt stage |
|---|---|
| `stg_life_policy_landing` | column-import → `LIFE_DB.LIFE_POLICY` |
| `stg_life_policy` | `LIFE_DB.V_LIFE_POLICY` derivations, canonical pivot |
| `stg_life_party_resolution` | the lost in-job name+DOB fuzzy match |
| `stg_life_plcymstr_client` | FD-001 client/address attributes (DQR-014, DQR-052) |
| `stg_life_address_repatriation` | ADDRMST repatriation target |

### Recovery assumptions

1. **Layout.** Records are 116 bytes, fixed width, at the FD-010 positions
   (asserted: `record_length` must be 116 for all 420 records).
2. **Amounts.** `SUMASSURED` and `MODALPREM` are 13.2 with implied decimals,
   so the landing value is the integer field / 100. Asserted against the raw
   records by `assert_life_landing_amounts_reconcile`.
3. **Dates land untouched.** Per the DDL comment, dates land as `INTEGER`
   `YYMMDD` exactly as received; no century logic happens in the load. The
   2016 integration truncated the 8-digit `POLMST` dates to 6 digits
   (`LIFEXTR.clle` header), and the original century is not recoverable from
   the feed.
4. **Century pivot.** FD-010 dates are `YYMMDD`, not Julian `YYDDD`, so the
   canonical pivot is taken from `julian_to_date` by converting the two-digit
   year alone (`yy || '001'`) and reading its year back. This guarantees the
   life book cannot drift from DQR-052 while still respecting the YYMMDD
   layout. Legacy `V_LIFE_POLICY` used pivot 40, so:
   * **84 of 420 policies** (two-digit DOB year 40–50) move from `19xx` to
     `20xx`. They are flagged by `dob_pivot_diff_flag`, exposed side by side
     as `insured_dob_ccyymmdd` (canonical) vs
     `insured_dob_ccyymmdd_legacy_pivot40`, and allow-listed as intentional
     diffs. `assert_life_dob_pivot_diffs_are_allowlisted` fails if the flagged
     set and the allow-list ever diverge in either direction.
   * The pivot-40 ambiguity flagged as "unresolved" in the feed spec
     (`390101 → 2039?!`) is resolved by the canonical rule: `39` → 2039 under
     both pivots; only 40–50 changes.
5. **Premium.** `annualised_premium_in_force = MODAL_PREMIUM * PAY_FREQ`, per
   `V_LIFE_POLICY`. This is the life book's own premium measure and is
   deliberately *not* run through `earned_premium` / `unearned_premium`: it is
   an in-force annualisation, not an earned-premium calculation.
6. **Baseline.** No golden fixture exists for this job — the export and its
   Teradata target are both gone. `golden_ds_life_policy_recon` is therefore
   an *independent* reimplementation of the documented legacy behaviour
   (FD-010 spec + landing DDL + pivot 40) written in Python in the seed
   builder, deliberately not sharing code with the dbt models, and used as the
   parity baseline. Full row/column parity holds except the 84 allow-listed
   pivot records.

### Party-resolution backfill (keyless life book)

FD-010 carries **no** customer or party identifier; the legacy job matched
`INSNAME` + `INSDOB` to PARTY records with an in-job fuzzy match whose
threshold, match rate, crosswalk and suspect queue are all lost. It is not
reproducible, so it is replaced with deterministic, auditable tiers, all keyed
through the shared `party_canonical_key` macro (precedence
`PARTY > LEGACY > APF > LIFE400 > MKTG > NINO`):

| Tier | Rule | Outcome |
|---|---|---|
| `T1_NAME_DOB` | full name + DOB, exactly one party candidate | auto-accept `PARTY:`/`LEGACY:` key |
| `T2_SURNAME_DOB` | surname + DOB, exactly one party candidate | auto-accept |
| `T3_CLIENT_NO` | surname resolves to exactly one FD-001 `CLIENT_NO` | auto-accept `LIFE400:` key |
| `SUSPECT_*` | candidates exist but are ambiguous | manual suspect queue |
| `NO_CANDIDATE` | no candidate at all | remains keyless |

**Measured outcome on the available feeds: 0 auto-accepted matches.** No
`INSNAME`+DOB or surname+DOB pair matches any party record, and while 127 of
the 420 policies have a surname present on FD-001, none resolves to a single
`CLIENT_NO`. The backfill therefore reports the entire life book as
unresolved rather than inventing a match rate — a quantified statement of the
gap, and the reason a real backfill needs the AS/400 `CLNTMST` client master
(which would slot in as a T0 tier ahead of T1). `matched_party_id` in
`stg_life_policy` is populated only from auto-accepted tiers, so it stays
`null` and parity against the baseline is unaffected.

### ADDRMST address repatriation

`ADDRMST` **does not exist in this estate.** The AS/400 correspondence
addresses were descoped from the 2016 integration and never migrated
(`docs/known_issues_register.md`, `docs/feed_inventory.md`), and the extract
program states it explicitly:

```
/* NOTE: NO ADDRESS/POSTCODE DATA - ADDRMST WAS DESCOPED FROM    */
```

Nothing can therefore be repatriated *from* `ADDRMST` today, and this
workstream does not pretend otherwise. Instead
`stg_life_address_repatriation` stands the repatriation target up and
populates it from the only surviving UK address attribute for this
population — the FD-001 `POSTCODE` of the surname candidates — with:

* the canonical `standardise_postcode` repair applied (FD-001 postcodes carry
  no embedded space and were only ever checked first-char-alpha, PR4471, so
  the repair is material: `NR13QQ` → `NR1 3QQ`);
* `is_valid_uk_postcode` as the DQR-014 verdict;
* `address_source = 'PLCYMSTR_FD001_CANDIDATE'` provenance, with
  `'ADDRMST_AS400'` reserved for the day the extract is recovered;
* `is_loadable`, true only when the party match was auto-accepted **and** the
  postcode is valid — so no ambiguous match can leak an address into a golden
  record (today: no row is loadable, consistent with the 0% match rate above).

`stg_life_plcymstr_client` also runs FD-001 `INCEPT_DT` (a genuine Julian
`YYDDD` field) through `julian_to_date`, which is where the canonical pivot
applies without any YYMMDD caveat.
