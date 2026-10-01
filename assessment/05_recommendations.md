# Deliverable 5 — Recommendations: Canonical Domains & Governance

Target-state proposal derived from the Assess-phase findings (Deliverables 1–4). It
defines five canonical data domains, per-domain survivorship rules that resolve the
identity fragmentation, and single group standards for **earned premium** and
**active policy**, each with an accountable owner. Every recommendation is traced to
the evidence that motivates it.

Ownership model used below (RACI-style):
- **Domain Owner (A)** — accountable executive/function for the domain's definitions.
- **Data Steward (R)** — responsible for day-to-day rules, reference data, DQ.
- **Consuming functions (C/I)** — read the canonical product; may not redefine terms.

---

## 5.1 Canonical domains (overview)

| Domain | Canonical key | Replaces / unifies | Owner (A) | Steward (R) |
|---|---|---|---|---|
| **Party** | `PARTY_UID` (surrogate) | `CUSTOMER_ID`, `PARTY_ID`, `CLIENT_NO`, `customer_ref`, `MKTG_CUST_ID`, life name+DOB | Chief Data Officer | MDM / Party Data Steward |
| **Policy** | `POLICY_UID` (+ `policy_no_canonical`) | POLARIS `ALB-XXX-9999999`, mainframe hyphen-stripped, bordereaux `AL/…`, life `PM…` | Policy Platform Owner | Policy Data Steward |
| **Claim** | `CLAIM_UID` | Guidewire + LEGACY_CLM (IMS) | Claims Platform Owner | Claims Data Steward |
| **Premium** | `PREMIUM_TXN_UID` / `earned_premium` measure | BTEQ 1/12, INFA 1/24, SAS 365ths, Life API | Group Finance (ledger) + Group Actuarial (method) | Premium Data Steward |
| **Reinsurance** | `RI_RISK_UID` / `CEDED_UID` | broker bordereaux + treaty ceding | Reinsurance / Capital Owner | RI Data Steward |

Rationale for surrogate keys: no existing natural key spans the estate — six identity
schemes (`02_attribute_overlap_matrix.md §2.1`), the manual `REF_DB.XREF_CLIENT_PARTY`
(`teradata/ddl/03_insurance_source_tables.sql:96-104`) and the ~55%/keyless life book
(`informatica/XML/wf_PARTY_MDM_SYNC.xml:7`; `teradata/ddl/04_life_db.sql:16`) make any
source key unsafe as the spine.

---

## 5.2 Party domain

**Canonical entity.** `PARTY_UID` surrogate + `PARTY_ROLE` (banking-customer /
policyholder / claimant / life-assured / marketing-contact). Source keys retained as
*non-authoritative* cross-reference attributes, not as the spine.

**Attributes (canonical):** `full_name`, `dob` (ISO), `nino` (masked at rest — see DQ),
`postcode` (single validator), `email` (single validator), plus `xref_*` columns holding
each legacy id and its match confidence.

**Survivorship rules (deterministic, auditable — replaces "most-recent-wins EXCEPT email longest-string"):**
1. **Match** — deterministic first: exact NINO, then exact (name + DOB + postcode). Fuzzy
   only as a *candidate generator* feeding a suspect queue; fuzzy matches are **never**
   auto-merged. (Fixes `wf_PARTY_MDM_SYNC.xml:7` fuzzy auto-attach and the 41k unworked
   queue, `dq_rules/dq_rules_registry.csv:7`.)
2. **Attribute survivorship by source trust rank, not recency:** identity/legal fields
   (name, DOB, NINO) → POLARIS > LEGACY_PAS > LIFE400 > APF > marketing; contactability
   (email, phone) → most-recently-*verified* (not longest string); address → most-recent
   validated postcode. (Removes the undocumented longest-string email rule
   `wf_PARTY_MDM_SYNC.xml:7`.)
3. **Confidence & provenance stored per field** (`source_system`, `match_method`,
   `match_confidence`, `as_of`); every merge reversible.
4. **`MKTG_CUST_ID` in scope**: partner-loyalty parties must be matched into `PARTY_UID`
   (name+email today only, `datastage/README.md:18-21`) — stops the 6th silo.
5. **Life book onboarding**: `LIFE_POLICY_ID` parties matched via the same service, not a
   lost DataStage job (`datastage/README.md:13-16`); unmatched → suspect queue with SLA.

**Owner:** CDO (A) · MDM/Party Steward (R) · Finance, UW, Claims, Marketing (C).

---

## 5.3 Policy domain

**Canonical entity.** `POLICY_UID` surrogate + `policy_no_canonical` in one format,
plus `policy_no_source` + `source_format`. Normalise the four formats
(`02_attribute_overlap_matrix.md §2.3`): POLARIS `ALB-XXX-9999999`, mainframe
hyphen-stripped (`data/inbound_feeds/PLCYMSTR_D260115.dat`), bordereaux `AL/PET-0001559`
(`data/inbound_feeds/CLAIMS_BDX_BRK0007_202606.csv:2`), life `PM…`
(`teradata/ddl/04_life_db.sql:5`). Re-keying happens **once** in ingestion, replacing the
four scattered re-keys (`wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:9-11`;
`api_legacy/plsql/pkg_policy_inquiry.sql:28-29`).

**Canonical attributes:** `party_uid` (FK), `product_cd` (governed reference — retire
`CAR/HSE` leakage, `glossary/underwriting_data_dictionary.csv:6`), dates in ISO (single
Julian/century conversion, see §5.6), `annual_premium_gbp` (money normalised: pence
implied-decimal `mainframe/copybooks/PLCYMSTR.cpy:16-17`, £-text
`wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:14-16`), `policy_status` (single domain),
`inforce_flag` (§5.5).

**Survivorship:** one policy record per `POLICY_UID`; when POLARIS and LEGACY_PAS both
carry a policy, POLARIS is system-of-record for policy terms, LEGACY_PAS for historic
premium/paid-to-date; life policies remain a distinct product line under the same key
space.

**Owner:** Policy Platform (A) · Policy Steward (R) · Finance, Actuarial, RI (C).

---

## 5.4 Claim domain

**Canonical entity.** `CLAIM_UID` + `policy_uid`, `policyholder_party_id`,
`claimant_party_id` **kept distinct** (fixes back-filled claimant caveat
`glossary/claims_glossary.md:16-17`).

**Canonical attributes:** `date_of_loss` and `date_of_notification` as separate ISO
fields (ends the "incurred in month" ambiguity `glossary/claims_glossary.md:6-9` and the
US/UK loss-date bug INC0067812 `wf_CLAIMS_FNOL_INTRADAY.xml:9`,
`teradata/bteq/05_stg_claims_summary.bteq:7-11`); `claim_status` single domain;
`fraud_status` as a **three-value** domain `CONFIRMED/SUSPECTED/NONE` — never collapsed
to Y/N (fixes `'S'`→`'N'` vs `'S'`→`'Y'` split `wf_CLAIMS_FNOL_INTRADAY.xml:15-17` vs
`05_stg_claims_summary.bteq:44-47`); `fraud_referral_score` 0–1000 kept separate from
banking `credit_default_probability` 0–1 (`§5.7`).

**Survivorship:** one operational and one analytical store must read the **same**
harmonisation service (no divergent INFA/BTEQ mappings); Guidewire is SoR for open
claims, LEGACY_CLM (IMS) for closed legacy history.

**Owner:** Claims Platform (A) · Claims Steward (R) · Actuarial, SIU, Finance (C).

---

## 5.5 Active-policy — single canonical definition

**Problem:** four+ concurrent definitions (`03_glossary_reconciliation.md §3.2`):
Finance `IF`+45-day collection (`glossary/finance_data_dictionary.csv:2`;
`teradata/bteq/04_stg_policy_360.bteq:35-40`), UW `IF`/`RN`
(`wf_POLICY_MASTER_DAILY.xml:48-50`), Claims any open claim
(`glossary/claims_glossary.md:3-5`), copybook 88-level (`mainframe/copybooks/PLCYMSTR.cpy:24-27`),
Life `AC/GR/RS` (`glossary/life_operations_glossary.md:5-8`).

**Canonical:** one **structural** flag + named derived measures — stop overloading "active".
- `policy_inforce` = `policy_status IN ('IF','RN')` (P&C) **or** `CONTRACT_STATUS IN ('AC','GR','RS')` (Life). **Single source of the word "active".**
- `policy_paying` = `policy_inforce` AND a collection in the last 45 days *(Finance's measure, renamed).*
- `policy_with_open_claim` = ≥1 OPEN/REOPENED claim *(Claims' measure, renamed).*

**Owner:** Policy Platform owns `policy_inforce` (A); Finance owns `policy_paying`,
Claims owns `policy_with_open_claim` (R for their derived measure). Board/regulatory
in-force counts use `policy_inforce` only.

---

## 5.6 Earned-premium — single canonical definition

**Problem:** 1/12 (Finance BTEQ `teradata/bteq/06_stg_earned_premium.bteq:6-9`), 1/24
(INFA `wf_BILLING_PREMIUM_RECON.xml:8`,`:10-14`), 365ths (Actuarial
`sas/actuarial/06_reserving_triangles.sas:10-11`), plus Life API summed into a Group KPI
(`glossary/life_operations_glossary.md:9-11`; `docs/known_issues_register.md:22`).

**Canonical:** **daily pro-rata 365ths** computed **once** in the warehouse as
`earned_premium`, consumed unchanged by Finance close, QRT and Board packs. IPT from a
single reference rate (`POLICY.IPT_RATE`), retiring the three hardcoded 12% copies
(`wf_BILLING_PREMIUM_RECON.xml:17-19`; `teradata/bteq/06_stg_earned_premium.bteq:26`;
`glossary/finance_data_dictionary.csv:7`). **Life API stays a separate, labelled
measure** (`annualised_premium_in_force`) and is **never** added to an earned-premium KPI;
any group premium KPI must show P&C earned premium and Life API as distinct lines.

**Owner:** Group Actuarial owns the methodology (A/R); Group Finance owns ledger
reconciliation and the IPT reference rate (R); the manual monthly XLS true-up
(`sas/regulatory/08_solvency_ii_qrt_prep.sas:8-10`) is retired.

---

## 5.7 Reinsurance domain

**Canonical entity.** `RI_RISK_UID` (inward risk from bordereaux) and `CEDED_UID`
(outward cession), both FK to `POLICY_UID`/`CLAIM_UID` via the canonical policy re-key.

**Canonical attributes:** amounts normalised from £-and-comma text once
(`wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:14-16`); **single governed `REF_DB.SII_LOB_MAP`**
consumed by *both* the QRT (SAS) and outward bordereau (INFA), ending the PET LoB drift
(`sas/regulatory/08_solvency_ii_qrt_prep.sas:23-31` vs
`wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:19-22`), enforced by a cross-engine equality test;
treaty reference data (quota-share terms) mastered centrally rather than in 14 hand-kept
broker column maps (`wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:7`).

**Survivorship:** one canonical `sii_lob` per product from the shared map; broker feed
timeliness (e.g. BRK0007 habitual lateness `wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:25`)
handled by an ingestion SLA, not manual restart runbooks.

**Owner:** Reinsurance/Capital (A) · RI Steward (R) · Actuarial, Regulatory Reporting (C).

---

## 5.8 Cross-cutting survivorship & DQ standards (enablers)

| Standard | Canonical rule | Retires |
|---|---|---|
| **Century/Julian** | one shared date service, single pivot, ISO output | pivots 49/50/40 (`wf_POLICY_MASTER_DAILY.xml:37`; `sas/macros/julian_to_date.sas:12`; `teradata/ddl/04_life_db.sql:22`) |
| **Postcode** | one validator service (repair-then-validate, case-insensitive) | 5 variants (`04_dq_registry_diff.md §4.2`) |
| **Email** | one validator applied on every ingest | 2 engines + banking gap (`dq_rules/dq_rules_registry.csv:2`) |
| **NINO** | mask/tokenise at ingest; analytics join on token, never raw | AR-118 raw join (`sas/claims_fraud/05_claims_fraud_scoring.sas:32-38`) |
| **DQ registry** | registry is the SoR; every rule has exactly one implementation + a conformance test; unregistered rules removed or registered | drift/duplication (`04_dq_registry_diff.md §4.7`) |

**DQ/registry owner:** CDO office / Data Governance (A) · per-domain stewards (R).

---

## 5.9 Owner mapping (summary)

| Definition / asset | Accountable owner | Responsible steward |
|---|---|---|
| `PARTY_UID` + survivorship | CDO | MDM/Party Steward |
| `POLICY_UID` + policy re-key | Policy Platform | Policy Steward |
| `CLAIM_UID` + fraud/date domains | Claims Platform | Claims Steward |
| `earned_premium` (365ths) method | Group Actuarial | Premium Steward |
| Earned-premium ledger recon + IPT rate | Group Finance | Premium Steward |
| `policy_inforce` (canonical active) | Policy Platform | Policy Steward |
| `policy_paying` / `policy_with_open_claim` | Finance / Claims | resp. stewards |
| `REF_DB.SII_LOB_MAP` + RI domain | Reinsurance/Capital | RI Steward |
| Shared date/postcode/email/NINO services + DQ registry | Data Governance (CDO office) | domain stewards |

> **Sequencing note:** Party is the critical-path domain — Policy/Claim/Premium/RI all
> FK to `PARTY_UID`. Recommend delivering the Party MDM survivorship service and the
> canonical policy re-key first, then the single earned-premium/active-policy measures,
> before retiring LIFE400/DataStage (`01_feed_inventory.md §1.8`).
