# Deliverable 2 — Attribute-Overlap Matrix

Matrix of key business attributes vs. each system/pipeline, with the identity-scheme
fragmentation, the two partial crosswalks, the ~55% MDM match rate, and per-attribute
format divergence. All cells cite file paths and line numbers.

Legend: ✔ present · ✖ absent · ⚠ present but divergent format/semantics.

---

## 2.1 Identity schemes — SIX competing person/customer keys

| # | Scheme | System | Where defined | Crosswalked? |
|---|---|---|---|---|
| 1 | `CUSTOMER_ID` (BIGINT) | APF core banking | `teradata/ddl/00_source_tables.sql:15` | via `PARTY.LEGACY_CUSTOMER_ID` (sparse) |
| 2 | `PARTY_ID` (`P`+7 digits) | POLARIS PAS / MDM | `teradata/ddl/03_insurance_source_tables.sql:12` | hub key |
| 3 | `CLIENT_NO` (numeric) | LEGACY_PAS mainframe | `mainframe/copybooks/PLCYMSTR.cpy:11`; `03_insurance_source_tables.sql:98` | via manual `XREF_CLIENT_PARTY` |
| 4 | `customer_ref` (mixed) | SOAP PolicyInquiryService | `api_legacy/plsql/pkg_policy_inquiry.sql:16-19` | **NONE — two schemes in one field** |
| 5 | `LIFE_POLICY_ID` (`PM…`) | LIFE400 (AS/400) | `teradata/ddl/04_life_db.sql:5`; `as400_life/feed_specs/POLMSTEX_feed_spec.md:11` | **no person key** — name+DOB fuzzy only |
| 6 | `MKTG_CUST_ID` (5‑digit) | DataStage partner loyalty | `datastage/README.md:18-21` | **never crosswalked** |

### The two partial crosswalks
- **`PARTY.LEGACY_CUSTOMER_ID`** — APF banking crosswalk, **~55% populated, no RI**: `teradata/ddl/03_insurance_source_tables.sql:6-8`,`:24`.
- **`REF_DB.XREF_CLIENT_PARTY`** — **manual** (Excel‑upload heritage) LEGACY_PAS↔POLARIS map; neither side enforced; ~12% daily unmatched pass through NULL: `teradata/ddl/03_insurance_source_tables.sql:96-104`; lookup at `informatica/XML/wf_POLICY_MASTER_DAILY.xml:53-58`.

### MDM match rate & keyless books
- MDM survivorship (`wf_PARTY_MDM_SYNC`): match rate **stuck at ~55%**, **41k unworked** suspects in `MDM_SUSPECT_QUEUE`: `informatica/XML/wf_PARTY_MDM_SYNC.xml:7`; `dq_rules/dq_rules_registry.csv:7`; `docs/known_issues_register.md:14`.
- Life book matched by **name+DOB fuzzy inside a lost‑source DataStage job**, no suspect queue: `as400_life/feed_specs/POLMSTEX_feed_spec.md:23-25`; `teradata/ddl/04_life_db.sql:10`,`:16`; `datastage/README.md:13-16`.
- `MKTG_CUST_ID` deduped ad hoc on name+email only: `datastage/README.md:20-21`.

---

## 2.2 Attribute × system/pipeline matrix

| Attribute | Banking (BTEQ 01–03 / SAS 01–04) | POLARIS / INFA policy | Mainframe LEGACY_PAS | Claims (Guidewire+IMS / INFA / BTEQ 05) | Bordereaux (INFA RI) | LIFE400 / DataStage | SOAP / PL/SQL |
|---|---|---|---|---|---|---|---|
| **Party/customer id** | `CUSTOMER_ID` `00_source_tables.sql:15` | `PARTY_ID` `03_…:12` | `CLIENT_NO` `PLCYMSTR.cpy:11` | `CLAIMANT_PARTY_ID` `03_…:49` | policy‑only (re‑keyed) | none / `MATCHED_PARTY_ID` fuzzy `04_life_db.sql:16` | `customer_ref` mixed `pkg_policy_inquiry.sql:19` |
| **Policy number** | ✖ | `ALB-XXX-9999999` `03_…:30` | ⚠ hyphens stripped `PLCYMSTR_feed_spec.md:15`; sample `ALBPET0003278` `PLCYMSTR_D260115.dat` | `POLICY_NO` `03_…:48` | ⚠ `AL/PET-0001559` `CLAIMS_BDX_…csv:2` | ⚠ `PM0485738843` (life id) `04_life_db.sql:5` | re‑key inline (4th place) `pkg_policy_inquiry.sql:28-29` |
| **DOB / dates** | ISO `DATE` `00_source_tables.sql:18` | ⚠ `BIRTH_DT` DD/MM/YYYY **text** `03_…:16` | ⚠ Julian YYDDD pivot 49 `PLCYMSTR.cpy:14-15` | ⚠ `LOSS_DT` DD/MM/YYYY text; US‑parse bug `05_…bteq:7-11`, `wf_CLAIMS_FNOL_INTRADAY.xml:9` | ⚠ DD/MM/YYYY `CLAIMS_BDX_…csv:2` | ⚠ YYMMDD pivot 40 `POLMSTEX_feed_spec.md:5-7` | DD/MM/YYYY text out `pkg_policy_inquiry.sql:36` |
| **Premium / amount** | ✖ (balances) | `ANNUAL_PREMIUM_GBP` decimal `03_…:39` | ⚠ pence implied‑decimal `PLCYMSTR.cpy:16-17` | `INCURRED/PAID_AMT` decimal `03_…:54-55` | ⚠ £‑and‑commas text `CLAIMS_BDX_…csv:2`, `wf_REINSURANCE…xml:14-16` | ⚠ `MODAL_PREMIUM` implied 2dp `POLMSTEX_feed_spec.md:20` | decimal passthrough |
| **Postcode** | US `ZIP_CODE` `00_source_tables.sql:66` | `POSTCODE` VARCHAR(10) `03_…:23` | ⚠ no embedded space, weak check `PLCYMSTR.cpy:28-30` | (via party) | broker‑specific | ✖ **no postcode field** (ADDRMST stranded) `LIFEXTR.clle:13-15` | `postcode_dq_status` echoed `pkg_policy_inquiry.sql:25` |
| **NINO** | ✖ (SSN_HASH banking) `00_…:19` | `NINO` CHAR(9) **unmasked** `03_…:17-18` | ✖ | joined **raw** in SAS `05_…sas:32-38` | ✖ | ✖ | ✖ |
| **Email** | present, **no validation** `dq_rules_registry.csv:2` | `EMAIL_ADDR` mixed case `03_…:19`; INFA regex `wf_PARTY_MDM_SYNC.xml:9-12` | ✖ | ✖ | ✖ | ✖ | ✖ |
| **Risk score** | RISK_SCORE **0–1** prob `03_sas_risk_scoring.sas:122-139` | ✖ | ✖ | FRAUD_SCORE **0–1000** `05_…sas:69-83` | ✖ | ✖ | ✖ |
| **Fraud flag** | ✖ | ✖ | `S`=suspected `CLMHIST.cpy:20-23` | `'S'`→`'N'` INFA `wf_CLAIMS_FNOL_INTRADAY.xml:15-17`; `'S'`→`'Y'` BTEQ `05_…bteq:44-47` | ✖ | ✖ | ✖ |
| **Active‑policy flag** | ✖ | UW `IF/RN` `wf_POLICY_MASTER_DAILY.xml:48-50` | 88‑levels `PLCYMSTR.cpy:19-27` | Claims: any open claim `claims_glossary.md:3-5` | ✖ | Life `AC/GR/RS` `life_operations_glossary.md:5-8` | Finance flag echoed `pkg_policy_inquiry.sql:22-23` |

---

## 2.3 Format divergence per attribute (the "format chaos")

| Attribute | Formats observed | Evidence |
|---|---|---|
| **Dates** | ISO `YYYY-MM-DD`; DD/MM/YYYY‑as‑text; Julian `YYDDD`; `YYMMDD`; US MM/DD/YYYY parse bug | `00_source_tables.sql:18`; `03_insurance_source_tables.sql:16`,`:50`; `PLCYMSTR.cpy:14-15`; `POLMSTEX_feed_spec.md:5-7`; `wf_CLAIMS_FNOL_INTRADAY.xml:9` |
| **Y2K pivot years** | **49** (INFA), **50** (SAS), **40** (LIFE400/DataStage/V_LIFE_POLICY) | `wf_POLICY_MASTER_DAILY.xml:37`; `sas/macros/julian_to_date.sas:12`; `teradata/ddl/04_life_db.sql:22`; `dq_rules_registry.csv:8` |
| **Money** | pounds decimal; pence implied‑decimal; £‑and‑commas text | `03_insurance_source_tables.sql:39`; `PLCYMSTR.cpy:16-17`; `wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:14-16`; `CLAIMS_BDX_BRK0007_202606.csv:2` |
| **Policy number** | POLARIS `ALB-XXX-9999999`; mainframe hyphen‑stripped `ALBPET0003278`; bordereaux `AL/PET-0001559`; life `PM0485738843` | `PLCYMSTR_feed_spec.md:15`; `data/inbound_feeds/PLCYMSTR_D260115.dat:1`; `CLAIMS_BDX_BRK0007_202606.csv:2`; `04_life_db.sql:5` |
| **Postcode** | 5 handling variants (space‑repair / require‑space / case‑sensitive / first‑char‑alpha / none) | see Deliverable 4, DQR‑014 |
| **Risk score** | 0–1 probability vs 0–1000 SIU — side‑by‑side, no rescale | `03_sas_risk_scoring.sas:122-139`; `05_claims_fraud_scoring.sas:10-13`; `claims_glossary.md:13-15` |
