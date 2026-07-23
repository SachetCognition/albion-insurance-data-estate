# Known Issues / Accepted Risks (extract — the full register is a SharePoint list)

| Ref | Summary | Status |
|---|---|---|
| INC0067812 | Guidewire loss dates parsed as MM/DD/YYYY in Informatica but DD/MM/YYYY in BTEQ; ~40% of claims have divergent loss dates between stores | Open since 2023 |
| AR-118 | SAS fraud pipeline joins on raw NINO; masking applied on output only | Accepted risk (DPIA 2022) |
| PR4471 | Mainframe postcode validation is first-char-alpha only | Won't fix |
| CR-2014-311 | Actuarial receive a separate policy master copy bypassing DWH DQ | Working as designed (!) |
| CR-2021-088 | Insurance BTEQ cloned from banking BTEQ; never re-converged | Backlog |
| CR-2022-410 | Duplicate-key validation skipped >1m rows in validate_policy.sas | "Temporary" |
| — | Earned premium computed three ways (1/12ths, 1/24ths, 365ths) | Manual true-up |
| — | 'Active policy' has three concurrent business definitions | Unresolved since 2019 |
| — | SII LoB mapping drifted between SAS and Informatica (PET) | Undetected until? |
| — | 41k unworked MDM suspects; party match rate plateaued at 55% | Underfunded |
| — | IPT rate 12% hardcoded in 3 codebases plus 1 unused parameter | Sleeping risk |
| — | LIFE400 never rebranded post-2016; screens/reports still say Provident Mutual; ops require 5250 knowledge held by 2 FTEs (1 retiring) | Risk log |
| — | DataStage LIFE_POLICY_LOAD .dsx export lost; job exists only in prod repository (DS 9.1, out of support 2018) | Frozen |
| — | POLMSTEX dates truncated to YYMMDD at extract; pivot 40 vs 49 vs 50 elsewhere; DOBs 1925-1939 at risk of +100y shift | Open |
| — | Life correspondence addresses (ADDRMST) never migrated; GDPR SARs need manual 5250 session | Accepted 2018 |
| — | LIFEXTR FTPs via plaintext credentials in QGPL/FTPSCRIPT | Security backlog |
| — | 'Bouns_Program' job name typo enshrined in prod since 2013; downstream tables inherit it | Won't fix |
| — | Group Premium KPI adds Life API to P&C earned premium (methodologically incompatible) | Unnoticed |
