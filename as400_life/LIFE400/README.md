# LIFE400 — Term Life Policy System (AS/400 / IBM i)

Provident Mutual Assurance Co. — Term Life Policy System | 
Platform: IBM AS/400 (iSeries) | ILE COBOL + DDS + ILE CL | 
Original Build: March 24 2026 (mimics 1997–1998) | Library: `LIFE400`

---

## Overview

LIFE400 is the AS/400 version of the term life insurance administration system. It covers the full policy lifecycle across three business domains:

| Domain | Batch Program | Online Program | CL Submitter |
|--------|--------------|---------------|--------------|
| New Business & Underwriting | `NBUWB` | `NBUWMNT` | `RUNNBUW` |
| Policy Servicing & Billing | `SVCBILB` | `SVCMNT` | `RUNSVC` |
| Claims Adjudication | `CLMADJB` | `CLMMNT` | `RUNCLM` |

Interactive entry point: `STRTLIFE` → `MAINMENU`
Nightly batch: `DLYUPD` (scheduled via `ADDJOBSCDE`)

---

## Repository Structure

```
LIFE400/
├── QCPYSRC/          ILE COBOL copybooks
│   └── POLDATA.cpy   Shared policy master record layout
├── QDDSSRC/          DDS source (database files, display files, printer files)
│   ├── POLMST.pf     Policy master physical file
│   ├── CLMPF.pf      Claims physical file
│   ├── SVCPF.pf      Service amendments physical file
│   ├── POLMSTL1.lf   Logical file over POLMST (keyed by POLID)
│   ├── MNUDSPF.dspf  Main menu 5250 display file
│   ├── NBUWDSPF.dspf New business entry display file
│   ├── CLMDSPF.dspf  Claims entry display file
│   ├── SVCDSPF.dspf  Servicing / inquiry display file
│   ├── POLRPT.prtf   Policy listing printer file
│   └── CLMRPT.prtf   Claims report printer file
├── QCBLLESRC/        ILE COBOL source members
│   ├── NBUWB.cble    Batch: new business & underwriting
│   ├── CLMADJB.cble  Batch: claims adjudication
│   ├── SVCBILB.cble  Batch: servicing & billing
│   ├── MAINMENU.cble Online: main menu
│   ├── NBUWMNT.cble  Online: new business maintenance
│   ├── CLMMNT.cble   Online: claims maintenance
│   ├── SVCMNT.cble   Online: servicing maintenance
│   └── POLMSTINQ.cble Online: policy master inquiry (read-only)
└── QCLSRC/           ILE CL source members
    ├── STRTLIFE.clle  Start life system (interactive entry point)
    ├── RUNNBUW.clle   Submit NB batch job
    ├── RUNCLM.clle    Submit claims batch job
    ├── RUNSVC.clle    Submit servicing batch job
    └── DLYUPD.clle    Nightly daily update (grace/lapse sweep)
```

---

## Plans and Products

| Code | Description | Issue Ages | Min SA | Max SA |
|------|-------------|-----------|--------|--------|
| T1001 | 10-Year Term | 18–60 | 10,000,000 | 50,000,000,000 |
| T2001 | 20-Year Term | 18–55 | 10,000,000 | 90,000,000,000 |
| T6501 | Term-to-65 | 18–50 | 10,000,000 | 75,000,000,000 |

---

## Building on a Real AS/400 / IBM i

### Step 1 — Create the Library and Source Physical Files

```
CRTLIB LIB(LIFE400) TYPE(*PROD) TEXT('PROVIDENT MUTUAL INS SYSTEM')

CRTSRCPF FILE(LIFE400/QCPYSRC)   RCDLEN(92)  TEXT('COBOL COPYBOOKS')
CRTSRCPF FILE(LIFE400/QDDSSRC)   RCDLEN(92)  TEXT('DDS SOURCE')
CRTSRCPF FILE(LIFE400/QCBLLESRC) RCDLEN(92)  TEXT('ILE COBOL SOURCE')
CRTSRCPF FILE(LIFE400/QCLSRC)    RCDLEN(92)  TEXT('ILE CL SOURCE')
```

### Step 2 — Upload Source Members

Upload each file from this repo into the corresponding source physical file using FTP or IFS copy, then use `CPYFRMSTMF` to copy into source members.

### Step 3 — Create Database Files

```
CRTPF FILE(LIFE400/POLMST)   SRCFILE(LIFE400/QDDSSRC) SRCMBR(POLMST)   TEXT('POLICY MASTER')
CRTPF FILE(LIFE400/CLMPF)    SRCFILE(LIFE400/QDDSSRC) SRCMBR(CLMPF)    TEXT('CLAIMS')
CRTPF FILE(LIFE400/SVCPF)    SRCFILE(LIFE400/QDDSSRC) SRCMBR(SVCPF)    TEXT('SERVICE REQUESTS')
CRTLF FILE(LIFE400/POLMSTL1) SRCFILE(LIFE400/QDDSSRC) SRCMBR(POLMSTL1) TEXT('POLMST LOGICAL')
```

### Step 4 — Create Display and Printer Files

```
CRTDSPF FILE(LIFE400/MNUDSPF)   SRCFILE(LIFE400/QDDSSRC) SRCMBR(MNUDSPF)
CRTDSPF FILE(LIFE400/NBUWDSPF)  SRCFILE(LIFE400/QDDSSRC) SRCMBR(NBUWDSPF)
CRTDSPF FILE(LIFE400/CLMDSPF)   SRCFILE(LIFE400/QDDSSRC) SRCMBR(CLMDSPF)
CRTDSPF FILE(LIFE400/SVCDSPF)   SRCFILE(LIFE400/QDDSSRC) SRCMBR(SVCDSPF)
CRTPRTF FILE(LIFE400/POLRPT)    SRCFILE(LIFE400/QDDSSRC) SRCMBR(POLRPT)
CRTPRTF FILE(LIFE400/CLMRPT)    SRCFILE(LIFE400/QDDSSRC) SRCMBR(CLMRPT)
```

### Step 5 — Compile ILE COBOL Programs

```
CRTCBLMOD MODULE(LIFE400/NBUWB)     SRCFILE(LIFE400/QCBLLESRC) SRCMBR(NBUWB)
CRTCBLMOD MODULE(LIFE400/CLMADJB)   SRCFILE(LIFE400/QCBLLESRC) SRCMBR(CLMADJB)
CRTCBLMOD MODULE(LIFE400/SVCBILB)   SRCFILE(LIFE400/QCBLLESRC) SRCMBR(SVCBILB)
CRTCBLMOD MODULE(LIFE400/MAINMENU)  SRCFILE(LIFE400/QCBLLESRC) SRCMBR(MAINMENU)
CRTCBLMOD MODULE(LIFE400/NBUWMNT)   SRCFILE(LIFE400/QCBLLESRC) SRCMBR(NBUWMNT)
CRTCBLMOD MODULE(LIFE400/CLMMNT)    SRCFILE(LIFE400/QCBLLESRC) SRCMBR(CLMMNT)
CRTCBLMOD MODULE(LIFE400/SVCMNT)    SRCFILE(LIFE400/QCBLLESRC) SRCMBR(SVCMNT)
CRTCBLMOD MODULE(LIFE400/POLMSTINQ) SRCFILE(LIFE400/QCBLLESRC) SRCMBR(POLMSTINQ)

CRTPGM PGM(LIFE400/NBUWB)     MODULE(LIFE400/NBUWB)
CRTPGM PGM(LIFE400/CLMADJB)   MODULE(LIFE400/CLMADJB)
CRTPGM PGM(LIFE400/SVCBILB)   MODULE(LIFE400/SVCBILB)
CRTPGM PGM(LIFE400/MAINMENU)  MODULE(LIFE400/MAINMENU)
CRTPGM PGM(LIFE400/NBUWMNT)   MODULE(LIFE400/NBUWMNT)
CRTPGM PGM(LIFE400/CLMMNT)    MODULE(LIFE400/CLMMNT)
CRTPGM PGM(LIFE400/SVCMNT)    MODULE(LIFE400/SVCMNT)
CRTPGM PGM(LIFE400/POLMSTINQ) MODULE(LIFE400/POLMSTINQ)
```

### Step 6 — Compile ILE CL Programs

```
CRTCLMOD MODULE(LIFE400/STRTLIFE) SRCFILE(LIFE400/QCLSRC) SRCMBR(STRTLIFE)
CRTCLMOD MODULE(LIFE400/RUNNBUW)  SRCFILE(LIFE400/QCLSRC) SRCMBR(RUNNBUW)
CRTCLMOD MODULE(LIFE400/RUNCLM)   SRCFILE(LIFE400/QCLSRC) SRCMBR(RUNCLM)
CRTCLMOD MODULE(LIFE400/RUNSVC)   SRCFILE(LIFE400/QCLSRC) SRCMBR(RUNSVC)
CRTCLMOD MODULE(LIFE400/DLYUPD)   SRCFILE(LIFE400/QCLSRC) SRCMBR(DLYUPD)

CRTPGM PGM(LIFE400/STRTLIFE) MODULE(LIFE400/STRTLIFE)
CRTPGM PGM(LIFE400/RUNNBUW)  MODULE(LIFE400/RUNNBUW)
CRTPGM PGM(LIFE400/RUNCLM)   MODULE(LIFE400/RUNCLM)
CRTPGM PGM(LIFE400/RUNSVC)   MODULE(LIFE400/RUNSVC)
CRTPGM PGM(LIFE400/DLYUPD)   MODULE(LIFE400/DLYUPD)
```

### Step 7 — Create Supporting Objects

```
/* JOB QUEUE AND JOB DESCRIPTION */
CRTJOBD JOBD(LIFE400/LIFEJD) JOBQ(LIFE400/LIFEQ) TEXT('LIFE400 JOB DESC')
CRTJOBQ JOBQ(LIFE400/LIFEQ) TEXT('LIFE400 JOB QUEUE')

/* OUTPUT QUEUE */
CRTOUTQ OUTQ(LIFE400/LIFEOUTQ) TEXT('LIFE400 OUTPUT QUEUE')

/* MESSAGE QUEUE */
CRTMSGQ MSGQ(LIFE400/LIFEMSGQ) TEXT('LIFE400 MESSAGE QUEUE')

/* SCHEDULE NIGHTLY JOB */
ADDJOBSCDE JOB(DLYUPD) CMD(CALL LIFE400/DLYUPD) +
    FRQ(*WEEKLY) SCDDAY(*ALL) SCDTIME(233000) +
    JOBD(LIFE400/LIFEJD) TEXT('LIFE400 NIGHTLY UPDATE')
```

### Step 8 — Start the System

```
CALL LIFE400/STRTLIFE
```

---

## 5250 Screen Reference

| Screen | Program | Description |
|--------|---------|-------------|
| MNUDSPF/MAINSCR | MAINMENU | Main menu — route to subsystems |
| NBUWDSPF/NBHDR | NBUWMNT | New business: policy/plan header |
| NBUWDSPF/NBINSKD | NBUWMNT | New business: insured details |
| NBUWDSPF/NBBENEFIT | NBUWMNT | New business: benefit/sum assured |
| NBUWDSPF/NBRIDERS | NBUWMNT | New business: rider entry |
| NBUWDSPF/NBRESULT | NBUWMNT | New business: issue result |
| CLMDSPF/CLMHDR | CLMMNT | Claims: claim ID + policy lookup |
| CLMDSPF/CLMDETAIL | CLMMNT | Claims: cause, date, beneficiary |
| CLMDSPF/CLMDOCS | CLMMNT | Claims: document checklist |
| CLMDSPF/CLMRESULT | CLMMNT | Claims: adjudication result |
| SVCDSPF/SVCHDR | SVCMNT / POLMSTINQ | Servicing: policy lookup |
| SVCDSPF/SVCPOL | SVCMNT / POLMSTINQ | Servicing: current policy display |
| SVCDSPF/SVCAMEND | SVCMNT | Servicing: amendment input |
| SVCDSPF/SVCRESULT | SVCMNT | Servicing: amendment result |

**Common Function Keys:**
`F3=Exit` · `F5=Refresh` · `F6=Submit/Issue/Apply` · `F10=Reinstate` · `F12=Cancel`

---

## Business Rules Summary

**New Business (50+ rules):** Issue age limits by plan, sum assured limits, maturity age cap, T65 occupation restriction, severe occupation auto-decline, UW class determination (Preferred/Standard/Table-B/Decline), mortality rate by age band, gender/smoker/occupation/UW rating factors, rider validation (ADB age cap, WOP age range, CI SA cap), modal premium loading (A/S/Q/M), reinsurance referral >45B SA, manual UW referral triggers.

**Servicing:** Grace period transition (Active→Grace after 30 days overdue), lapse transition (Active/Grace→Lapsed after grace expires), reinstatement within 730-day window, plan change with age/maturity validation, SA increase >25% or >25B requires UW, billing mode change with modal recalculation, add/remove ADB01 rider with age check.

**Claims:** Death-only claim type support, active/grace eligibility check, contestability period investigation (2 years), suicide window exclusion (2 years), accidental death ADB rider payout, grace period deduction, loan balance deduction, settlement floor at zero, payment via check or ACH.

---

## Y2K Notes

All date fields use 8-digit `YYYYMMDD` format. Programs reviewed November 1998.
See `*Y2K-REVIEWED 1998-11-14` comments throughout source members.

---

*LIFE400 — Provident Mutual Assurance Co. — AS/400 Term Life System*
*ILE COBOL V3R7 · OS/400 V4R2 · IBM AS/400 Model 9406*
