"""Analyst catalogue for the Albion data-estate assessment (ADEM-1).

This module holds the *claims* of the assessment. It deliberately holds no
line numbers: every claim carries one or more evidence probes, and
``estate_scan`` resolves each probe against the working tree to produce the
concrete ``path:line`` citation plus the matching source snippet. A probe that
no longer matches fails the scan, so the published report can never cite a
reference that has drifted away from the code.

A probe is ``(path, needle)`` where ``needle`` is a literal substring of the
line to cite, or ``(path, needle, note)`` to add an explanatory note.
"""

SEVERITY_ORDER = ["Critical", "High", "Medium", "Low"]

CATEGORIES = [
    {
        "id": "C1",
        "title": "Identity fragmentation",
        "summary": (
            "Six independent person/contract identifier schemes are in production use "
            "with two partial, manually maintained crosswalks and no group party key."
        ),
    },
    {
        "id": "C2",
        "title": "DQ rule duplication & drift",
        "summary": (
            "Registered DQ rules are re-implemented per engine. The registry records "
            "fewer implementations than exist, and no two implementations of the same "
            "rule agree on the same input."
        ),
    },
    {
        "id": "C3",
        "title": "Metric divergence",
        "summary": (
            "The same business measures (earned premium, active policy, risk score, "
            "fraud flag) carry multiple concurrent definitions, each implemented in a "
            "different engine and all published side by side."
        ),
    },
    {
        "id": "C4",
        "title": "Format chaos",
        "summary": (
            "Dates, money and policy references arrive in mutually incompatible "
            "physical formats and are re-parsed independently in every consumer."
        ),
    },
    {
        "id": "C5",
        "title": "Pipeline clone drift & scheduling chaos",
        "summary": (
            "The insurance estate was cloned from the banking estate and never "
            "re-converged; four schedulers with overlapping ownership drive it."
        ),
    },
    {
        "id": "C6",
        "title": "Legacy consumption debt",
        "summary": (
            "A frozen 2011 rpc/encoded SOAP contract serves 26-hour-stale ODS data as "
            "real-time and leaks two identifier schemes through one field."
        ),
    },
    {
        "id": "C7",
        "title": "Platform obsolescence & key-person risk",
        "summary": (
            "Out-of-support platforms, a production job whose source is lost, "
            "plaintext credentials and manual green-screen GDPR fulfilment."
        ),
    },
]

FINDINGS = [
    # ---------------------------------------------------------------- C1 ----
    {
        "id": "F-ID-01",
        "category": "C1",
        "title": "Six concurrent identifier schemes for the same population",
        "severity": "Critical",
        "summary": (
            "CUSTOMER_ID (APF banking), PARTY_ID (POLARIS), CLIENT_NO (LEGACY_PAS "
            "mainframe), customer_ref (SOAP API, mixed scheme), LIFE_POLICY_ID "
            "(LIFE400 — a contract key used as a person key) and MKTG_CUST_ID "
            "(partner loyalty) all identify overlapping populations of natural "
            "persons. None is authoritative and none is a superset."
        ),
        "impact": (
            "No group-level view of a customer. Cross-sell, aggregate exposure, "
            "sanctions/PEP screening, GDPR subject access and single-customer-view "
            "regulatory reporting all require manual reconciliation."
        ),
        "evidence": [
            ("docs/feed_inventory.md", "Identity schemes now in play: 6"),
            ("teradata/bteq/01_stg_customer_360.bteq", "c.CUSTOMER_ID,",
             "CUSTOMER_ID — APF banking core"),
            ("teradata/ddl/03_insurance_source_tables.sql", "PARTY_ID            CHAR(8)",
             "PARTY_ID — POLARIS PAS"),
            ("mainframe/copybooks/PLCYMSTR.cpy", "PLCY-CLIENT-NO           PIC 9(10)",
             "CLIENT_NO — LEGACY_PAS mainframe"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "AS customer_ref",
             "customer_ref — SOAP API, two schemes in one field"),
            ("teradata/ddl/04_life_db.sql", "LIFE_POLICY_ID   CHAR(12)",
             "LIFE_POLICY_ID — LIFE400, no person key at all"),
            ("datastage/README.md", "MKTG_CUST_ID is a 6th identifier scheme",
             "MKTG_CUST_ID — partner loyalty"),
        ],
    },
    {
        "id": "F-ID-02",
        "category": "C1",
        "title": "Both identity crosswalks are partial, manual and unenforced",
        "severity": "Critical",
        "summary": (
            "PARTY.LEGACY_CUSTOMER_ID (banking crosswalk) is ~55% populated with no "
            "referential integrity, and REF_DB.XREF_CLIENT_PARTY (mainframe "
            "crosswalk) is an Excel-upload heritage table. MDM match rate has been "
            "stuck at ~55% with 41k unworked suspects."
        ),
        "impact": (
            "Roughly half of all joins between the insurance and banking estates "
            "silently drop or duplicate people; the suspect backlog grows unworked."
        ),
        "evidence": [
            ("teradata/ddl/03_insurance_source_tables.sql", "Coverage was ~55% at last audit"),
            ("teradata/ddl/03_insurance_source_tables.sql",
             "CREATE MULTISET TABLE REF_DB.XREF_CLIENT_PARTY"),
            ("teradata/ddl/03_insurance_source_tables.sql", "Manually maintained crosswalk"),
            ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "Match rate stuck at ~55%"),
            ("dq_rules/dq_rules_registry.csv", "41k unworked suspects"),
            ("informatica/parameter_files/wf_PARTY_MDM_SYNC.par", "$$MATCH_CONFIDENCE_FLOOR=0.82"),
        ],
    },
    {
        "id": "F-ID-03",
        "category": "C1",
        "title": "Life book has no party key; matching happens in a lost-source job",
        "severity": "Critical",
        "summary": (
            "FD-010 carries INSNAME free text and a DOB only. Life policyholders are "
            "attached to group PARTY by a name+DOB fuzzy match executed inside the "
            "DataStage job LIFE_POLICY_LOAD, whose .dsx export no longer exists. "
            "There is no suspect queue and the match precision is unknown."
        ),
        "impact": (
            "The entire term-life book cannot be reliably attributed to a person; the "
            "matching rule cannot be read, tested, corrected or migrated."
        ),
        "evidence": [
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md",
             "No customer/party identifier exists on this feed."),
            ("teradata/ddl/04_life_db.sql", "MATCHED_PARTY_ID CHAR(10)"),
            ("datastage/README.md", "for this job is lost"),
            ("glossary/life_operations_glossary.md", "a name+DOB fuzzy match inside a DataStage job"),
            ("dq_rules/dq_rules_registry.csv", "life book matched by name+DOB fuzzy only"),
        ],
    },
    {
        "id": "F-ID-04",
        "category": "C1",
        "title": "MKTG_CUST_ID has never been crosswalked to anything",
        "severity": "High",
        "summary": (
            "Partner loyalty files carry a partner-issued 5-digit CustomerID that "
            "lands in the DataStage marts. Marketing dedupe is ad hoc on name+email "
            "inside the marts."
        ),
        "impact": (
            "Marketing counts of 'customers' cannot be reconciled to any other "
            "system; consent and suppression cannot be enforced across the group."
        ),
        "evidence": [
            ("datastage/README.md", "crosswalked to PARTY_ID or the APF CUSTOMER_ID"),
            ("docs/feed_inventory.md", "MKTG_CUST_ID (6th id scheme, never crosswalked)"),
        ],
    },
    {
        "id": "F-ID-05",
        "category": "C1",
        "title": "The SOAP contract multiplexes two identifier schemes into one field",
        "severity": "High",
        "summary": (
            "pkg_policy_inquiry returns NVL(legacy_customer_id, party_id) as "
            "customer_ref, so downstream consumers parse the prefix to work out "
            "which scheme they were given."
        ),
        "impact": (
            "Every consumer re-implements identity disambiguation; the field cannot "
            "be typed, validated or migrated without breaking a frozen contract."
        ),
        "evidence": [
            ("api_legacy/plsql/pkg_policy_inquiry.sql",
             "NVL(TO_CHAR(p.legacy_customer_id), p.party_id) AS customer_ref"),
            ("api_legacy/soap/PolicyInquiryService.wsdl",
             "'CustomerRef' for two different identifier schemes"),
        ],
    },
    # ---------------------------------------------------------------- C2 ----
    {
        "id": "F-DQ-01",
        "category": "C2",
        "title": "DQR-014 (UK postcode) implemented five different ways",
        "severity": "High",
        "summary": (
            "Informatica variant A auto-repairs a missing space then regex-validates; "
            "the BTEQ variant requires an embedded space and checks first-char-alpha; "
            "the SAS macro applies a case-sensitive PRX (and was never registered); "
            "the COBOL copybook checks first-char-alpha only (PR4471); and LIFE400 "
            "has no postcode field at all — correspondence addresses are stranded in "
            "ADDRMST on the AS/400."
        ),
        "impact": (
            "The same postcode is VALID in one store and INVALID in the next. "
            "Address-based pricing, fraud and GDPR fulfilment disagree by store."
        ),
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-014", "registry entry"),
            ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "DQR-014 variant A",
             "variant 1 — auto-repairs space, then REG_MATCH"),
            ("teradata/bteq/04_stg_policy_360.bteq", "Postcode DQ rule DQR-014, local re-implementation",
             "variant 2 — requires embedded space"),
            ("sas/macros/check_uk_postcode.sas", "case-SENSITIVE",
             "variant 3 — rejects lowercase, never registered"),
            ("mainframe/copybooks/PLCYMSTR.cpy", "WEAK CHECK - FIRST CHAR ALPHA ONLY",
             "variant 4 — PR4471, won't fix"),
            ("docs/feed_inventory.md", "no postcode field at all",
             "variant 5 — LIFE400 has no postcode at all"),
        ],
    },
    {
        "id": "F-DQ-02",
        "category": "C2",
        "title": "DQR-007 (email) implemented twice and skipped once",
        "severity": "Medium",
        "summary": (
            "Informatica lowercases then applies an RFC-ish regex; BTEQ tests for the "
            "presence of '@'; the APF banking customer pipeline performs no email "
            "validation at all. The registry records only the Informatica variant."
        ),
        "impact": (
            "Email is a survivorship attribute in the MDM hub, so validation "
            "divergence propagates directly into golden records and contactability."
        ),
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-007", "registry entry: 1 registered, 3 actual"),
            ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "DQR-007 variant B"),
            ("teradata/bteq/04_stg_policy_360.bteq", "Email DQ rule DQR-007, local variant"),
        ],
    },
    {
        "id": "F-DQ-03",
        "category": "C2",
        "title": "DQR-021 NINO masking is bypassed by a raw join (AR-118)",
        "severity": "Critical",
        "summary": (
            "Informatica masks NINO on the way into the marts. The SAS fraud pipeline "
            "reads POLICY_ADMIN_DB.PARTY directly and joins on the raw NINO 'for "
            "match quality', applying mask_nino only to the output dataset."
        ),
        "impact": (
            "Special-category-adjacent identifiers are processed unmasked in an "
            "analytical environment. Accepted as risk AR-118 in the 2022 DPIA and "
            "never remediated; SAS WORK datasets retain raw NINO."
        ),
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-021", "registry status PARTIAL"),
            ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "EXP_NINO_MASK",
             "masks only the Informatica-fed marts"),
            ("sas/claims_fraud/05_claims_fraud_scoring.sas", "accepted risk AR-118",
             "raw NINO join"),
            ("sas/claims_fraud/05_claims_fraud_scoring.sas", "masked only on the way OUT"),
            ("sas/macros/mask_nino.sas", "KNOWN GAP"),
            ("docs/known_issues_register.md", "AR-118"),
        ],
    },
    {
        "id": "F-DQ-04",
        "category": "C2",
        "title": "Three different Y2K pivot years for the same two-digit years (DQR-052)",
        "severity": "High",
        "summary": (
            "Informatica windows 00-49 to 20xx, the actuarial SAS macro windows 00-50, "
            "and the LIFE400 extract plus the LIFE_DB century view use pivot 40. The "
            "registered rule DQR-052 has no registered implementation at all."
        ),
        "impact": (
            "Dates resolve to different centuries per engine. Life DOBs in the range "
            "1925-1939 are at risk of a +100 year shift, which silently changes "
            "underwriting age, contestability and reserving."
        ),
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-052", "registered implementations: none"),
            ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "&lt;= 49", "pivot 49"),
            ("sas/macros/julian_to_date.sas", "if _yy <= 50 then _year = 2000 + _yy;", "pivot 50"),
            ("teradata/ddl/04_life_db.sql", "pivot 40 (!!)", "pivot 40"),
            ("as400_life/extracts/LIFEXTR.clle", "PIVOT YEAR AGREED AS 40",
             "agreed verbally, never specified"),
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "known ambiguity, unresolved"),
        ],
    },
    {
        "id": "F-DQ-05",
        "category": "C2",
        "title": "Solvency II line-of-business mapping drifted between SAS and Informatica",
        "severity": "High",
        "summary": (
            "The Albion PRODUCT_CD to SII LoB mapping exists twice. SAS maps PET to "
            "'Miscellaneous financial loss'; the Informatica reinsurance lookup maps "
            "PET to 'Other motor' after a 2023 edit."
        ),
        "impact": (
            "The QRT submission and the outward bordereau report the same product "
            "under different regulatory lines of business."
        ),
        "evidence": [
            ("sas/regulatory/08_solvency_ii_qrt_prep.sas", "'PET' = 'Miscellaneous financial loss'"),
            ("informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml", "PET maps to 'Other motor' here"),
            ("docs/known_issues_register.md", "SII LoB mapping drifted"),
        ],
    },
    {
        "id": "F-DQ-06",
        "category": "C2",
        "title": "Suspended registry rule replaced by an unscheduled shadow check",
        "severity": "Medium",
        "summary": (
            "DQR-033 (loss date not in future) was commented out of BTEQ in 2022 and "
            "is marked SUSPENDED. An equivalent check now lives in a manual, "
            "unscheduled ad-hoc SQL pack run by Claims MI before month end."
        ),
        "impact": (
            "The control exists on paper and in an unscheduled script, but nothing "
            "enforces it in the pipeline."
        ),
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-033"),
            ("dq_rules/sql/dq_checks_claims.sql", "DQR-033 equivalent"),
            ("dq_rules/sql/dq_checks_claims.sql", "not scheduled"),
        ],
    },
    {
        "id": "F-DQ-07",
        "category": "C2",
        "title": "Policy status domain (DQR-030) unimplemented; retired codes dropped silently",
        "severity": "Medium",
        "summary": (
            "DQR-030 is DRAFT with no implementation. LEGACY_PAS still emits retired "
            "product codes CAR/HSE and an out-of-domain status 'PD', dropped silently "
            "by a source-qualifier filter; the product mapping table is lost and the "
            "mapping is hardcoded in a session pre-SQL."
        ),
        "impact": "Silent row loss with no reject file and no reconciliation.",
        "evidence": [
            ("dq_rules/dq_rules_registry.csv", "DQR-030"),
            ("glossary/underwriting_data_dictionary.csv", "mapping table lost; hardcoded in a session pre-SQL"),
        ],
    },
    {
        "id": "F-DQ-08",
        "category": "C2",
        "title": "Duplicate-key validation silently skipped above 1m rows (CR-2022-410)",
        "severity": "High",
        "summary": (
            "validate_policy.sas was copy-pasted from validate_table.sas and edited in "
            "place: the null-rate threshold became hardcoded and the duplicate-key "
            "check is skipped, with only a WARNING, once row counts exceed a million."
        ),
        "impact": (
            "The DQ gate protecting the published data products degrades to a no-op "
            "exactly on the largest and most material tables."
        ),
        "evidence": [
            ("sas/macros/validate_policy.sas", "Skipping duplicate-key check"),
            ("sas/macros/validate_policy.sas", "Copy-pasted from validate_table.sas"),
            ("docs/known_issues_register.md", "CR-2022-410"),
        ],
    },
    # ---------------------------------------------------------------- C3 ----
    {
        "id": "F-MX-01",
        "category": "C3",
        "title": "Earned premium computed on three incompatible bases",
        "severity": "Critical",
        "summary": (
            "Finance BTEQ earns straight-line 1/12ths, the Informatica billing "
            "reconciliation earns 1/24ths (mid-month inception assumption), and "
            "actuarial SAS earns daily 365ths from a separate feed. All three are "
            "published; the reconciliation is a manual spreadsheet."
        ),
        "impact": (
            "Year-end figures differ by up to 1.8% by product. The Solvency II "
            "S.05.01 combined ratio never ties to the Board pack and is corrected by "
            "a manual true-up journal."
        ),
        "evidence": [
            ("teradata/bteq/06_stg_earned_premium.bteq", "Straight-line monthly 1/12ths (Finance)"),
            ("informatica/XML/wf_BILLING_PREMIUM_RECON.xml", "EARNED PREMIUM METHOD: 1/24ths"),
            ("sas/actuarial/06_reserving_triangles.sas", "365ths daily pro-rata"),
            ("sas/regulatory/08_solvency_ii_qrt_prep.sas", "The two inputs use different earned-premium conventions"),
            ("glossary/actuarial_definitions.md", "the three earned-premium figures differ by up to 1.8%"),
            ("dq_rules/sql/dq_checks_claims.sql", "never ties; tolerance raised twice"),
        ],
    },
    {
        "id": "F-MX-02",
        "category": "C3",
        "title": "Life Annualised Premium In Force is added to P&C earned premium in a Group KPI",
        "severity": "Critical",
        "summary": (
            "LIFE_DB.V_LIFE_POLICY derives ANNUALISED_PREMIUM_IN_FORCE as "
            "MODAL_PREMIUM x PAY_FREQ. Group MI adds this forward-looking in-force "
            "measure to backward-looking P&C earned premium in a single KPI tile."
        ),
        "impact": (
            "A headline group premium number is methodologically meaningless and is "
            "recorded as unnoticed in the known-issues register."
        ),
        "evidence": [
            ("teradata/ddl/04_life_db.sql", "ANNUALISED_PREMIUM_IN_FORCE"),
            ("glossary/life_operations_glossary.md", "adds Life API to P&C earned premium"),
            ("docs/known_issues_register.md", "Group Premium KPI adds Life API"),
        ],
    },
    {
        "id": "F-MX-03",
        "category": "C3",
        "title": "Four concurrent definitions of 'active policy', each implemented somewhere",
        "severity": "Critical",
        "summary": (
            "Underwriting: status IF or RN. Finance: status IF plus a collection in "
            "the last 45 days. Claims MI: any policy with an OPEN or REOPENED claim, "
            "including cancelled policies. Life Ops: CNTRSTS in AC/GR/RS. Each has a "
            "live implementation, and the SOAP API serves the Finance flag to a "
            "claims-facing consumer."
        ),
        "impact": (
            "In-force policy counts differ by audience; claim frequency uses one "
            "definition in the numerator and another in the denominator."
        ),
        "evidence": [
            ("glossary/underwriting_data_dictionary.csv", "Policy with status IF or RN"),
            ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "Active flag per UNDERWRITING definition",
             "UW implementation"),
            ("glossary/finance_data_dictionary.csv", "at least one premium collection in the last 45 days"),
            ("teradata/bteq/04_stg_policy_360.bteq", "per FINANCE definition", "Finance implementation"),
            ("glossary/claims_glossary.md", "any policy with at least one OPEN or REOPENED claim"),
            ("glossary/life_operations_glossary.md", "CNTRSTS in ('AC','GR','RS')"),
            ("teradata/bteq/06_stg_earned_premium.bteq", "UW definition of active here!",
             "Finance-owned table filtered on the UW definition"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "this API is claims-facing"),
        ],
    },
    {
        "id": "F-MX-04",
        "category": "C3",
        "title": "Two incompatible risk scales rendered side by side",
        "severity": "High",
        "summary": (
            "The claims fraud model emits FRAUD_SCORE on a 0-1000 SIU scale; the "
            "premium-finance model emits a 0-1 probability of default for an "
            "overlapping customer population. Both appear on the same Qlik dashboard "
            "with no rescaling."
        ),
        "impact": "Operational decisions are taken on visually comparable, numerically unrelated scores.",
        "evidence": [
            ("sas/claims_fraud/05_claims_fraud_scoring.sas", "NOTE ON SCALE"),
            ("sas/claims_fraud/05_claims_fraud_scoring.sas", "side-by-side in the Qlik"),
            ("glossary/claims_glossary.md", "confused with the APF banking RISK_SCORE (0\u20131 probability)"),
            ("docs/architecture_overview.md", "mixed 0–1 and 0–1000 risk scales side by side"),
        ],
    },
    {
        "id": "F-MX-05",
        "category": "C3",
        "title": "Fraud flag 'S' mapped to opposite values in the two loaders",
        "severity": "High",
        "summary": (
            "LEGACY_CLM emits 'S' (suspected). Informatica decodes 'S' to 'N'; the "
            "BTEQ staging maps 'S' to 'Y'. A manual ad-hoc query exists purely to "
            "count the resulting disagreements."
        ),
        "impact": (
            "Fraud MI counts differ between the operational and analytical stores, "
            "and the fraud score adds 250 points on the BTEQ interpretation."
        ),
        "evidence": [
            ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "'S','N'", "Informatica: S -> N"),
            ("teradata/bteq/05_stg_claims_summary.bteq", "IN ('Y','S') THEN 'Y'", "BTEQ: S -> Y"),
            ("dq_rules/sql/dq_checks_claims.sql", "fraud_flag_mismatches"),
            ("sas/claims_fraud/05_claims_fraud_scoring.sas", "(FRAUD_FLAG_NORM = 'Y') * 250"),
        ],
    },
    {
        "id": "F-MX-06",
        "category": "C3",
        "title": "IPT rate hardcoded in three codebases with an unused parameter",
        "severity": "Medium",
        "summary": (
            "The Informatica recon hardcodes 0.12 while a $$IPT_RATE parameter sits "
            "unused in the same parameter file; the BTEQ earned-premium job uses the "
            "POLICY.IPT_RATE column; Finance documents the rate as hardcoded in three "
            "pipelines."
        ),
        "impact": "A statutory rate change requires coordinated edits across engines with no single owner.",
        "evidence": [
            ("informatica/XML/wf_BILLING_PREMIUM_RECON.xml", "RATE IS HARDCODED"),
            ("informatica/parameter_files/wf_BILLING_PREMIUM_RECON.par", "mapping hardcodes 0.12 anyway"),
            ("teradata/bteq/06_stg_earned_premium.bteq", "p.ANNUAL_PREMIUM_GBP * p.IPT_RATE"),
            ("glossary/finance_data_dictionary.csv", "hardcoded in three pipelines"),
        ],
    },
    {
        "id": "F-MX-07",
        "category": "C3",
        "title": "'Incurred' is anchored to different dates in Claims and Finance",
        "severity": "Medium",
        "summary": (
            "Claims MI recognise incurred movements on LOSS_DT; Finance recognise them "
            "on NOTIFICATION_DT because their ledger has no loss-date field. "
            "Reserving triangles are built on loss date."
        ),
        "impact": "'Incurred in month' means three different things across three packs.",
        "evidence": [
            ("glossary/claims_glossary.md", "Claims MI use **LOSS_DT**"),
            ("glossary/claims_glossary.md", "recognise incurred movements on **NOTIFICATION_DT**"),
            ("glossary/claims_glossary.md", "means different things in different packs"),
            ("sas/actuarial/06_reserving_triangles.sas", "ACCIDENT_YEAR"),
        ],
    },
    # ---------------------------------------------------------------- C4 ----
    {
        "id": "F-FM-01",
        "category": "C4",
        "title": "Five date representations, including a live US/UK parsing defect",
        "severity": "Critical",
        "summary": (
            "ISO dates (banking), DD/MM/YYYY held as text (POLARIS party DOB, claims "
            "loss date), Julian YYDDD (mainframe), YYMMDD (LIFE400) and a US-format "
            "assumption in the Informatica claims path all coexist. Guidewire has "
            "sent DD/MM/YYYY since its 2023 upgrade but Informatica still parses "
            "MM/DD/YYYY for GUIDEWIRE_CC while BTEQ parses the same field as UK."
        ),
        "impact": (
            "INC0067812, open since 2023: about 40% of claims carry divergent loss "
            "dates between the operational and analytical stores, so accident-year "
            "allocation differs for every day<=12 date."
        ),
        "evidence": [
            ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "ASSUMES GUIDEWIRE SENDS MM/DD/YYYY"),
            ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "TO_DATE(in_LOSS_DT_RAW,'MM/DD/YYYY')"),
            ("teradata/bteq/05_stg_claims_summary.bteq", "LOSS_DT arrives as DD/MM/YYYY *text*"),
            ("teradata/ddl/03_insurance_source_tables.sql", "DD/MM/YYYY as text (!)"),
            ("mainframe/copybooks/PLCYMSTR.cpy", "JULIAN DATE YYDDD"),
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "All dates YYMMDD"),
            ("docs/known_issues_register.md", "INC0067812"),
            ("glossary/actuarial_definitions.md", "DWH accident-year allocations differ from actuarial"),
        ],
    },
    {
        "id": "F-FM-02",
        "category": "C4",
        "title": "Three money representations, each de-scaled by hand",
        "severity": "High",
        "summary": (
            "Mainframe premium arrives in pence with an implied decimal, broker "
            "bordereaux amounts arrive as text with a pound sign and thousands "
            "commas, and Teradata holds DECIMAL(12,2) pounds. Each consumer "
            "re-implements the conversion."
        ),
        "impact": "A missed de-scaling is a 100x error with no schema-level guard.",
        "evidence": [
            ("mainframe/copybooks/PLCYMSTR.cpy", "STORED IN PENCE, IMPLIED DECIMAL"),
            ("sas/actuarial/06_reserving_triangles.sas", "ANNL_PREM_PENCE / 100"),
            ("informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml", "strips pound sign and commas"),
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "implied 2dp"),
        ],
    },
    {
        "id": "F-FM-03",
        "category": "C4",
        "title": "Three policy-number formats and four re-keying implementations",
        "severity": "High",
        "summary": (
            "POLARIS uses ALB-XXX-9999999, the mainframe extract strips hyphens, and "
            "brokers send AL/MOT/9999999. Re-keying is implemented in the Informatica "
            "bordereaux mapping and again inline in the PL/SQL inquiry package."
        ),
        "impact": (
            "Bordereaux re-keying failures surface as orphan claims, which the ad-hoc "
            "DQ pack counts but nothing fixes."
        ),
        "evidence": [
            ("mainframe/feed_specs/PLCYMSTR_feed_spec.md", "Hyphens stripped vs POLARIS format"),
            ("informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml", "'AL/', 'ALB-'"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "re-key inline (4th place)"),
            ("dq_rules/sql/dq_checks_claims.sql", "typically bordereaux re-keying failures"),
        ],
    },
    {
        "id": "F-FM-04",
        "category": "C4",
        "title": "Status code domains do not align across the estate",
        "severity": "Medium",
        "summary": (
            "P&C policy status is IF/RN/LP/CN/EX, LIFE400 contract status is "
            "PE/AC/GR/LA/RS/CL/TE/RJ, and claim status is single-character O/S/R/D in "
            "LEGACY_CLM against Guidewire words. Harmonisation is a DECODE per engine."
        ),
        "impact": "No shared status vocabulary; every cross-system count needs a bespoke mapping.",
        "evidence": [
            ("teradata/ddl/03_insurance_source_tables.sql", "IF/RN/LP/CN/EX"),
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "does not align to P&C status domain"),
            ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "single-char O/S/R/D to Guidewire words"),
        ],
    },
    # ---------------------------------------------------------------- C5 ----
    {
        "id": "F-OP-01",
        "category": "C5",
        "title": "The insurance estate is an un-reconverged clone of the banking estate",
        "severity": "High",
        "summary": (
            "BTEQ 04 was cloned from BTEQ 01, run_insurance_bteq.sh from "
            "run_bteq_pipeline.sh, the policyholder segmentation from the banking "
            "customer segmentation, and validate_policy.sas from validate_table.sas. "
            "Each pair has since diverged and fixes do not propagate."
        ),
        "impact": (
            "Every DQ or logic fix must be applied N times; in practice it is applied "
            "once. Overlapping people receive two unreconciled segment labels."
        ),
        "evidence": [
            ("teradata/bteq/04_stg_policy_360.bteq", "Cloned from 01_stg_customer_360.bteq"),
            ("teradata/bteq/run_insurance_bteq.sh", "Cloned from run_bteq_pipeline.sh"),
            ("sas/customer/09_policyholder_segmentation.sas", "Cloned from Premium Finance"),
            ("sas/macros/validate_policy.sas", "Copy-pasted from validate_table.sas"),
            ("sas/run_insurance_sas_pipeline.sh", "cloned 2021 from premium_finance"),
            ("docs/known_issues_register.md", "CR-2021-088"),
        ],
    },
    {
        "id": "F-OP-02",
        "category": "C5",
        "title": "Four schedulers with overlapping ownership; LIFE_POLICY_LOAD is triple-scheduled",
        "severity": "Critical",
        "summary": (
            "Control-M, the prod crontab, AS/400 ADDJOBSCDE and the DataStage "
            "Director scheduler all drive production work. run_wf_policy_master and "
            "run_insurance_sas_pipeline.sh are double-scheduled; LIFE_POLICY_LOAD is "
            "started by Control-M ALB-LIF-0005, by cron at 00:45 and by the DataStage "
            "Director."
        ),
        "impact": (
            "Concurrent runs of the same load, no single source of schedule truth, "
            "and nobody can say which scheduler owns bdx_transfer."
        ),
        "evidence": [
            ("orchestration/cron/crontab_prod.txt", "triple-scheduled"),
            ("orchestration/cron/crontab_prod.txt", "ALSO in Control-M ALB-DWH-0032"),
            ("orchestration/cron/crontab_prod.txt", "ALSO Control-M ALB-DWH-0050"),
            ("orchestration/cron/crontab_prod.txt", "nobody is sure which scheduler"),
            ("orchestration/controlm/ALBION_DWH_DAILY.xml", "ALB-LIF-0005"),
            ("as400_life/LIFE400/QCLSRC/DLYUPD.clle", "ADDJOBSCDE"),
            ("docs/architecture_overview.md", "Control-M *and* cron *and* AS/400 ADDJOBSCDE"),
        ],
    },
    {
        "id": "F-OP-03",
        "category": "C5",
        "title": "75-minute gap and no file watcher between the AS/400 push and the DataStage load",
        "severity": "High",
        "summary": (
            "LIFEXTR submits an FTP push at 23:30; LIFE_POLICY_LOAD starts at 00:45. "
            "Nothing verifies the file arrived or is complete."
        ),
        "impact": "A late or partial extract loads silently truncated life data with no alert.",
        "evidence": [
            ("orchestration/controlm/ALBION_DWH_DAILY.xml", "no file-watcher, just a 75-minute gap"),
            ("as400_life/extracts/LIFEXTR.clle", "SBMJOB CMD(CALL PGM(LIFE400/FTPPUT)"),
            ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "Nightly 23:30 via LIFEXTR"),
        ],
    },
    {
        "id": "F-OP-04",
        "category": "C5",
        "title": "Undocumented cross-pipeline trigger inside a ksh wrapper",
        "severity": "High",
        "summary": (
            "run_wf_policy_master ends by invoking run_insurance_bteq.sh — a "
            "scheduling dependency that lives in a shell script written by a "
            "contractor who left in 2022, described in Control-M only as a comment."
        ),
        "impact": (
            "The real dependency graph is not in the scheduler; a Control-M rerun "
            "silently re-runs the whole Teradata staging layer."
        ),
        "evidence": [
            ("informatica/scripts/run_wf_policy_master", "kick BTEQ staging"),
            ("informatica/scripts/run_wf_policy_master", "run_insurance_bteq.sh"),
            ("orchestration/controlm/ALBION_DWH_DAILY.xml", "also kicks insurance BTEQ - undocumented"),
        ],
    },
    {
        "id": "F-OP-05",
        "category": "C5",
        "title": "Known nightly race between the MDM sync and the policy load",
        "severity": "High",
        "summary": (
            "wf_PARTY_MDM_SYNC must finish before wf_POLICY_MASTER_DAILY but no "
            "INCOND exists in Control-M; the workflow comment says it relies on "
            "runtime luck. Roughly three incidents a year."
        ),
        "impact": "The policy load can resolve parties against a half-synced hub, producing wrong PARTY_IDs.",
        "evidence": [
            ("orchestration/controlm/ALBION_DWH_DAILY.xml", "Missing INCOND on ALB-MDM-0003"),
            ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "relies on runtime luck"),
        ],
    },
    {
        "id": "F-OP-06",
        "category": "C5",
        "title": "Duplicate actuarial policy feed bypasses every DWH DQ gate (CR-2014-311)",
        "severity": "High",
        "summary": (
            "PLCYEXTR STEP020 REPROs a second copy of the policy master to "
            "ALB.ACT.PLCYMSTR.COPY. The actuarial SAS reserving job reads that flat "
            "file directly, so none of the DWH standardisation or DQ applies. The "
            "register classifies this as working as designed."
        ),
        "impact": (
            "Reserving, pricing and the SFCR narrative are produced from ungoverned "
            "data that can differ from the warehouse."
        ),
        "evidence": [
            ("mainframe/jcl/PLCYEXTR.jcl", "REPRO A SECOND COPY FOR ACTUARIAL"),
            ("sas/actuarial/06_reserving_triangles.sas", "bypasses all DWH DQ gates"),
            ("docs/known_issues_register.md", "CR-2014-311"),
            ("glossary/actuarial_definitions.md", "not from\n  the DWH", "actuarial treat it as authoritative"),
        ],
    },
    {
        "id": "F-OP-07",
        "category": "C5",
        "title": "Insurance BTEQ orchestrator continues after a mid-pipeline failure",
        "severity": "Medium",
        "summary": (
            "run_insurance_bteq.sh only aborts when 04_stg_policy_360 fails; a failure "
            "in 05 does not stop 06, on the strength of an unexplained 2022 comment."
        ),
        "impact": "Finance close can run on a partially rebuilt staging layer without an alert.",
        "evidence": [
            ("teradata/bteq/run_insurance_bteq.sh", "does NOT stop 06 by design"),
        ],
    },
    {
        "id": "F-OP-08",
        "category": "C5",
        "title": "The life 'nightly' batch actually runs weekly",
        "severity": "Medium",
        "summary": (
            "DLYUPD performs the grace/lapse sweep and is scheduled weekly via "
            "ADDJOBSCDE, but is described as nightly in the documentation and by Life "
            "Ops."
        ),
        "impact": "Lapse status can be up to seven days stale wherever it is consumed as current.",
        "evidence": [
            ("glossary/life_operations_glossary.md", "weekly via ADDJOBSCDE but described everywhere as",
             "documented weekly, described as nightly"),
            ("as400_life/LIFE400/QCLSRC/DLYUPD.clle", "ADDJOBSCDE"),
        ],
    },
    # ---------------------------------------------------------------- C6 ----
    {
        "id": "F-LC-01",
        "category": "C6",
        "title": "26-hour-stale ODS served as real-time policy data",
        "severity": "Critical",
        "summary": (
            "pkg_policy_inquiry reads a nightly GoldenGate copy of the Teradata "
            "staging table replicated into Oracle. Data is up to 26 hours old and "
            "callers, including the Guidewire integration layer, assume it is live."
        ),
        "impact": (
            "Broker extranet, aggregator gateway and claims handling make decisions "
            "on yesterday's policy state, including the active-policy flag."
        ),
        "evidence": [
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "up to 26h stale"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "GoldenGate"),
            ("docs/architecture_overview.md", "26h-stale data sold as real-time"),
        ],
    },
    {
        "id": "F-LC-02",
        "category": "C6",
        "title": "Frozen 2011 rpc/encoded SOAP contract with unknown consumers",
        "severity": "High",
        "summary": (
            "PolicyInquiryService v1.3 is rpc/encoded, frozen since 2011, and its "
            "consumer list includes 'an unknown number of Access DBs'. The 2021 "
            "Guidewire integration through it is documented as temporary."
        ),
        "impact": (
            "The contract cannot be evolved or safely retired without a consumer "
            "discovery exercise; rpc/encoded is unsupported by modern tooling."
        ),
        "evidence": [
            ("api_legacy/soap/PolicyInquiryService.wsdl", "contract frozen"),
            ("api_legacy/soap/PolicyInquiryService.wsdl", 'use="encoded"'),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "an unknown number of Access DBs"),
        ],
    },
    {
        "id": "F-LC-03",
        "category": "C6",
        "title": "Claims returned to consumers as DD/MM/YYYY text through the API",
        "severity": "Medium",
        "summary": (
            "get_party_claims returns loss_dt as text and accepts either "
            "claimant_party_id or a legacy client number in the same argument."
        ),
        "impact": "Format and identity ambiguity is pushed onto every API consumer.",
        "evidence": [
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "returned as DD/MM/YYYY text"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "callers pass either key"),
        ],
    },
    # ---------------------------------------------------------------- C7 ----
    {
        "id": "F-PT-01",
        "category": "C7",
        "title": "DataStage 9.1 out of support since 2018 with one production job's source lost",
        "severity": "Critical",
        "summary": (
            "The DS39 project runs on InfoSphere DataStage 9.1. LIFE_POLICY_LOAD — "
            "the only bridge between the life book and the group warehouse — exists "
            "only in the production repository; the .dsx export is lost and change "
            "requests against it are refused."
        ),
        "impact": (
            "An unsupported platform carries an unreadable, unmodifiable, "
            "unmigratable production dependency for an entire line of business."
        ),
        "evidence": [
            ("datastage/README.md", "out of support since 2018"),
            ("datastage/README.md", "for this job is lost"),
            ("orchestration/controlm/ALBION_DWH_DAILY.xml", "job source lost - do not modify"),
            ("docs/known_issues_register.md", "exists only in prod repository"),
        ],
    },
    {
        "id": "F-PT-02",
        "category": "C7",
        "title": "LIFE400 operable by two 5250-literate FTEs, one retiring",
        "severity": "Critical",
        "summary": (
            "The Provident Mutual life book is administered on an AS/400 system never "
            "rebranded after the 2016 acquisition. Operations require 5250 knowledge "
            "held by two people."
        ),
        "impact": "Single point of organisational failure for an in-force life book.",
        "evidence": [
            ("docs/known_issues_register.md", "5250 knowledge held by 2 FTEs (1 retiring)"),
            ("as400_life/LIFE400/README.md", "Provident Mutual"),
        ],
    },
    {
        "id": "F-PT-03",
        "category": "C7",
        "title": "Plaintext credentials in the extract and orchestration layers",
        "severity": "Critical",
        "summary": (
            "LIFEXTR FTPs the nightly life extract using credentials held in "
            "plaintext in QGPL/FTPSCRIPT; the Informatica wrapper reads a pmcmd "
            "password from an environment variable exported in plaintext from "
            "/etc/profile.d."
        ),
        "impact": "Credential exposure on both the source platform and the ETL server.",
        "evidence": [
            ("as400_life/extracts/LIFEXTR.clle", "CREDENTIALS IN QGPL/FTPSCRIPT (PLAINTEXT)"),
            ("informatica/scripts/run_wf_policy_master", "in plain text"),
            ("docs/known_issues_register.md", "plaintext credentials"),
        ],
    },
    {
        "id": "F-PT-04",
        "category": "C7",
        "title": "Life correspondence addresses stranded on the AS/400; GDPR SARs are manual",
        "severity": "High",
        "summary": (
            "ADDRMST was descoped from the 2016 integration, so no address data leaves "
            "LIFE400. Subject access requests for the life book require a manual 5250 "
            "session."
        ),
        "impact": (
            "Statutory GDPR timescales depend on a manual process performed by two "
            "people on an unsupported platform."
        ),
        "evidence": [
            ("as400_life/extracts/LIFEXTR.clle", "GDPR SAR REQUESTS REQUIRE A 5250 SESSION"),
            ("docs/known_issues_register.md", "GDPR SARs need manual 5250 session"),
            ("docs/feed_inventory.md", "descoped from the 2016 integration"),
        ],
    },
    {
        "id": "F-PT-05",
        "category": "C7",
        "title": "Defects enshrined as contract: the 'Bouns_Program' job name",
        "severity": "Low",
        "summary": (
            "A 2013 typo in a DataStage job name propagated into downstream table "
            "names and is now marked won't-fix."
        ),
        "impact": "Illustrates how the estate encodes accidents as permanent interface contracts.",
        "evidence": [
            ("datastage/README.md", "typo enshrined in prod job name since 2013"),
            ("docs/known_issues_register.md", "'Bouns_Program' job name typo"),
        ],
    },
]

# --------------------------------------------------------------------------
# Attribute overlap matrix: canonical attribute x producing pipeline/consumer.
# --------------------------------------------------------------------------
ATTRIBUTE_MATRIX = [
    {
        "attribute": "Party / person identifier",
        "canonical": "party_key (surrogate, resolved)",
        "producers": [
            {"system": "APF core banking (BTEQ 01)", "physical": "CUSTOMER_ID",
             "format": "INTEGER", "derivation": "Source system key",
             "evidence": ("teradata/bteq/01_stg_customer_360.bteq", "c.CUSTOMER_ID,")},
            {"system": "POLARIS PAS (Teradata)", "physical": "PARTY_ID",
             "format": "CHAR(8), 'P' + 7 digits", "derivation": "Source system key",
             "evidence": ("teradata/ddl/03_insurance_source_tables.sql", "PARTY_ID            CHAR(8)")},
            {"system": "LEGACY_PAS (mainframe)", "physical": "CLIENT_NO",
             "format": "PIC 9(10), zero padded", "derivation": "Crosswalk via XREF_CLIENT_PARTY",
             "evidence": ("mainframe/copybooks/PLCYMSTR.cpy", "PLCY-CLIENT-NO           PIC 9(10)")},
            {"system": "LIFE400 (AS/400)", "physical": "— none —",
             "format": "INSNAME free text + DOB", "derivation": "name+DOB fuzzy match in lost-source job",
             "evidence": ("as400_life/feed_specs/POLMSTEX_feed_spec.md", "no party key")},
            {"system": "Partner loyalty (DataStage)", "physical": "MKTG_CUST_ID",
             "format": "5-digit partner-issued", "derivation": "Never crosswalked; name+email dedupe",
             "evidence": ("datastage/README.md", "MKTG_CUST_ID is a 6th identifier scheme")},
            {"system": "SOAP PolicyInquiryService", "physical": "customer_ref",
             "format": "VARCHAR, two schemes", "derivation": "NVL(legacy_customer_id, party_id)",
             "evidence": ("api_legacy/plsql/pkg_policy_inquiry.sql", "AS customer_ref")},
        ],
    },
    {
        "attribute": "Policy number",
        "canonical": "policy_number (ALB-XXX-9999999)",
        "producers": [
            {"system": "POLARIS PAS", "physical": "POLICY_NO", "format": "VARCHAR(18) ALB-XXX-9999999",
             "derivation": "Source system key",
             "evidence": ("teradata/ddl/03_insurance_source_tables.sql", "POLICY_NO           VARCHAR(18)")},
            {"system": "LEGACY_PAS extract", "physical": "PLCY-POLICY-NO", "format": "PIC X(18), hyphens stripped",
             "derivation": "Fixed-width position 1-18",
             "evidence": ("mainframe/feed_specs/PLCYMSTR_feed_spec.md", "Hyphens stripped vs POLARIS format")},
            {"system": "Broker bordereaux (Informatica)", "physical": "in_POLICY_REF", "format": "AL/MOT/9999999",
             "derivation": "REPLACESTR 'AL/'->'ALB-', '/'->'-'",
             "evidence": ("informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml", "'AL/', 'ALB-'")},
            {"system": "SOAP / PL/SQL", "physical": "p_policy_no", "format": "either format",
             "derivation": "Inline REPLACE re-key (4th implementation)",
             "evidence": ("api_legacy/plsql/pkg_policy_inquiry.sql", "re-key inline (4th place)")},
            {"system": "LIFE400", "physical": "LIFE_POLICY_ID / POLID", "format": "CHAR(12) 'PM' prefixed",
             "derivation": "Separate numbering scheme, no FK",
             "evidence": ("teradata/ddl/04_life_db.sql", "LIFE_POLICY_ID   CHAR(12)")},
        ],
    },
    {
        "attribute": "Postcode",
        "canonical": "postcode (validated, spaced, uppercase)",
        "producers": [
            {"system": "Informatica wf_POLICY_MASTER_DAILY", "physical": "POSTCODE_STD / POSTCODE_DQ_STATUS",
             "format": "repaired + uppercased", "derivation": "DQR-014 variant A: insert space, REG_MATCH",
             "evidence": ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "DQR-014 variant A")},
            {"system": "BTEQ 04_stg_policy_360", "physical": "POSTCODE_DQ_STATUS",
             "format": "as stored", "derivation": "Requires embedded space + first char A-Z",
             "evidence": ("teradata/bteq/04_stg_policy_360.bteq", "Postcode DQ rule DQR-014, local re-implementation")},
            {"system": "SAS check_uk_postcode.sas", "physical": "POSTCODE_OK",
             "format": "as stored", "derivation": "Case-sensitive PRX; never registered",
             "evidence": ("sas/macros/check_uk_postcode.sas", "case-SENSITIVE")},
            {"system": "LEGACY_PAS copybook", "physical": "PLCY-POSTCODE",
             "format": "PIC X(08), no space", "derivation": "88-level first-char-alpha only (PR4471)",
             "evidence": ("mainframe/copybooks/PLCYMSTR.cpy", "WEAK CHECK - FIRST CHAR ALPHA ONLY")},
            {"system": "LIFE400", "physical": "— none —", "format": "n/a",
             "derivation": "ADDRMST descoped in 2016; addresses never leave the AS/400",
             "evidence": ("as400_life/extracts/LIFEXTR.clle", "NO ADDRESS/POSTCODE DATA")},
        ],
    },
    {
        "attribute": "Loss date",
        "canonical": "loss_date (DATE)",
        "producers": [
            {"system": "Informatica wf_CLAIMS_FNOL_INTRADAY", "physical": "out_LOSS_DT",
             "format": "parsed MM/DD/YYYY for Guidewire", "derivation": "IIF(SOURCE_SYSTEM='GUIDEWIRE_CC', US, UK)",
             "evidence": ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "TO_DATE(in_LOSS_DT_RAW,'MM/DD/YYYY')")},
            {"system": "BTEQ 05_stg_claims_summary", "physical": "LOSS_DT",
             "format": "parsed DD/MM/YYYY", "derivation": "SUBSTR concatenation to ISO then CAST",
             "evidence": ("teradata/bteq/05_stg_claims_summary.bteq", "DD/MM/YYYY text -> DATE")},
            {"system": "SAS 06_reserving_triangles", "physical": "LOSS_DATE",
             "format": "ddmmyy10.", "derivation": "input(c.LOSS_DT, ddmmyy10.)",
             "evidence": ("sas/actuarial/06_reserving_triangles.sas", "input(c.LOSS_DT, ddmmyy10.)")},
            {"system": "SOAP API", "physical": "loss_dt", "format": "DD/MM/YYYY text",
             "derivation": "Passed through untyped",
             "evidence": ("api_legacy/plsql/pkg_policy_inquiry.sql", "returned as DD/MM/YYYY text")},
        ],
    },
    {
        "attribute": "Inception date",
        "canonical": "inception_date (DATE)",
        "producers": [
            {"system": "Informatica EXP_POLICY_DATES", "physical": "out_INCEPTION_DT",
             "format": "from Julian YYDDD", "derivation": "Y2K pivot 49",
             "evidence": ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "&lt;= 49")},
            {"system": "SAS %julian_to_date", "physical": "INCEPTION_DT",
             "format": "from Julian YYDDD", "derivation": "Y2K pivot 50",
             "evidence": ("sas/macros/julian_to_date.sas", "if _yy <= 50 then _year = 2000 + _yy;")},
            {"system": "LIFE_DB.V_LIFE_POLICY", "physical": "INSURED_DOB_CCYYMMDD",
             "format": "from YYMMDD integer", "derivation": "Y2K pivot 40",
             "evidence": ("teradata/ddl/04_life_db.sql", "pivot 40 (!!)")},
        ],
    },
    {
        "attribute": "Annual / written premium",
        "canonical": "gross_written_premium (DECIMAL(12,2) GBP)",
        "producers": [
            {"system": "POLARIS PAS", "physical": "ANNUAL_PREMIUM_GBP", "format": "DECIMAL(12,2) GBP",
             "derivation": "Source value",
             "evidence": ("teradata/ddl/03_insurance_source_tables.sql", "ANNUAL_PREMIUM_GBP  DECIMAL(12,2)")},
            {"system": "LEGACY_PAS copybook", "physical": "PLCY-ANNL-PREM", "format": "PIC 9(09)V99 pence",
             "derivation": "Implied decimal, /100 downstream",
             "evidence": ("mainframe/copybooks/PLCYMSTR.cpy", "STORED IN PENCE, IMPLIED DECIMAL")},
            {"system": "Broker bordereaux", "physical": "in_AMT_TXT", "format": "text with £ and commas",
             "derivation": "REPLACECHR CHR(163) and ','",
             "evidence": ("informatica/XML/wf_REINSURANCE_BORDEREAUX_MONTHLY.xml", "strips pound sign and commas")},
            {"system": "LIFE400", "physical": "MODAL_PREMIUM x PAY_FREQ", "format": "DECIMAL(15,2), implied 2dp at source",
             "derivation": "Annualised Premium In Force — not earned premium",
             "evidence": ("teradata/ddl/04_life_db.sql", "ANNUALISED_PREMIUM_IN_FORCE")},
        ],
    },
    {
        "attribute": "Earned premium",
        "canonical": "earned_premium (single basis, to be agreed)",
        "producers": [
            {"system": "BTEQ 06_stg_earned_premium (Finance)", "physical": "EARNED_PREMIUM",
             "format": "DECIMAL(12,2)", "derivation": "Straight-line 1/12ths",
             "evidence": ("teradata/bteq/06_stg_earned_premium.bteq", "Straight-line monthly 1/12ths (Finance)")},
            {"system": "Informatica wf_BILLING_PREMIUM_RECON", "physical": "out_EARNED_PREMIUM_24",
             "format": "DECIMAL(12,2)", "derivation": "1/24ths, mid-month inception assumption",
             "evidence": ("informatica/XML/wf_BILLING_PREMIUM_RECON.xml", "EARNED PREMIUM METHOD: 1/24ths")},
            {"system": "SAS 06_reserving_triangles (Actuarial)", "physical": "EARNED_PREMIUM_365",
             "format": "numeric", "derivation": "Daily 365ths from the separate actuarial feed",
             "evidence": ("sas/actuarial/06_reserving_triangles.sas", "EARNED_PREMIUM_365")},
        ],
    },
    {
        "attribute": "Active policy flag",
        "canonical": "policy_status + policy_state_history (definition per consumer view)",
        "producers": [
            {"system": "Informatica EXP_POLICY_FLAGS (UW)", "physical": "ACTIVE_POLICY_FLAG",
             "format": "Y/N", "derivation": "status IF or RN",
             "evidence": ("informatica/XML/wf_POLICY_MASTER_DAILY.xml", "IIF(in_STATUS = 'IF' OR in_STATUS = 'RN','Y','N')")},
            {"system": "BTEQ 04_stg_policy_360 (Finance)", "physical": "ACTIVE_POLICY_FLAG",
             "format": "Y/N", "derivation": "status IF and collection within 45 days",
             "evidence": ("teradata/bteq/04_stg_policy_360.bteq", "per FINANCE definition")},
            {"system": "Claims MI dashboards", "physical": "(dashboard-side)",
             "format": "n/a", "derivation": "any policy with an OPEN/REOPENED claim",
             "evidence": ("glossary/claims_glossary.md", "any policy with at least one OPEN or REOPENED claim")},
            {"system": "LIFE400 / Life Ops", "physical": "CNTRSTS", "format": "CHAR(2)",
             "derivation": "AC, GR or RS",
             "evidence": ("glossary/life_operations_glossary.md", "CNTRSTS in ('AC','GR','RS')")},
        ],
    },
    {
        "attribute": "NINO",
        "canonical": "national_insurance_number (tokenised)",
        "producers": [
            {"system": "POLICY_ADMIN_DB.PARTY", "physical": "NINO", "format": "CHAR(9) unmasked",
             "derivation": "Stored raw in the operational store",
             "evidence": ("teradata/ddl/03_insurance_source_tables.sql", "NINO                CHAR(9)")},
            {"system": "Informatica EXP_NINO_MASK", "physical": "out_NINO_MASKED", "format": "XX*****XX",
             "derivation": "Masked into the marts only",
             "evidence": ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "EXP_NINO_MASK")},
            {"system": "SAS fraud pipeline", "physical": "NINO / NINO_MASKED", "format": "raw in WORK, masked on output",
             "derivation": "Raw join, AR-118",
             "evidence": ("sas/claims_fraud/05_claims_fraud_scoring.sas", "accepted risk AR-118")},
        ],
    },
    {
        "attribute": "Fraud flag",
        "canonical": "fraud_indicator (Y / N / SUSPECTED)",
        "producers": [
            {"system": "CLAIMS_DB.CLAIM (operational)", "physical": "FRAUD_FLAG", "format": "CHAR(1) Y/N/blank/S",
             "derivation": "LEGACY_CLM also sends 'S'",
             "evidence": ("teradata/ddl/03_insurance_source_tables.sql", "LEGACY_CLM also sends 'S'")},
            {"system": "Informatica EXP_CLAIM_FLAGS", "physical": "out_FRAUD_FLAG", "format": "Y/N",
             "derivation": "DECODE 'S' -> 'N'",
             "evidence": ("informatica/XML/wf_CLAIMS_FNOL_INTRADAY.xml", "'S','N'")},
            {"system": "BTEQ 05_stg_claims_summary", "physical": "FRAUD_FLAG_NORM", "format": "Y/N",
             "derivation": "'S' -> 'Y'",
             "evidence": ("teradata/bteq/05_stg_claims_summary.bteq", "IN ('Y','S') THEN 'Y'")},
        ],
    },
    {
        "attribute": "Risk / fraud score",
        "canonical": "score with explicit scale + model version",
        "producers": [
            {"system": "SAS 05_claims_fraud_scoring", "physical": "FRAUD_SCORE", "format": "0-1000 integer",
             "derivation": "Weighted rules, refer at >= 650",
             "evidence": ("sas/claims_fraud/05_claims_fraud_scoring.sas", "FRAUD_SCORE >= 650")},
            {"system": "SAS 03_sas_risk_scoring (banking)", "physical": "PROBABILITY_OF_DEFAULT / COMPOSITE_RISK_SCORE",
             "format": "0-1 probability and 0-100 composite", "derivation": "Logistic model + composite banding",
             "evidence": ("sas/premium_finance/03_sas_risk_scoring.sas", "COMPOSITE_RISK_SCORE")},
        ],
    },
    {
        "attribute": "Email",
        "canonical": "email_address (lowercased, validated)",
        "producers": [
            {"system": "Informatica EXP_EMAIL_DQ", "physical": "out_EMAIL_STD / out_EMAIL_DQ_STATUS",
             "format": "lowercased", "derivation": "DQR-007 variant B, RFC-ish regex",
             "evidence": ("informatica/XML/wf_PARTY_MDM_SYNC.xml", "DQR-007 variant B")},
            {"system": "BTEQ 04_stg_policy_360", "physical": "EMAIL_DQ_STATUS", "format": "as stored, mixed case",
             "derivation": "POSITION('@') > 0",
             "evidence": ("teradata/bteq/04_stg_policy_360.bteq", "Email DQ rule DQR-007, local variant")},
            {"system": "APF banking pipeline", "physical": "EMAIL", "format": "as stored",
             "derivation": "No validation at all",
             "evidence": ("dq_rules/dq_rules_registry.csv", "APF banking pipeline (none)")},
        ],
    },
]

# --------------------------------------------------------------------------
# Feeds discovered in code that are absent from docs/feed_inventory.md.
# --------------------------------------------------------------------------
UNLISTED_FEEDS = [
    {
        "id": "UNL-01",
        "name": "ALB.ACT.PLCYMSTR.COPY — duplicate actuarial policy master",
        "tech": "JCL IDCAMS REPRO -> flat file -> SAS INFILE",
        "why_missing": (
            "Created by CR-2014-311 as a second copy of FD-001 and consumed directly "
            "by actuarial SAS. It is a distinct feed with distinct governance (none) "
            "but has no FD- identifier."
        ),
        "evidence": [
            ("mainframe/jcl/PLCYEXTR.jcl", "ACTOUT   DD DSN=ALB.ACT.PLCYMSTR.COPY"),
            ("sas/actuarial/06_reserving_triangles.sas", "/interface/actuarial/PLCYMSTR_COPY.dat"),
        ],
    },
    {
        "id": "UNL-02",
        "name": "Teradata STG_POLICY_360 -> Oracle ODS GoldenGate replica",
        "tech": "GoldenGate (2013 config) -> Oracle ods_policy_360 / ods_claims",
        "why_missing": (
            "A production replication feed serving the SOAP API and its downstream "
            "consumers; not present in the governance inventory in any form."
        ),
        "evidence": [
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "GoldenGate"),
            ("api_legacy/plsql/pkg_policy_inquiry.sql", "FROM ods_policy_360 p"),
            ("docs/architecture_overview.md", "GoldenGate replica"),
        ],
    },
    {
        "id": "UNL-03",
        "name": "DataStage partner source files (Retail / customer / product / transactiondata)",
        "tech": "Delimited files -> DataStage 9.1 marts",
        "why_missing": (
            "FD-011 covers partner loyalty at a high level, but the individual "
            "delimited sources and mart outputs that carry MKTG_CUST_ID are not "
            "inventoried, owned or DQ-checked."
        ),
        "evidence": [
            ("datastage/README.md", "RETAIL_DATA_MART_Job"),
            ("datastage/README.md", "ACTIVATIONSALES_DATA_MART_Job"),
        ],
    },
    {
        "id": "UNL-04",
        "name": "LIFE400 ADDRMST correspondence addresses — the feed that does not exist",
        "tech": "None (descoped 2016)",
        "why_missing": (
            "Not a feed today; recorded here because its absence is what makes life "
            "GDPR fulfilment manual and leaves postcode variant 5 empty."
        ),
        "evidence": [
            ("as400_life/extracts/LIFEXTR.clle", "ADDRMST WAS DESCOPED FROM"),
            ("docs/known_issues_register.md", "ADDRMST"),
        ],
    },
    {
        "id": "UNL-05",
        "name": "Ad-hoc Claims MI DQ pack",
        "tech": "Hand-run SQL",
        "why_missing": (
            "An unscheduled month-end control that re-implements registry rules with "
            "local thresholds; invisible to both the feed inventory and the DQ registry."
        ),
        "evidence": [
            ("dq_rules/sql/dq_checks_claims.sql", "run manually before month-end"),
        ],
    },
]

# --------------------------------------------------------------------------
# Recommended canonical model and target platform.
# --------------------------------------------------------------------------
TARGET_DOMAINS = [
    {
        "domain": "Party",
        "purpose": "One record per natural or legal person across insurance, banking, life and marketing.",
        "key": "party_key (surrogate) with party_xref(source_system, source_id) satellite",
        "core_attributes": [
            "party_key", "party_type", "given_name", "family_name", "birth_date (DATE)",
            "nino_token", "email_address", "phone_e164", "postal_address (structured, UK postcode validated once)",
            "match_score", "match_method", "golden_flag",
        ],
        "sources": [
            "CORE_BANKING_DB.CUSTOMERS.CUSTOMER_ID",
            "POLICY_ADMIN_DB.PARTY.PARTY_ID",
            "LEGACY_PAS CLIENT_NO via REF_DB.XREF_CLIENT_PARTY",
            "LIFE400 INSNAME + INSDOB (probabilistic, quarantined until reviewed)",
            "Partner loyalty MKTG_CUST_ID (probabilistic on name+email)",
        ],
        "notes": (
            "Every legacy identifier becomes a row in party_xref with its match method "
            "and confidence; no legacy key is ever reused as the canonical key."
        ),
    },
    {
        "domain": "Policy",
        "purpose": "One record per contract with a status history, covering P&C and life.",
        "key": "policy_key; natural key (source_system, policy_number)",
        "core_attributes": [
            "policy_key", "policy_number (canonical ALB-XXX-9999999)", "party_key",
            "product_code (live domain, retired codes mapped explicitly)",
            "inception_date", "expiry_date", "policy_status (canonical domain)",
            "status_effective_from/to", "gross_written_premium_gbp", "ipt_rate", "channel", "broker_key",
        ],
        "sources": [
            "POLARIS POLICY", "LEGACY_PAS PLCYMSTR (Julian dates, pence)",
            "LIFE400 POLMST via POLMSTEX (YYMMDD, CNTRSTS)",
        ],
        "notes": (
            "'Active' becomes a set of named, tested views over policy_status history "
            "(active_uw, active_finance, active_claims, active_life) rather than four "
            "hardcoded flags."
        ),
    },
    {
        "domain": "Claim",
        "purpose": "One record per claim with an explicit event date model.",
        "key": "claim_key; natural key (source_system, claim_number)",
        "core_attributes": [
            "claim_key", "policy_key", "claimant_party_key", "loss_date (DATE)",
            "notification_date (DATE)", "claim_status (canonical)", "cause_code",
            "incurred_amount_gbp", "paid_amount_gbp", "outstanding_reserve_gbp",
            "fraud_indicator (Y/N/SUSPECTED)", "fraud_score", "fraud_score_scale",
        ],
        "sources": ["Guidewire ClaimCenter", "LEGACY_CLM (IMS)", "Broker bordereaux"],
        "notes": (
            "loss_date is parsed once, at ingestion, per source contract — removing "
            "INC0067812 by construction. 'S' is preserved as SUSPECTED rather than "
            "collapsed to Y or N."
        ),
    },
    {
        "domain": "Premium & Billing",
        "purpose": "Written, collected and earned premium on one agreed basis with alternates as named measures.",
        "key": "premium_transaction_key; policy_key + period for earned measures",
        "core_attributes": [
            "policy_key", "transaction_type", "transaction_date", "gross_amount_gbp",
            "ipt_amount_gbp", "commission_amount_gbp", "collection_method",
            "apf_account_key", "earned_premium_365 (primary)",
            "earned_premium_1_12 / earned_premium_1_24 (reported as reconciling measures)",
        ],
        "sources": ["BILLING_DB.PREMIUM_TRANSACTIONS", "CORE_BANKING_DB.ACCOUNTS", "POLARIS POLICY"],
        "notes": (
            "Adopt 365ths as the single group basis (it is already the actuarial and "
            "UW rate-monitoring basis) and publish the 1/12ths and 1/24ths variants as "
            "explicitly named reconciling measures with a tested bridge, replacing the "
            "manual true-up workbook."
        ),
    },
    {
        "domain": "Reinsurance",
        "purpose": "Treaties, cessions and outward bordereaux.",
        "key": "treaty_key; cession grain policy_key + treaty_key + period",
        "core_attributes": [
            "treaty_key", "treaty_type", "line_of_business", "sii_line_of_business",
            "reinsurer", "cession_pct", "retention_gbp", "limit_gbp", "uw_year", "ceded_premium_gbp",
        ],
        "sources": ["REINSURANCE_DB.TREATY", "Broker bordereaux (14 brokers)"],
        "notes": (
            "The product -> Solvency II LoB mapping becomes one seed table with a "
            "uniqueness test, consumed by both QRT and bordereaux models."
        ),
    },
    {
        "domain": "Life",
        "purpose": "Term-life contracts from LIFE400 with their own measures kept distinct.",
        "key": "life_policy_key; natural key LIFE_POLICY_ID",
        "core_attributes": [
            "life_policy_key", "party_key (probabilistic, with confidence)", "plan_code",
            "contract_status", "sum_assured_gbp", "modal_premium_gbp", "pay_frequency",
            "annualised_premium_in_force_gbp", "insured_birth_date (century resolved once)",
        ],
        "sources": ["LIFE400 POLMST via POLMSTEX"],
        "notes": (
            "Annualised Premium In Force is modelled as its own measure and is never "
            "additive with P&C earned premium; the Group Premium KPI is redefined."
        ),
    },
]

PLATFORM_RECOMMENDATION = {
    "target": "Snowflake + dbt, with domain-aligned data products and contract-tested domain APIs",
    "why": [
        "The estate's core problem is duplicated logic, not compute: seven engines each "
        "re-implement the same rules. dbt gives one version-controlled, tested "
        "implementation per rule with lineage that can be diffed in review.",
        "Snowflake removes the Teradata/DataStage/SAS licence and skills exposure in one "
        "target, supports the fixed-width and delimited landing patterns already in use, "
        "and its zero-copy clone plus time travel make parallel-run reconciliation cheap.",
        "Identity resolution needs a stateful, auditable match store; Snowflake plus dbt "
        "snapshots gives survivorship history that today exists nowhere.",
        "Column-level masking policies and tokenisation replace the NINO masking sprawl "
        "and close AR-118 at the platform layer rather than per pipeline.",
    ],
    "alternatives": [
        {"option": "Databricks + Delta Live Tables",
         "verdict": "Viable",
         "reasoning": (
             "Strong for the probabilistic life/marketing matching workload, but the estate "
             "is overwhelmingly SQL and the in-house skill base is SQL/SAS; a Spark-first "
             "target increases retraining cost with no compensating benefit for these workloads."
         )},
        {"option": "Microsoft Fabric / Synapse",
         "verdict": "Viable",
         "reasoning": (
             "Attractive if the group is Azure-committed, but the OneLake/Fabric item model "
             "is less mature for contract-tested domain products, and mainframe/AS-400 "
             "landing patterns need more custom work."
         )},
        {"option": "Modernise in place (Teradata + Informatica IDMC)",
         "verdict": "Rejected",
         "reasoning": (
             "Lowest migration risk but leaves DataStage 9.1, the lost LIFE_POLICY_LOAD "
             "source, the AS/400 key-person risk and the four-scheduler problem untouched. "
             "It fixes none of the seven finding categories."
         )},
        {"option": "Lakehouse on open table formats, self-managed",
         "verdict": "Rejected",
         "reasoning": (
             "Highest ceiling, but requires platform engineering capability that the current "
             "operating model (two 5250-literate FTEs, a lost job source, a stale on-call rota) "
             "does not have."
         )},
    ],
    "services": [
        {"service": "Party Domain Service",
         "owns": "party, party_xref, match candidates and survivorship",
         "contract": "party_by_key, party_search, party_xref_resolve (REST + Snowflake secure views)",
         "dq": "Uniqueness of party_key; xref coverage per source with alert thresholds; "
               "suspect-queue age SLO replacing the 41k unworked backlog",
         "owner": "MDM team"},
        {"service": "Policy Domain Service",
         "owns": "policy, policy_status_history, product reference",
         "contract": "policy_by_number, policies_for_party, active_policy views per definition",
         "dq": "Status domain test, product-code domain test (retired codes mapped, never dropped), "
               "canonical policy-number format test",
         "owner": "Policy Platform"},
        {"service": "Claim Domain Service",
         "owns": "claim, claim_event, fraud scores",
         "contract": "claim_by_number, claims_for_policy, claims_for_party",
         "dq": "loss_date <= notification_date <= run date (reinstating DQR-033), "
               "fraud_indicator domain test including SUSPECTED",
         "owner": "Claims Platform"},
        {"service": "Premium & Billing Domain Service",
         "owns": "premium transactions, earned premium measures, IPT",
         "contract": "earned_premium(policy, period, basis), collections_for_policy",
         "dq": "Basis bridge test (365ths vs 1/12ths vs 1/24ths within tolerance), "
               "IPT rate sourced from one reference table",
         "owner": "Finance MI"},
        {"service": "Reinsurance Domain Service",
         "owns": "treaties, cessions, outward bordereaux, SII LoB mapping seed",
         "contract": "cessions_for_policy, outward_bordereau(period)",
         "dq": "One-to-one product -> SII LoB mapping test shared by QRT and bordereaux",
         "owner": "RI team"},
        {"service": "Life Domain Service",
         "owns": "life policies, API measure, life status",
         "contract": "life_policy_by_id, life_policies_for_party (with match confidence)",
         "dq": "Century-resolution test on all YYMMDD dates; match-confidence distribution monitoring",
         "owner": "Life Ops"},
    ],
    "roadmap": [
        {"phase": "0. Stabilise (0-3 months)",
         "actions": [
             "Freeze the four-scheduler estate behind one Control-M source of truth; remove the "
             "duplicate cron entries and the ksh cross-pipeline kick.",
             "Reconstruct LIFE_POLICY_LOAD from POLMSTEX_feed_spec.md, LIFE_DB DDL and the LIFE400 "
             "COBOL source, and check the reconstruction into version control.",
             "Close AR-118 by tokenising NINO at ingestion.",
         ],
         "risks": "Reconstruction cannot be validated against the lost original except by parallel run."},
        {"phase": "1. Land and mirror (3-6 months)",
         "actions": [
             "Land all eleven inventoried feeds plus the five unlisted ones into Snowflake raw, "
             "byte-faithful, with source contracts declared in dbt.",
             "Build staging models that parse each format exactly once (dates, pence, policy refs).",
         ],
         "risks": "Mainframe/AS-400 connectivity and file-transfer security rework."},
        {"phase": "2. Resolve identity (6-12 months)",
         "actions": [
             "Stand up the Party domain with deterministic then probabilistic matching, "
             "an auditable suspect queue and survivorship rules replacing the undocumented "
             "longest-string email rule.",
             "Backfill party_xref for the life and marketing books.",
         ],
         "risks": "Match rate above 55% requires data remediation, not only better algorithms."},
        {"phase": "3. Converge definitions (9-15 months)",
         "actions": [
             "Publish one earned-premium basis with named reconciling measures; retire the manual "
             "true-up workbook.",
             "Replace the four active-policy flags with named, tested views and agree owners.",
         ],
         "risks": "Requires Finance/UW/Claims/Actuarial governance sign-off, unresolved since 2019."},
        {"phase": "4. Re-platform consumption (12-24 months)",
         "actions": [
             "Replace PolicyInquiryService with contract-tested domain APIs, running both in "
             "parallel behind a facade; discover and migrate the unknown consumers.",
             "Retire DataStage 9.1, then the SAS insurance pipeline, then LIFE400 once the life "
             "domain is proven.",
         ],
         "risks": "Unknown SOAP consumers; LIFE400 retirement depends on the ADDRMST repatriation."},
    ],
}

EXEC_SUMMARY = {
    "headline": (
        "Albion's analytical estate spans seven technologies and cannot produce a single "
        "agreed number for a customer, a policy or a premium. The root cause is not any "
        "one legacy platform: it is that every business community was allowed to "
        "re-implement shared logic in its own engine, and the governance artefacts "
        "record fewer implementations than actually exist."
    ),
    "points": [
        "Six identifier schemes and two partial, manually maintained crosswalks leave the "
        "MDM match rate at 55% with 41k unworked suspects; the entire life book has no "
        "person key at all.",
        "Every registered DQ rule that has more than one implementation has divergent "
        "implementations. The registry itself understates the count — the SAS postcode "
        "macro and the COBOL check were never registered.",
        "Three earned-premium bases, four active-policy definitions, two incompatible risk "
        "scales and an inverted fraud-flag mapping are all live simultaneously.",
        "One production job (DataStage LIFE_POLICY_LOAD) is the sole bridge between the "
        "life book and the group warehouse, runs on a platform out of support since 2018, "
        "and its source is lost.",
        "The fastest route out is not tool-for-tool replacement: it is to make each shared "
        "rule exist exactly once, in a tested, version-controlled model layer, and to give "
        "each canonical domain an owner and a contract.",
    ],
}
