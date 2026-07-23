# Albion General Insurance Group — Legacy Data Estate (Demo Monorepo)

A deliberately convoluted, realistic single-repo snapshot of a mid-size UK
composite insurer's analytical data estate, assembled for **AI-assisted
assessment and modernization demos** (e.g. Devin).

Albion General acquired **Albion Premium Finance (APF)** — a retail
banking/premium-finance business — in 2016, and **Provident Mutual** in the
same year, bringing both its P&C book (mainframe LEGACY_PAS/LEGACY_CLM) and a
**term-life book still administered on a never-rebranded AS/400 system
(LIFE400)**. A 2013-era **DataStage** estate serves marketing/affinity
("Retail Partnerships") and — because a contractor wired it that way in 2016 —
is also the only bridge between the life system and the group warehouse. The estate therefore
spans **Informatica PowerCenter, SAS 9.4, Teradata BTEQ, IBM DataStage 9.1,
mainframe COBOL/JCL feeds, AS/400 ILE COBOL/CL/DDS, Oracle PL/SQL and a frozen
SOAP API**, with three business
communities (Finance, Underwriting/Claims, Actuarial) each owning their own
definitions of the same concepts.

## Layout
```
informatica/            5 insurance PowerCenter workflow exports, DQ mapplet,
                        parameter files, pmcmd/ksh scripts
informatica/legacy_shared_services/
                        REAL legacy PowerCenter exports + transfer scripts
                        (Group Shared Services HR/payroll estate)
sas/premium_finance/    Banking analytics pipeline (segments, txn, risk, golden record)
sas/claims_fraud|actuarial|regulatory|customer/
                        Insurance SAS estate (fraud 0-1000, chain ladder, IBNR,
                        Solvency II QRT prep, policyholder segmentation clone)
teradata/bteq           01-03 banking staging + 04-06 insurance staging (divergent clones)
teradata/ddl            Source/staging/product DDL, incl. manual XREF crosswalk table
mainframe/              PLCYMSTR + CLMHIST copybooks, JCL, feed specs
as400_life/LIFE400/     REAL AS/400 term-life admin system (ILE COBOL, CL, DDS,
                        5250 display files) - Provident Mutual, never rebranded
as400_life/extracts     LIFEXTR nightly extract CL + POLMSTEX feed spec (YYMMDD, pivot 40)
datastage/              REAL InfoSphere DataStage .dsx job exports (Retail
                        Partnerships marts, Bouns_Program) + the lost-source
                        LIFE_POLICY_LOAD story; MKTG_CUST_ID identity silo
api_legacy/             PL/SQL policy inquiry package + rpc/encoded WSDL (2011)
dq_rules/               DQ registry (incomplete on purpose) + ad-hoc SQL pack
orchestration/          Control-M export, cron dump (overlapping ownership), master scripts
glossary/               4 conflicting business glossaries (Finance/UW/Claims/Actuarial)
data/                   Synthetic source CSVs, fixed-width mainframe feed sample,
                        broker bordereaux sample, staged/product outputs
docs/                   Feed inventory, architecture, known-issues register
```

## Engineered assessment findings (ground truth)
An AI assessment of this repo should be able to surface, with file-level evidence:

1. **Identity fragmentation** — SIX schemes: CUSTOMER_ID / PARTY_ID /
   CLIENT_NO / customer_ref / LIFE_POLICY_ID (no person key at all —
   name+DOB fuzzy match in a lost-source DataStage job) / MKTG_CUST_ID
   (never crosswalked), with two partial crosswalks and a 55% MDM match rate.
2. **Rule duplication & drift** — postcode rule DQR-014 in 4 engines
   (all different), email DQR-007 in 2 (+1 gap), NINO masking in 2 stacks with
   a raw-join bypass (AR-118), Julian date conversion in 3 places with
   THREE different Y2K pivot years (49/50/40), SII LoB mapping drifted
   between SAS and Informatica, and a FIFTH postcode variant: LIFE400 has no
   postcode field (addresses stranded on the AS/400, GDPR SAR impact).
3. **Metric divergence** — earned premium 1/12ths vs 1/24ths vs 365ths,
   plus Life "Annualised Premium In Force" summed with earned premium in one
   Group KPI; FOUR concurrent definitions of "active policy"; two incompatible risk
   score scales on one dashboard; fraud flag 'S' mapped opposite ways.
4. **Format chaos** — ISO vs DD/MM/YYYY-as-text vs Julian vs a US-format
   parsing bug (INC0067812); pence implied-decimal; £-and-commas text amounts;
   three formats of the same policy number.
5. **Pipeline clone drift & scheduling chaos** — insurance BTEQ/SAS cloned
   from banking and never re-converged; QUADRUPLE scheduling (Control-M, cron,
   AS/400 ADDJOBSCDE, DataStage Director — LIFE_POLICY_LOAD is triple-scheduled);
   a 75-minute FTP gap with no file-watcher between AS/400 and DataStage;
   an undocumented cross-pipeline kick inside a ksh script; a known nightly
   race condition; a DQ-bypassing duplicate actuarial feed.
6. **Legacy consumption debt** — 26h-stale ODS sold as real-time behind a
   frozen rpc/encoded SOAP contract that mixes two identifier schemes in one
   field, plus inline re-keying logic duplicated a fourth time in PL/SQL.
7. **Platform obsolescence & key-person risk** — DataStage 9.1 out of support
   since 2018 with one production job's source lost; LIFE400 operable by two
   5250-literate FTEs (one retiring); plaintext FTP credentials; GDPR subject
   access requests requiring a manual green-screen session.

## Suggested demo flow (maps to modernization use cases)
1. **Assess** — inventory feeds/pipelines across Informatica + SAS + BTEQ +
   mainframe; build the attribute-overlap matrix; reconcile the four
   glossaries; diff the DQ registry against actual implementations.
2. **Recommend** — propose canonical Party / Policy / Claim / Premium /
   Reinsurance data domains, survivorship rules, and a single earned-premium
   and active-policy definition with owner mapping.
3. **Generate** — Snowflake + dbt models (staging → domains → marts) with
   dbt tests replacing the DQ rule sprawl; Spring Boot domain APIs
   (Policy/Party/Claim) replacing PolicyInquiryService, with contract tests.
4. **Migrate** — generate migration scripts from Teradata/Oracle/flat feeds
   to the target model, including the identity-resolution backfill.
5. **Evolve** — introduce an incremental change (e.g. IPT rate change, new
   product code, GDPR field) and show blast-radius analysis + coordinated
   code change across dbt models and APIs. The life estate adds a strong
   variant: "retire LIFE400 and DataStage" — Devin must recover the lost
   LIFE_POLICY_LOAD logic from the feed spec + landing DDL + COBOL source,
   design the party-resolution backfill for a keyless book, and repatriate
   the stranded ADDRMST addresses.

---
*All data is synthetic. Company, people and incidents are fictional. The
`legacy_shared_services` Informatica exports, the `as400_life/LIFE400` system
and the `datastage` job exports originate from public sample repositories
(rebranded) and are included to provide authentic tool-native bulk.*
