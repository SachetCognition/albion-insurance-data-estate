# Albion General Insurance Group — Data Feed Inventory
*Maintained by Data Governance. Last full audit 2024; entries marked (?) unverified since.*

| Feed | Source | Tech | Frequency | Consumers | Owner | Overlapping attributes |
|---|---|---|---|---|---|---|
| FD-001 PLCYMSTR | LEGACY_PAS (mainframe VSAM) | JCL + NDM fixed-width | Daily 02:40 | INFA wf_POLICY_MASTER_DAILY; BTEQ 04; **separate actuarial copy (CR-2014-311)** | Mainframe Svcs | POLICY_NO, CLIENT_NO, POSTCODE, PREMIUM |
| FD-002 POLARIS policy CDC | POLARIS PAS (Oracle) | Informatica CDC | 15 min | POLICY_ADMIN_DB | Policy Platform | POLICY_NO, PARTY_ID, PREMIUM |
| FD-003 Guidewire CC events | Guidewire ClaimCenter | INFA wf_CLAIMS_FNOL_INTRADAY | 30 min | CLAIMS_DB | Claims Platform | CLAIM_NO, POLICY_NO, LOSS_DT, FRAUD_FLAG |
| FD-004 LEGACY_CLM | IMS mainframe | JCL extract per CLMHIST.cpy | Daily | Same INFA workflow (union) | Mainframe Svcs | Same as FD-003, different formats/domains |
| FD-005 Broker bordereaux | 14 brokers, SFTP | ksh bdx_transfer + INFA wf_RI_BORDEREAUX | Monthly | REINSURANCE_DB | RI team | POLICY_NO (re-keyed), INCURRED, PAID |
| FD-006 Banking core | APF core banking | BTEQ 01–03 (Premium Finance pipeline) | Daily 02:00 | STG_CUSTOMER_360 etc., SAS 01–04 | APF MI | CUSTOMER_ID ↔ PARTY.LEGACY_CUSTOMER_ID; DOB, EMAIL, POSTCODE |
| FD-007 Premium txns | Billing platform | BTEQ 06 + INFA wf_BILLING_PREMIUM_RECON | Daily/Monthly | Finance close, QRT | Finance MI | POLICY_NO, APF_ACCOUNT_ID ↔ banking ACCOUNTS |
| FD-008 Bureau scores | Credit bureau | sftp CSV (?) | Weekly | SAS 03_risk_scoring (banking) | APF Risk | CUSTOMER_ID; not joined to insurance despite fraud team requests |
| FD-009 GSS payroll estate | EHRP etc. | Legacy INFA folder (see legacy_shared_services) | Biweekly | HR BI (?) | GSS | SSN-era masking job is ancestor of NINO masking in two other stacks |

## Attribute overlap hotspots (2024 audit extract)
- **Person identity**: `CUSTOMER_ID` (banking) / `PARTY_ID` (POLARIS) / `CLIENT_NO` (mainframe) / `customer_ref` (SOAP API, mixed scheme). Crosswalks: `PARTY.LEGACY_CUSTOMER_ID` (~55% populated) and `REF_DB.XREF_CLIENT_PARTY` (manual).
- **Postcode**: captured in 5 systems, validated 4 different ways (DQR-014).
- **Email**: 3 stores, 2 validators, 1 store unvalidated; case handling differs.
- **Dates**: ISO (banking), DD/MM/YYYY text (POLARIS party, claims loss date), Julian YYDDD (mainframe), MM/DD/YYYY assumption bug (INFA claims path).
- **Money**: pounds decimal, pence implied-decimal (mainframe), text-with-£ (bordereaux).

## 2026 additions (post life/marketing estate discovery)
| Feed | Source | Tech | Frequency | Consumers | Owner | Overlapping attributes |
|---|---|---|---|---|---|---|
| FD-010 POLMSTEX | LIFE400 (AS/400, Provident Mutual) | CL LIFEXTR + FTP (plaintext creds) | Nightly 23:30 | DataStage LIFE_POLICY_LOAD → LIFE_DB | Life Ops | LIFE_POLICY_ID (5th id scheme), INSNAME/DOB (fuzzy party match), dates YYMMDD pivot 40 |
| FD-011 Partner loyalty | Retail partners (affinity programme) | Delimited files → DataStage marts | Weekly | RETAIL/ACTIVATIONSALES marts, Bouns_Program | Marketing | MKTG_CUST_ID (6th id scheme, never crosswalked), name/email dedupe only |

**Identity schemes now in play: 6** — CUSTOMER_ID (banking), PARTY_ID (POLARIS),
CLIENT_NO (mainframe P&C), customer_ref (SOAP, mixed), LIFE_POLICY_ID-only
(life, no person key at all), MKTG_CUST_ID (partner loyalty).
**Y2K pivot years in play: 3** — 49 (Informatica), 50 (SAS julian macro), 40 (LIFE400/DataStage).
**Postcode handling variants: 5** — the four registered/unregistered P&C variants
plus LIFE400: *no postcode field at all*; correspondence addresses live in
ADDRMST on the AS/400, descoped from the 2016 integration (GDPR SAR impact).
