# Deliverable 1 — Feed / Pipeline Inventory

**Scope:** Every pipeline/feed across Informatica PowerCenter (insurance + legacy
GSS), SAS (Premium Finance banking + insurance estate), Teradata BTEQ, mainframe
COBOL/JCL, and the AS/400 life estate — cross-checked against `docs/feed_inventory.md`.

All rows cite exact file paths and line numbers as evidence. Where the README or
the governance inventory claims something the repo does not contain, it is flagged
under **Gaps & discrepancies**.

---

## 1.1 Master feed register (reconciled with `docs/feed_inventory.md`)

| Feed | Source → Target | Tech / orchestrator | Schedule | Format | Evidence |
|---|---|---|---|---|---|
| **FD-001 PLCYMSTR** | LEGACY_PAS (VSAM) → Teradata `STG_POLICY_MASTER` / `STG_POLICY_360` (+ **separate actuarial copy**) | JCL `PLCYEXTR` + NDM (Connect:Direct) → INFA `wf_POLICY_MASTER_DAILY` → BTEQ `04` | Extract 02:40, NDM 03:00, INFA 03:15 (Control‑M **ALB‑DWH‑0032**), BTEQ 04:30 | Fixed width LRECL 80 | `mainframe/jcl/PLCYEXTR.jcl:10`, `:17-26`; `mainframe/copybooks/PLCYMSTR.cpy`; `mainframe/feed_specs/PLCYMSTR_feed_spec.md:5-10`; `informatica/XML/wf_POLICY_MASTER_DAILY.xml:7`,`:79`,`:84-86`; `teradata/bteq/04_stg_policy_360.bteq:1-10`; `docs/feed_inventory.md:6` |
| **FD-002 POLARIS policy CDC** | POLARIS PAS (Oracle) → `POLICY_ADMIN_DB` | Informatica CDC | 15 min | Oracle CDC | `docs/feed_inventory.md:7` — **no workflow export in `informatica/XML/`** (see Gaps) |
| **FD-003 Guidewire CC events** | Guidewire ClaimCenter → `CLAIMS_DB.CLAIM` | INFA `wf_CLAIMS_FNOL_INTRADAY` | Every 30 min 07:00–21:00 (Control‑M **ALB‑DWH‑0047**, cyclic) | event/micro‑batch | `informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml:7`,`:28`; `orchestration/controlm/ALBION_DWH_DAILY.xml:13`; `docs/feed_inventory.md:8` |
| **FD-004 LEGACY_CLM** | IMS mainframe → same INFA workflow (union) | JCL extract per `CLMHIST.cpy` → `wf_CLAIMS_FNOL_INTRADAY` (union) | Daily | Fixed width | `mainframe/copybooks/CLMHIST.cpy:1-4`; union declared in mapping at `informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml:7`; `docs/feed_inventory.md:9` — **`CLMEXTR` JCL referenced but absent** (see Gaps) |
| **FD-005 Broker bordereaux** | 14 brokers (SFTP) → `REINSURANCE_DB` | ksh `bdx_transfer` + INFA `wf_REINSURANCE_BORDEREAUX_MONTHLY` | Monthly WD3 (cron `bdx_transfer` 06:00 WD1‑5) | CSV, per‑broker columns, £‑text amounts | `informatica/scripts/bdx_transfer:9-18`; `informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:7`,`:25`; `data/inbound_feeds/CLAIMS_BDX_BRK0007_202606.csv:1-6`; `docs/feed_inventory.md:10` |
| **FD-006 Banking core** | APF core banking → `STG_CUSTOMER_360` etc. → SAS 01–04 | BTEQ `01–03` + SAS `01–04` | Daily 02:00 (Control‑M **ALB‑DWH‑0040** `run_full_pipeline.sh`) | Teradata | `teradata/bteq/01_stg_customer_360.bteq`; `sas/premium_finance/01–04`; `orchestration/controlm/ALBION_DWH_DAILY.xml:12`; `docs/feed_inventory.md:11` |
| **FD-007 Premium txns** | Billing platform → Finance close / QRT | BTEQ `06_stg_earned_premium` + INFA `wf_BILLING_PREMIUM_RECON` | BTEQ monthly WD2 06:00; INFA monthly WD1 22:00 (Control‑M **ALB‑FIN‑0012**) | Teradata | `teradata/bteq/06_stg_earned_premium.bteq:1-10`; `informatica/XML/wf_BILLING_PREMIUM_RECON.xml:28`; `orchestration/controlm/ALBION_DWH_DAILY.xml:21`; `docs/feed_inventory.md:12` |
| **FD-008 Bureau scores** | Credit bureau → SAS `03_risk_scoring` (banking only) | sftp CSV | Weekly | CSV | `sas/premium_finance/03_sas_risk_scoring.sas:31-44`; `data/01_source_tables/customer_bureau_scores.csv`; `docs/feed_inventory.md:13` |
| **FD-009 GSS payroll estate** | EHRP etc. → HR BI | Legacy INFA folders `COMP_TIME`, `EHRP2BIIS`, `Pay_Calendar` + ksh transfer scripts | Biweekly | Oracle/flat file | `informatica/legacy_shared_services/XML/*`; `informatica/legacy_shared_services/scripts/*`; `docs/feed_inventory.md:14` |
| **FD-010 POLMSTEX** | LIFE400 (AS/400) → DataStage `LIFE_POLICY_LOAD` → `LIFE_DB.LIFE_POLICY` | CL `LIFEXTR` + FTP (plaintext) → DataStage 9.1 | Nightly 23:30 (AS/400 ADDJOBSCDE); DS 00:45 | Fixed width, YYMMDD | `as400_life/extracts/LIFEXTR.clle`; `as400_life/feed_specs/POLMSTEX_feed_spec.md`; `datastage/README.md:13-16`; `teradata/ddl/04_life_db.sql`; `docs/feed_inventory.md:26` |
| **FD-011 Partner loyalty** | Retail partners → RETAIL / ACTIVATIONSALES marts, Bouns_Program | Delimited files → DataStage | Weekly | Delimited | `datastage/jobs/RETAIL_DATA_MART_Job.dsx`, `ACTIVATIONSALES_DATA_MART_Job.dsx`, `Bouns_Program_Job.dsx`; `datastage/README.md:18-21`; `docs/feed_inventory.md:27` |

---

## 1.2 Informatica PowerCenter — insurance estate (`informatica/`)

**5 workflow exports (`informatica/XML/`):**

1. **`wf_POLICY_MASTER_DAILY`** — LEGACY_PAS policy master → Teradata staging.
   - Source flat file per `PLCYMSTR.cpy`, LRECL 80: `wf_POLICY_MASTER_DAILY.xml:7-16`.
   - Julian YYDDD → DATE, **Y2K pivot 49**: `:35-38`.
   - Postcode DQ "variant A" (repairs space then regex): `:41-45`.
   - Active flag per **Underwriting** definition (`IF`/`RN`): `:48-50`.
   - `CLIENT_NO → PARTY_ID` crosswalk lookup `REF_DB.XREF_CLIENT_PARTY`, ~12% unmatched pass through NULL: `:53-58`.
   - Control‑M **ALB‑DWH‑0032**, depends on NDM arrival: `:79`.

2. **`wf_CLAIMS_FNOL_INTRADAY`** — Guidewire CC ∪ LEGACY_CLM → `CLAIMS_DB.CLAIM`.
   - Loss‑date bug: assumes Guidewire MM/DD/YYYY (INC0067812): `wf_CLAIMS_FNOL_INTRADAY.xml:9`.
   - Fraud flag `'S'` → **`'N'`** here: `:15-17`.
   - Cyclic 30 min, Control‑M **ALB‑DWH‑0047**: `:28`.

3. **`wf_PARTY_MDM_SYNC`** — POLARIS PARTY → MDM hub golden record.
   - Survivorship: most‑recent‑update wins, **except email = longest string**: `wf_PARTY_MDM_SYNC.xml:7`.
   - Email DQ "variant B" (lowercase + full regex): `:9-12`.
   - NINO masking (marts only): `:15-17`.
   - NAME+DOB fuzzy match to APF; 55% rate; 41k unworked suspects: `:7`, `:20`.
   - Nightly 01:30 Control‑M **ALB‑MDM‑0003**; "must finish before `wf_POLICY_MASTER_DAILY` … relies on runtime luck": `:28` (race — see §1.7).

4. **`wf_BILLING_PREMIUM_RECON`** — written vs collected vs earned.
   - **Earned premium 1/24ths**: `wf_BILLING_PREMIUM_RECON.xml:8`,`:10-14`.
   - IPT 12% **hardcoded** (`POLICY.IPT_RATE` unused): `:17-19`.
   - APF banking↔insurance join FK‑by‑convention, ~3% orphans dropped: `:22`.
   - Monthly WD1 22:00 Control‑M **ALB‑FIN‑0012**: `:28`.

5. **`wf_REINSURANCE_BORDEREAUX_MONTHLY`** — broker bordereaux → outward Lloyd's bordereau.
   - Re‑key `AL/MOT/9999999` → `ALB-MOT-9999999`: `wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:9-11`.
   - Strip `£` + commas from text amounts: `:14-16`.
   - **SII LoB map DRIFTED** vs SAS (PET → 'Other motor' here): `:19-22` (see Deliverable 4).

**Supporting objects:**
- DQ mapplet `mplt_DQ_PARTY_STANDARDISE` (name/phone/postcode; references three postcode engines + a 4th GSS US‑format variant): `informatica/mapplets/mplt_DQ_PARTY_STANDARDISE.xml:6`.
- Parameter files: `informatica/parameter_files/wf_BILLING_PREMIUM_RECON.par`, `wf_PARTY_MDM_SYNC.par`, `wf_POLICY_MASTER_DAILY.par`.
- Scripts: `informatica/scripts/run_wf_policy_master` (pmcmd kick), `informatica/scripts/bdx_transfer` (ksh SFTP).

## 1.3 Informatica — legacy Group Shared Services (`informatica/legacy_shared_services/`)

Authentic rebranded PowerCenter 9.6 HR/payroll exports (FD-009). **3 workflows:**
- `wf_COMPTIME` — folder `COMP_TIME`: `legacy_shared_services/XML/wf_GSS_COMPTIME.xml:5`.
- `wf_EHRP2BIIS_UPDATE` — folder `EHRP2BIIS`: `wf_GSS_EHRP2BIIS_UPDATE.xml:5`.
- `wf_Pay_Calendar` — folder `Pay_Calendar`: `wf_GSS_PAY_CALENDAR.xml:5`.

**Transfer/utility scripts** (`legacy_shared_services/scripts/`): `actstage_load`,
`afps_transfer`, `archive_files`, `cdc_transfer`, `ehrp2biis_afterload.sql`,
`ehrp2biis_preload`, `fda_transfer`, `nih_cpm_transfer`, `nih_les_transfer`,
`nih_transfer_les`, `oig_transfer`, `remove_file`. All are ksh SFTP skeletons —
`bdx_transfer` was cloned from `cdc_transfer` (`informatica/scripts/bdx_transfer:6`).
Note plaintext credential handling in `ehrp2biis_preload:15-18` (`.pw`/`.use` files).
These carry raw **SSN** as join keys (741 refs in `wf_GSS_EHRP2BIIS_UPDATE.xml`), the
claimed ancestor of NINO masking (see Deliverable 4, DQR-021).

## 1.4 SAS estate

**Banking / Premium Finance (`sas/premium_finance/`):** `01_sas_customer_segments`,
`02_sas_txn_analytics`, `03_sas_risk_scoring`, `04_sas_data_products`, orchestrated by
`run_sas_pipeline.sh`. Risk model emits **RISK_SCORE 0–1 probability** (`03_sas_risk_scoring.sas:122-139`).

**Insurance (`sas/claims_fraud|actuarial|regulatory|customer/`):** orchestrated by
`sas/run_insurance_sas_pipeline.sh:16-20`.
- `05_claims_fraud_scoring.sas` — fraud **0–1000** scale (`:10-13`,`:69-83`); joins **raw NINO** (AR‑118) `:32-38`.
- `06_reserving_triangles.sas` — chain ladder; **365ths** earned premium (`:10-11`,`:30-33`); reads the **separate actuarial mainframe copy** `:5-6`,`:17`.
- `07_ibnr_projection.sas` — IBNR = ultimate − reported; tail factor 1.05 hardcoded `:24-27`.
- `08_solvency_ii_qrt_prep.sas` — QRT S.05.01/S.19.01; **SII LoB map drifted** vs Informatica `:11-14`,`:23-31`.
- `09_policyholder_segmentation.sas` — **cloned** from banking `01_sas_customer_segments` (`:4-9`); dual segment labels for overlapping people.

**Macros (`sas/macros/`):** `check_uk_postcode`, `mask_nino`, `julian_to_date`,
`validate_policy`, `validate_table`, `connect_teradata`, `log_step` (DQ engines — see Deliverable 4).

## 1.5 Teradata BTEQ (`teradata/bteq`) & DDL (`teradata/ddl`)

- **Banking staging 01–03** (`01_stg_customer_360`, `02_stg_txn_summary`, `03_stg_risk_factors`), run by `run_bteq_pipeline.sh`.
- **Insurance staging 04–06** (`04_stg_policy_360`, `05_stg_claims_summary`, `06_stg_earned_premium`), run by `run_insurance_bteq.sh`.
  - `04` **cloned from `01`** and diverged (`04_stg_policy_360.bteq:8-9`, CR‑2021‑088); Finance active flag `:35-40`; **1/12ths** earned `:44-49`; postcode DQ (requires space) `:51-57`; email DQ (`@` only) `:59-61`.
  - `05` loss‑date DD/MM/YYYY (INC0067812) `:7-11`,`:30`; fraud `'S'` → **`'Y'`** `:44-47`.
  - `06` **1/12ths** earned `:6-9`,`:27-29`; UW active filter (`IF`/`RN`) `:44`.
- **DDL:** `00_source_tables` (banking), `01_staging_tables` (`STG_CUSTOMER_360/TXN_SUMMARY/RISK_FACTORS`), `02_data_product_tables` (4 banking products), `03_insurance_source_tables` (PARTY/POLICY/CLAIM/PREMIUM_TRANSACTIONS/BROKER/TREATY + **manual `REF_DB.XREF_CLIENT_PARTY`** `03_insurance_source_tables.sql:96-104`), `04_life_db` (`LIFE_POLICY` + view `V_LIFE_POLICY` with **pivot 40** `04_life_db.sql:20-26`).

## 1.6 Mainframe (`mainframe/`) & AS/400 life (`as400_life/`)

- `copybooks/PLCYMSTR.cpy` — policy master, postcode 88‑level first‑char‑alpha (PR4471) `:28-30`; active 88‑levels `:19-27`.
- `copybooks/CLMHIST.cpy` — claim history; loss DDMMYYYY `:8-11`; fraud `'S'` no Guidewire equivalent `:20-23`.
- `jcl/PLCYEXTR.jcl` — extract STEP010 `:10-15`; **STEP020 REPRO the actuarial copy (CR‑2014‑311)** `:17-26`.
- `feed_specs/PLCYMSTR_feed_spec.md` — layout + known issues `:12-26`.
- `as400_life/LIFE400/` — real ILE COBOL/CL/DDS admin system (POLMST, CLMPF, `POLDATA.cpy`). Life status domain `POLDATA.cpy:22-30`; dates 8‑digit YYYYMMDD on the AS/400 `:19`,`:56`,`:109` (truncated to YYMMDD only at extract).
- `as400_life/extracts/LIFEXTR.clle` — nightly `CPYTOIMPF` + FTP plaintext; **dates truncated to YYMMDD, pivot 40 agreed in a meeting, not in spec** `:6-9`; **no address/postcode — ADDRMST descoped, GDPR SAR needs 5250** `:13-15`.
- `as400_life/feed_specs/POLMSTEX_feed_spec.md` — layout; `PM…` 5th id scheme `:11`; INSNAME no party key `:16`,`:23-25`; INSDOB pivot‑40 ambiguity `:17`.

## 1.7 Orchestration & known issues (cross‑checked)

- **Four schedulers in play**: Control‑M (`orchestration/controlm/ALBION_DWH_DAILY.xml`), cron (`orchestration/cron/crontab_prod.txt`), AS/400 ADDJOBSCDE (`LIFEXTR`/DLYUPD), and the DataStage Director scheduler (`datastage/README.md`).
- **Duplicate scheduling across Control‑M and cron**: policy workflow (`crontab_prod.txt:3` ALSO `ALB‑DWH‑0032`), insurance SAS (`crontab_prod.txt:5` ALSO `ALB‑DWH‑0050`), and LIFE_POLICY_LOAD (`crontab_prod.txt:7`, below).
- **LIFE_POLICY_LOAD is triple‑scheduled**: cron `crontab_prod.txt:7`, Control‑M **ALB‑LIF‑0005** `ALBION_DWH_DAILY.xml:17`, **and** the DS Director — explicitly noted `crontab_prod.txt:7`.
- **75‑minute FTP gap, no file‑watcher** between AS/400 push (23:30) and DataStage: `ALBION_DWH_DAILY.xml:17-19`; upstream `LIFEXTR.clle:23-24`.
- **Undocumented cross‑pipeline kick** inside a ksh script: `informatica/scripts/run_wf_policy_master:32-33` calls `run_insurance_bteq.sh` ("should be Control‑M's job… added temporarily 2022"); also flagged in Control‑M description `ALBION_DWH_DAILY.xml:7`.
- **Nightly race condition** (MDM sync vs policy load): missing INCOND on `ALB‑MDM‑0003` `ALBION_DWH_DAILY.xml:8-10`; `wf_PARTY_MDM_SYNC.xml:28` ("relies on runtime luck"); `docs/architecture_overview.md:33-35`.
- **DQ‑bypassing duplicate actuarial feed**: `PLCYEXTR.jcl:17-26` (REPRO) consumed by `06_reserving_triangles.sas:5-6`,`:17`; CR‑2014‑311 in `docs/known_issues_register.md:8` and `docs/feed_inventory.md:6`.
- **Scheduler ownership overlap** (nobody owns `bdx_transfer`): `crontab_prod.txt:1-4`.
- **Plaintext FTP creds**: `LIFEXTR.clle:23`; `run_wf_policy_master:9-11` (`pmpasswd` in `/etc/profile.d`).

---

## 1.8 Gaps & discrepancies (repo vs. `docs/feed_inventory.md` / README claims)

| # | Claim | Repo reality | Evidence |
|---|---|---|---|
| G1 | FD-002 POLARIS CDC is an active Informatica CDC feed | No workflow export exists in `informatica/XML/` (only the 5 insurance workflows) | `docs/feed_inventory.md:7` vs `informatica/XML/` contents |
| G2 | FD-004 LEGACY_CLM extracted "per CLMHIST.cpy" via JCL | The `CLMEXTR` JCL is referenced but **not present**; only `PLCYEXTR.jcl` exists | `mainframe/copybooks/CLMHIST.cpy:3`; `docs/feed_inventory.md:9`; `mainframe/jcl/` |
| G3 | FD-011 has DataStage job exports | `LIFE_POLICY_LOAD` **.dsx is lost** — the load job that produces FD‑010's target is not in the repo | `datastage/README.md:13-16`; `docs/known_issues_register.md:17` |
| G4 | NINO masking descends from a GSS "Pseudossn" Informatica job | The three GSS exports carry **raw SSN as keys**; no pseudonymisation/masking job is present among them | `sas/macros/mask_nino.sas:4-6`; SSN refs in `wf_GSS_EHRP2BIIS_UPDATE.xml` (741) with no mask transform |
| G5 | DLYUPD lapse sweep is "nightly" | Scheduled **weekly** via ADDJOBSCDE | `glossary/life_operations_glossary.md:14-15` |
| G6 | DQR-030 policy status domain `(IF,RN,LP,CN,EX)` | LEGACY_PAS emits retired `CAR/HSE` products and status `PD` (life legacy) dropped silently | `dq_rules/dq_rules_registry.csv:5`; `glossary/underwriting_data_dictionary.csv:6` |
