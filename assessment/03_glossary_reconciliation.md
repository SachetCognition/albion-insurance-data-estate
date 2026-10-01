# Deliverable 3 — Glossary Reconciliation

Term-by-term reconciliation of the four conflicting business glossaries plus the
Life Operations glossary, with each community's definition, the conflict flagged,
and a canonical-definition candidate. All definitions cite file/line evidence.

Sources:
- Finance — `glossary/finance_data_dictionary.csv`
- Underwriting — `glossary/underwriting_data_dictionary.csv`
- Claims MI — `glossary/claims_glossary.md`
- Actuarial — `glossary/actuarial_definitions.md`
- Life Ops (Provident Mutual) — `glossary/life_operations_glossary.md`

---

## 3.1 Earned Premium — FOUR methodologies + a Group KPI error

| Community | Definition | Evidence |
|---|---|---|
| Finance | GWP straight‑line **monthly (1/12ths)** from inception | `finance_data_dictionary.csv:3`; BTEQ `06_stg_earned_premium.bteq:6-9`,`:27-29`; `04_stg_policy_360.bteq:44-49` |
| Billing recon (INFA) | **1/24ths** (assumes mid‑month inception) | `informatica/XML/wf_BILLING_PREMIUM_RECON.xml:8`,`:10-14` |
| Actuarial | daily pro‑rata **365ths**; authoritative for reserving/pricing/SFCR | `actuarial_definitions.md:3-7`; `06_reserving_triangles.sas:10-11`,`:30-33` |
| Underwriting | "not a UW measure" — but rate monitoring uses the actuarial 365ths | `underwriting_data_dictionary.csv:4` |
| Life Ops | does not use earned premium; measures **Annualised Premium In Force (API)** = `MODAL_PREMIUM × PAY_FREQ` | `life_operations_glossary.md:9-11`; view `04_life_db.sql:25` |

**Conflicts:**
- Three concurrent earned‑premium methods differ by up to **1.8% by product** at year‑end (`actuarial_definitions.md:6-7`); month‑end reconciliation is a manual XLS (`06_stg_earned_premium.bteq:9`).
- The QRT combines Finance 1/12ths premium with 365ths‑derived ultimates → combined ratio never ties, "true‑up" journal (`08_solvency_ii_qrt_prep.sas:8-10`).
- **Group Premium KPI adds Life API to P&C earned premium** — methodologically incompatible (`life_operations_glossary.md:10-11`; `docs/known_issues_register.md:22`).

**Canonical candidate:** single **daily 365ths earned premium** as the group standard
(align Finance/Billing to actuarial), computed once in the warehouse and consumed by
QRT and Board packs; keep **API** as a *distinct, separately‑labelled* life measure
that is **never summed** into an earned‑premium KPI. Owner: Group Actuarial (methodology)
+ Finance MI (ledger reconciliation).

---

## 3.2 "Active Policy" — FOUR concurrent P&C definitions + a 5th for Life

| Community | Definition | Evidence |
|---|---|---|
| Finance | status `IF` **and** a premium collection in last **45 days** | `finance_data_dictionary.csv:2`; `04_stg_policy_360.bteq:35-40` |
| Underwriting | status `IF` **or** `RN`, irrespective of collections | `underwriting_data_dictionary.csv:2`; `wf_POLICY_MASTER_DAILY.xml:48-50`; `06_stg_earned_premium.bteq:44` |
| Claims MI | any policy with ≥1 OPEN/REOPENED claim, **including cancelled** | `claims_glossary.md:3-5` |
| Mainframe (88‑levels) | `PLCY-ACTIVE` = `IF`/`RN` (UW view baked into copybook) | `mainframe/copybooks/PLCYMSTR.cpy:24-27` |
| Life Ops | `CNTRSTS in ('AC','GR','RS')`; Finance count only `AC` for group in‑force | `life_operations_glossary.md:5-8`; `04_life_db.sql:9` |

**Conflict:** four P&C answers to the same question (Finance/UW/Claims + the copybook's
UW‑baked 88‑level), plus a distinct life status domain that does not align to the P&C
domain. Unresolved since 2019 (`docs/known_issues_register.md:12`). Note the copybook
even documents "DO NOT RECONCILE THESE TWO NUMBERS" (`PLCYMSTR.cpy:26-27`).

**Canonical candidate:** define **`policy_inforce`** = status `IF`/`RN` (or life `AC`)
as the single structural flag, and express the others as *named derived measures*:
`policy_paying` (Finance's collections test), `policy_with_open_claim` (Claims), and a
mapped life status. Never overload the word "active". Owner: a cross‑community data
council; structural flag owned by Policy Platform.

---

## 3.3 Risk / Fraud score scales — two incompatible scales on one dashboard

| Community | Scale | Evidence |
|---|---|---|
| APF banking risk | `RISK_SCORE` **0–1 probability** of default | `03_sas_risk_scoring.sas:122-139`,`:168` |
| Claims SIU fraud | `FRAUD_SCORE` **0–1000**; referral ≥ 650 | `05_claims_fraud_scoring.sas:10-13`,`:80-82`; `claims_glossary.md:13-15` |

**Conflict:** both surfaced side‑by‑side in the Qlik "Customer Risk" dashboard for
overlapping customers with **no rescaling** (`05_claims_fraud_scoring.sas:11-13`;
`docs/architecture_overview.md:27`).

**Canonical candidate:** keep the two scores as *distinct, explicitly‑named metrics*
(`credit_default_probability` 0–1 and `fraud_referral_score` 0–1000) with a governed
display rule forbidding them on a shared axis; if a blended view is needed, define a
separate normalised `customer_risk_index`. Owner: MI/BI governance.

---

## 3.4 Fraud flag `'S'` — mapped opposite ways

| Pipeline | Mapping of `'S'` (suspected) | Evidence |
|---|---|---|
| Informatica claims load | `'S'` → **`'N'`** | `wf_CLAIMS_FNOL_INTRADAY.xml:15-17` |
| BTEQ claims staging | `'S'` → **`'Y'`** | `05_stg_claims_summary.bteq:44-47` |
| Source (IMS copybook) | `'S'` = fraud‑suspected; Guidewire has no equivalent | `mainframe/copybooks/CLMHIST.cpy:20-23` |

**Conflict:** operational store (INFA) and analytical store (BTEQ) disagree for every
`'S'` claim → fraud MI counts diverge; the ad‑hoc pack even measures the mismatch
(`dq_rules/sql/dq_checks_claims.sql:17-22`).

**Canonical candidate:** preserve a **three‑value domain** end‑to‑end
(`CONFIRMED`/`SUSPECTED`/`NONE`) rather than collapsing to Y/N; downstream consumers
choose their own inclusion rule explicitly. Owner: Claims Platform + Claims MI.

---

## 3.5 Other reconciliation items

| Term | Divergence | Evidence | Canonical candidate |
|---|---|---|---|
| **Incurred / "in month"** | Claims use `LOSS_DT`; Finance recognise on `NOTIFICATION_DT` | `claims_glossary.md:6-9` | Separate `date_of_loss` vs `date_of_notification`; ban unqualified "incurred in month" |
| **Customer vs Policyholder** | Finance "Customer"=APF banking `CUSTOMER_ID`; UW "Policyholder"=`PARTY_ID`/`CLIENT_NO`; Life=`INSNAME` free text | `finance_data_dictionary.csv:4`; `underwriting_data_dictionary.csv:3`; `life_operations_glossary.md:12-13` | Canonical **Party** domain with role attributes (banking‑customer / policyholder / claimant) |
| **Product code** | 6 live (MOT/HOM/PET/TRV/CPM/CLB); LEGACY_PAS emits retired `CAR/HSE`, mapping table lost/hardcoded | `underwriting_data_dictionary.csv:6` | Governed product reference table; retire hardcoded session pre‑SQL |
| **IPT** | 12% hardcoded in 3 codebases + 1 unused parameter | `finance_data_dictionary.csv:7`; `wf_BILLING_PREMIUM_RECON.xml:17-19`; `06_stg_earned_premium.bteq:26`; `docs/known_issues_register.md:15` | Single reference rate; use `POLICY.IPT_RATE` everywhere |
| **Claimant** | `CLAIMANT_PARTY_ID` back‑filled from policy party for legacy claims (may not be the actual claimant) | `claims_glossary.md:16-17` | Distinguish `policyholder_party_id` from `claimant_party_id`; flag back‑filled rows |
