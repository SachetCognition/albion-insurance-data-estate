# Current-State Architecture (as understood)

```
AS/400 (LIFE400 - Provident Mutual life book: ILE COBOL/CL/DDS, 5250)
   │  CL LIFEXTR ► IFS ► FTP (plaintext creds), fixed-width YYMMDD
   ▼
DATASTAGE 9.1 (out of support; LIFE_POLICY_LOAD source lost;
               Retail Partnerships marts + Bouns_Program loyalty)
   │
   ├──────────────────────────────► TERADATA LIFE_DB (pivot-40 century view)
   ▼
MAINFRAME (LEGACY_PAS, LEGACY_CLM/IMS, GSS payroll)
   │  JCL + NDM fixed-width / copybooks
   ▼
INFORMATICA PowerCenter 10.5 (5 insurance folders + legacy GSS folders)
   │            │
   │            └────────► Oracle MDM hub / marts (NINO masked here only)
   ▼
TERADATA (POLICY_ADMIN_DB, CLAIMS_DB, BILLING_DB, ETL_STAGING_DB,
          CORE_BANKING_DB, TXN_PROCESSING_DB, DATA_PRODUCTS_DB, ACTUARIAL_DB,
          REGULATORY_DB, REF_DB)
   │  BTEQ staging (2 divergent clones of the same pipeline pattern)
   ▼
SAS 9.4 (Premium Finance 01–04; Insurance 05–09; separate mainframe feed
         bypass into Actuarial)
   │
   ├──► Qlik dashboards (mixed 0–1 and 0–1000 risk scales side by side)
   ├──► QRT / Solvency II workbook (manual true-up journals)
   └──► GoldenGate replica ► Oracle ODS ► PL/SQL ► SOAP PolicyInquiryService
                                              (26h-stale data sold as real-time)
```

Scheduling: Control-M *and* cron *and* AS/400 ADDJOBSCDE *and* the DataStage
Director's own scheduler, with overlapping ownership of at least
three jobs. One known nightly race condition (MDM sync vs policy load).
