      ******************************************************************
      * CLMHIST - CLAIM HISTORY SEGMENT (LEGACY_CLM / IMS DB)          *
      * FED TO DWH VIA CLMEXTR JCL, CONSUMED BY INFA wf_CLAIMS_FNOL    *
      ******************************************************************
       01  CLM-HIST-REC.
           05  CLM-CLAIM-NO             PIC X(12).
           05  CLM-POLICY-NO            PIC X(18).
           05  CLM-LOSS-DT              PIC 9(08).
      *        FORMAT DDMMYYYY (UK) - DOWNSTREAM INFA EXPECTS
      *        MM/DD/YYYY, CONVERSION DONE IN EXP_CLAIM_DATES.
      *        SAS FRAUD MODEL READS THIS FIELD RAW. SEE INC0067812.
           05  CLM-CAUSE-CD             PIC X(20).
           05  CLM-INCURRED-AMT         PIC S9(09)V99 COMP-3.
           05  CLM-PAID-AMT             PIC S9(09)V99 COMP-3.
           05  CLM-STATUS               PIC X(01).
               88  CLM-OPEN             VALUE 'O'.
               88  CLM-SETTLED          VALUE 'S'.
               88  CLM-REOPENED         VALUE 'R'.
               88  CLM-DECLINED         VALUE 'D'.
           05  CLM-FRAUD-IND            PIC X(01).
               88  CLM-FRAUD-CONFIRMED  VALUE 'Y'.
               88  CLM-FRAUD-SUSPECTED  VALUE 'S'.
      *        GUIDEWIRE_CC USES Y/N/BLANK - 'S' HAS NO EQUIVALENT
           05  FILLER                   PIC X(08).
