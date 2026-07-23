# Deliverable 4 — DQ Registry vs. Actual Implementations

The DQ registry (`dq_rules/dq_rules_registry.csv`, 7 rules) and the ad-hoc SQL pack
(`dq_rules/sql/dq_checks_claims.sql`) are diffed against the actual code across
Informatica, SAS, BTEQ, PL/SQL, mainframe COBOL and AS/400. Each rule is classified
**Implemented / Registry-only / Implemented-but-unregistered (gap)**, with drift noted.

---

## 4.1 Rule-by-rule diff

| Rule | Registry says | Actual implementations | Classification |
|---|---|---|---|
| **DQR-007 Email** | INFA `EXP_EMAIL_DQ` only | INFA regex+lowercase (`wf_PARTY_MDM_SYNC.xml:9-12`); BTEQ `@`‑only (`04_stg_policy_360.bteq:59-61`); banking pipeline **none** (`dq_rules_registry.csv:2`) | 2 engines + 1 **unregistered gap** |
| **DQR-014 Postcode** | INFA variant A + BTEQ | 4 P&C engines (all differ) + LIFE400 has no field (§4.2) | drift across **5 variants** |
| **DQR-021 NINO masking** | INFA `EXP_NINO_MASK` | INFA marts‑only (`wf_PARTY_MDM_SYNC.xml:15-17`); SAS `mask_nino` output‑only w/ **raw‑join bypass AR‑118** (§4.3) | PARTIAL + bypass |
| **DQR-030 Policy status domain** | none registered | LEGACY_PAS emits retired `CAR/HSE` + status `PD` dropped by SQ filter | **unregistered / DRAFT**, `dq_rules_registry.csv:5` |
| **DQR-033 Loss date not future** | BTEQ 05 (commented out 2022) | no active impl; ad‑hoc pack re‑implements it (`dq_checks_claims.sql:4-8`) | SUSPENDED + shadow ad‑hoc |
| **DQR-041 Party duplicate** | MDM survivorship | 55% match; 41k suspects; life name+DOB fuzzy; MKTG never crosswalked | ACTIVE but ineffective, `dq_rules_registry.csv:7` |
| **DQR-052 Century pivot** | none | pivot 49 / 50 / 40 in 3+ places (§4.4) | **unregistered / DRAFT** drift |

Additional **unregistered** DQ logic found in code: fraud‑flag mismatch check and
earned‑premium tri‑reconciliation in the ad‑hoc pack (`dq_checks_claims.sql:17-26`),
duplicate‑key check silently skipped >1m rows (`validate_policy.sas:26-28`, CR‑2022‑410),
and the APF orphan‑match ~3% drop (`wf_BILLING_PREMIUM_RECON.xml:22`).

---

## 4.2 DQR-014 Postcode — FOUR engines (all different) + a 5th LIFE400 variant

| # | Engine | Behaviour | Evidence |
|---|---|---|---|
| A | Informatica `EXP_POSTCODE_DQ` | **auto‑repairs** a missing space (inserts before final 3 chars), uppercases, then `REG_MATCH` — most permissive | `wf_POLICY_MASTER_DAILY.xml:41-45` |
| B | BTEQ `04_stg_policy_360` | **requires** an embedded space (`LIKE '% %'`) + first char alpha; upper‑cases | `04_stg_policy_360.bteq:51-57` |
| C | SAS `check_uk_postcode.sas` | full PRX pattern, **case‑SENSITIVE** (rejects lowercase); **never registered** | `sas/macros/check_uk_postcode.sas:6-9`,`:16-17` |
| D | COBOL `PLCYMSTR` 88‑level | **first char alpha only** (PR4471) — weakest | `mainframe/copybooks/PLCYMSTR.cpy:28-30` |
| E | LIFE400 | **no postcode field at all** — addresses stranded in ADDRMST (GDPR SAR impact) | `as400_life/extracts/LIFEXTR.clle:13-15`; `docs/feed_inventory.md:33-35` |

**How they differ on the same input:** `ec1a 1bb` → A repairs/validates VALID, B fails
(lowercase first‑char test passes but case handling differs), C **rejects** (lowercase),
D passes (first char alpha). `EC1A1BB` (no space) → A repairs to VALID, B **fails**
(no space), C fails (no space), D passes. Documented in the SAS macro header
(`check_uk_postcode.sas:6-9`) and BTEQ comment (`04_stg_policy_360.bteq:51-54`). The
registry lists only A and B (`dq_rules_registry.csv:3`); C and D are **unregistered**.
A **4th standardiser variant** (US‑format, applied to UK addresses since a 2018 copy‑paste)
lives in the GSS estate per `mplt_DQ_PARTY_STANDARDISE.xml:6`.

---

## 4.3 DQR-021 NINO masking — 2 stacks + raw-join bypass (AR-118)

| Stack | Behaviour | Evidence |
|---|---|---|
| Informatica `EXP_NINO_MASK` | masks `first2 + '*****' + last2`, **marts only**; SAS reads raw upstream | `wf_PARTY_MDM_SYNC.xml:15-17` |
| SAS `mask_nino.sas` | same shape, but applied **on OUTPUT only** | `sas/macros/mask_nino.sas:11-19` |
| **Bypass (AR‑118)** | `05_claims_fraud_scoring.sas` **joins on raw `PARTY.NINO`** "for match quality"; masking applied only to the published dataset | `05_claims_fraud_scoring.sas:5`,`:32-38`,`:85`; `docs/known_issues_register.md:6` |

**Drift:** the two masks are structurally the same but maintained separately; more
importantly the SAS fraud pipeline defeats the control by joining raw NINO before
masking (accepted risk, DPIA 2022, never remediated). **Lineage gap (G4):** the registry
and `mask_nino.sas:4-6` claim descent from a GSS "Pseudossn" Informatica job, but the
three GSS exports carry **raw SSN as join keys** with no masking transform present.

---

## 4.4 Julian / century conversion — 3 places, THREE pivot years (DQR-052)

| Impl | Pivot | Evidence |
|---|---|---|
| Informatica `EXP_POLICY_DATES` | **49** (`<=49 ⇒ 20xx`) | `wf_POLICY_MASTER_DAILY.xml:37` |
| SAS `julian_to_date.sas` (actuarial) | **50** (`<=50 ⇒ 20xx`) | `sas/macros/julian_to_date.sas:12` |
| LIFE400 / DataStage / `V_LIFE_POLICY` | **40** (`>=40 ⇒ 19xx`) | `teradata/ddl/04_life_db.sql:22`; `as400_life/extracts/LIFEXTR.clle:9`; `POLMSTEX_feed_spec.md:5-7` |

**Drift:** a policy/DOB with two‑digit year 49/50 resolves to different centuries
across the actuarial and DWH views (`julian_to_date.sas:4-7`). Life DOBs 1925–1939 are
at risk of a **+100y shift** under pivot 40 (`docs/known_issues_register.md:18`;
`POLMSTEX_feed_spec.md:17`). Registry lists DQR‑052 as **DRAFT with no implementation**
(`dq_rules_registry.csv:8`).

---

## 4.5 Related date drift — INC0067812 (loss-date US/UK)

Not a registry rule but the same class of drift: Informatica parses Guidewire loss
dates as **MM/DD/YYYY** while BTEQ treats the field as **DD/MM/YYYY**; ~40% of claims
diverge for day ≤ 12. Evidence: `wf_CLAIMS_FNOL_INTRADAY.xml:9`;
`05_stg_claims_summary.bteq:7-11`,`:30`; `docs/known_issues_register.md:5`;
`actuarial_definitions.md:12-14`.

---

## 4.6 SII Line-of-Business mapping drift (SAS vs Informatica)

| Impl | `PET` maps to | Evidence |
|---|---|---|
| SAS `08_solvency_ii_qrt_prep.sas` | **'Miscellaneous financial loss'** | `sas/regulatory/08_solvency_ii_qrt_prep.sas:23-31` |
| Informatica `LKP_SII_LOB` | **'Other motor'** (2023 fat‑finger; "simply wrong") | `wf_REINSURANCE_BORDEREAUX_MONTHLY.xml:19-22` |

**Impact:** the QRT (from SAS) and the outward bordereau (from Informatica) report PET
under **different Solvency II LoBs**; undetected (`docs/known_issues_register.md:13`).
Not in the DQ registry — an **unregistered consistency gap**. Canonical fix: single
governed `REF_DB.SII_LOB_MAP` consumed by both, with a cross‑engine equality test.

---

## 4.7 Summary counts

- Registry rules: **7** (`dq_rules_registry.csv`). Implemented as written: **0** cleanly
  (all show drift, partial coverage, suspension, or missing implementation).
- Registry‑only / DRAFT / SUSPENDED with no active impl: **DQR‑030, DQR‑033, DQR‑052**.
- Implemented‑but‑unregistered: SAS postcode (C), COBOL postcode (D), fraud‑flag mismatch
  check, earned‑premium tri‑recon, duplicate‑key skip, APF orphan drop, **SII LoB drift**.
- Highest‑risk findings: **AR‑118 raw‑NINO join** (DPO), **SII LoB drift** (regulatory),
  **three Y2K pivots** (data correctness), **postcode 5‑variant sprawl** (GDPR/matching).
