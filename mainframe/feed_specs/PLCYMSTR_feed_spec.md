# Feed Specification — PLCYMSTR (Policy Master Daily Extract)

| Property | Value |
|---|---|
| Feed ID | FD-001 |
| Source | LEGACY_PAS (mainframe VSAM), JCL `PLCYEXTR` |
| Frequency | Daily 02:40 GMT (NDM transfer 03:00) |
| Format | Fixed width, LRECL 80, per copybook `PLCYMSTR.cpy` |
| Landing | `/interface/inbound/plcymstr/PLCYMSTR_DYYMMDD.dat` |
| Consumers | Informatica `wf_POLICY_MASTER_DAILY`; Teradata `04_stg_policy_360.bteq`; Actuarial SAS (via the *separate* ACT copy — see CR-2014-311) |

## Layout
| Pos | Len | Field | Notes |
|---|---|---|---|
| 1 | 18 | POLICY_NO | Hyphens stripped vs POLARIS format `ALB-XXX-9999999` |
| 19 | 10 | CLIENT_NO | Zero-padded numeric. **Not** PARTY_ID — crosswalk via XREF_CLIENT_PARTY |
| 29 | 4 | PRODUCT_CD | |
| 33 | 5 | INCEPT_DT | Julian YYDDD, Y2K windowed |
| 38 | 11 | ANNL_PREM | Pence, implied 2dp |
| 49 | 2 | STATUS | See 88-levels; "active" definition disputed between UW and Finance |
| 51 | 8 | POSTCODE | No embedded space; validation is first-char-alpha only (PR4471) |
| 59 | 20 | SURNAME | Uppercase |

## Known issues
- Julian date conversion re-implemented in **three** places (Informatica `EXP_POLICY_DATES`, BTEQ `04_stg_policy_360`, SAS `%julian_to_date` in actuarial folder) with different Y2K windowing cutoffs (49 vs 50).
- Duplicate feed to Actuarial bypasses all DWH data-quality gates.
