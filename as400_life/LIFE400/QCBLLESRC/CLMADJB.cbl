      *===============================================================*
      * PROGRAM:   CLMADJB                                           *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    D. BRENNAN                                        *
      * DATE:      1997-11-02                                        *
      * VERSION:   1.2                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *            1998-02-15 - ADDED ADB RIDER PAYOUT LOGIC        *
      *---------------------------------------------------------------*
      * BATCH CLAIMS ADJUDICATION                                    *
      * DOMAIN:  TERM LIFE - CLAIMS PROCESSING                       *
      * PURPOSE: VALIDATE CLAIM INTAKE, IDENTIFY INVESTIGATION       *
      *          TRIGGERS, ADJUDICATE COVERAGE, CALCULATE NET        *
      *          SETTLEMENT AMOUNT.                                   *
      *---------------------------------------------------------------*
      * CALLED BY: RUNCLM (CL)                                       *
      * FILES:     POLMST (I-O INDEXED), CLMPF (I-O INDEXED)        *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *---------------------------------------------------------------*
      * RETURN CODES:                                                 *
      *  00 - CLAIM APPROVED AND SETTLED                             *
      *  02 - PENDING INVESTIGATION                                  *
      *  11 - UNSUPPORTED CLAIM TYPE (ONLY DEATH CLAIMS SUPPORTED)  *
      *  12 - POLICY NOT ACTIVE OR IN GRACE (LAPSED/TERMINATED)     *
      *  13 - MISSING CORE CLAIM DATA                               *
      *  14 - MISSING REQUIRED DOCUMENTS - MANUAL REVIEW            *
      *  21 - SUICIDE WITHIN CONTESTABILITY WINDOW - REJECTED       *
      *  22 - DEATH AFTER POLICY EXPIRY - REJECTED                  *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMADJB.
       AUTHOR.     D. BRENNAN.
       DATE-WRITTEN. 1997-11-02.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-AS400.
       OBJECT-COMPUTER. IBM-AS400.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POLMST
               ASSIGN TO DATABASE-POLMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS PM-POLICY-ID
               FILE STATUS IS WS-POLMST-STATUS.
           SELECT CLMPF
               ASSIGN TO DATABASE-CLMPF
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS PM-CLAIM-ID
               FILE STATUS IS WS-CLMPF-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  POLMST.
       COPY POLDATA.
       FD  CLMPF.
       01  CLM-RECORD.
           05  CLM-CLAIM-ID          PIC X(12).
           05  CLM-POLICY-ID         PIC X(12).
           05  FILLER                PIC X(300).

       WORKING-STORAGE SECTION.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-CLMPF-STATUS           PIC X(02) VALUE SPACES.
       77  WS-RESULT-CODE            PIC 9(02) VALUE 0.
       77  WS-RESULT-MESSAGE         PIC X(100) VALUE SPACES.
       77  WS-DAYS-SINCE-ISSUE       PIC 9(07) VALUE 0.
       77  WS-DAYS-CONTESTABLE       PIC 9(07) VALUE 0.
       77  WS-DAYS-SUICIDE-WINDOW    PIC 9(07) VALUE 0.
       77  WS-RIDER-IDX              PIC 9(02) VALUE 0.
       77  WS-ADB-FOUND              PIC X VALUE 'N'.

       LINKAGE SECTION.
       01  LK-CLAIM-ID               PIC X(12).
       01  LK-POLICY-ID              PIC X(12).

       PROCEDURE DIVISION USING LK-CLAIM-ID LK-POLICY-ID.

       MAIN-PROCESS.
           OPEN I-O POLMST
           OPEN I-O CLMPF
           MOVE LK-POLICY-ID TO PM-POLICY-ID
           READ POLMST
               INVALID KEY
                   MOVE 12 TO WS-RESULT-CODE
                   MOVE 'POLICY RECORD NOT FOUND' TO WS-RESULT-MESSAGE
                   PERFORM 9000-RETURN-ERROR
                   CLOSE POLMST CLMPF
                   GOBACK
           END-READ
           MOVE LK-CLAIM-ID TO PM-CLAIM-ID
           PERFORM 1000-INITIALIZE
           PERFORM 1100-LOAD-PLAN-PARAMETERS
           PERFORM 1200-VALIDATE-CLAIM-INTAKE
           IF WS-RESULT-CODE NOT = 0
               PERFORM 9000-RETURN-ERROR
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST CLMPF
               GOBACK
           END-IF
           PERFORM 1300-DETERMINE-INVESTIGATION
           IF WS-RESULT-CODE = 2
               PERFORM 9000-RETURN-PENDING
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST CLMPF
               GOBACK
           END-IF
           PERFORM 1400-ADJUDICATE-COVERAGE
           IF WS-RESULT-CODE NOT = 0
               PERFORM 9000-RETURN-ERROR
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST CLMPF
               GOBACK
           END-IF
           PERFORM 1500-CALCULATE-SETTLEMENT
           PERFORM 1600-SETTLE-CLAIM
           REWRITE WS-POLICY-MASTER-REC
           CLOSE POLMST CLMPF
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - INITIALIZE                                             *
      *---------------------------------------------------------------*
       1000-INITIALIZE.
           MOVE ZEROS TO PM-CLAIM-PAYMENT-AMT
           MOVE ZEROS TO WS-RESULT-CODE
           MOVE SPACES TO WS-RESULT-MESSAGE
           MOVE 'N' TO WS-ADB-FOUND
      *Y2K-REVIEWED 1998-11-14
           IF PM-PROCESS-DATE = 0
               ACCEPT PM-PROCESS-DATE FROM DATE YYYYMMDD
           END-IF
           MOVE 'CLMADJB' TO PM-LAST-ACTION-USER
           MOVE PM-PROCESS-DATE TO PM-LAST-ACTION-DATE.

      *---------------------------------------------------------------*
      * 1100 - LOAD PLAN PARAMETERS   (CL-101)                       *
      *---------------------------------------------------------------*
       1100-LOAD-PLAN-PARAMETERS.
           EVALUATE PM-PLAN-CODE
               WHEN 'T1001'
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 30 TO PM-GRACE-DAYS
               WHEN 'T2001'
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 30 TO PM-GRACE-DAYS
               WHEN 'T6501'
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 30 TO PM-GRACE-DAYS
               WHEN OTHER
                   MOVE 21 TO WS-RESULT-CODE
                   MOVE 'INVALID PLAN CODE' TO WS-RESULT-MESSAGE
           END-EVALUATE.

      *---------------------------------------------------------------*
      * 1200 - VALIDATE CLAIM INTAKE   (CL-201 THRU CL-204)          *
      *---------------------------------------------------------------*
       1200-VALIDATE-CLAIM-INTAKE.
      * CL-201: ONLY DEATH CLAIMS SUPPORTED
           IF NOT PM-CLAIM-DEATH
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'ONLY DEATH CLAIMS ARE SUPPORTED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * CL-202: POLICY MUST BE ACTIVE OR IN GRACE
           IF NOT PM-STATUS-ACTIVE AND NOT PM-STATUS-GRACE
               MOVE 12 TO WS-RESULT-CODE
               MOVE 'POLICY IS NOT ACTIVE OR IN GRACE PERIOD'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * CL-203: CORE DATA REQUIRED
           IF PM-CLAIM-ID = SPACES OR
              PM-DATE-OF-DEATH = 0 OR
              PM-BENEFICIARY-NAME = SPACES
               MOVE 13 TO WS-RESULT-CODE
               MOVE 'MISSING CLAIM ID DATE OF DEATH OR BENEFICIARY'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * CL-204: REQUIRED DOCUMENTS
           IF PM-DEATH-CERT-RECD NOT = 'Y' OR
              PM-CLAIM-FORM-RECD NOT = 'Y' OR
              PM-ID-PROOF-RECD NOT = 'Y'
               MOVE 14 TO WS-RESULT-CODE
               MOVE 'MISSING REQUIRED DOCUMENTS - MANUAL REVIEW'
                   TO WS-RESULT-MESSAGE
               MOVE 2 TO WS-RESULT-CODE
           END-IF.

      *---------------------------------------------------------------*
      * 1300 - DETERMINE INVESTIGATION (CL-301 THRU CL-303)          *
      *---------------------------------------------------------------*
       1300-DETERMINE-INVESTIGATION.
           MOVE 'N' TO PM-INVESTIGATION-STATUS
      *Y2K-REVIEWED 1998-11-14
           COMPUTE WS-DAYS-SINCE-ISSUE =
               PM-DATE-OF-DEATH - PM-ISSUE-DATE
           COMPUTE WS-DAYS-CONTESTABLE =
               PM-CONTESTABILITY-YRS * 365
      * CL-301: DEATH WITHIN CONTESTABILITY PERIOD
           IF WS-DAYS-SINCE-ISSUE <= WS-DAYS-CONTESTABLE
               MOVE 'P' TO PM-INVESTIGATION-STATUS
               MOVE 2 TO WS-RESULT-CODE
               EXIT PARAGRAPH
           END-IF
      * CL-302: SUSPICIOUS CAUSE OF DEATH
           IF PM-CAUSE-UNKNOWN OR PM-CAUSE-HOMICIDE OR PM-CAUSE-SUICIDE
               MOVE 'P' TO PM-INVESTIGATION-STATUS
               MOVE 2 TO WS-RESULT-CODE
               EXIT PARAGRAPH
           END-IF
      * CL-303: ACCIDENTAL/HOMICIDE/UNKNOWN WITHOUT MEDICAL RECORDS
           IF (PM-CAUSE-ACCIDENT OR PM-CAUSE-HOMICIDE OR
               PM-CAUSE-UNKNOWN) AND
              PM-MEDICAL-RECORDS-RECD NOT = 'Y'
               MOVE 'P' TO PM-INVESTIGATION-STATUS
               MOVE 2 TO WS-RESULT-CODE
           END-IF.

      *---------------------------------------------------------------*
      * 1400 - ADJUDICATE COVERAGE    (CL-401 THRU CL-402)           *
      *---------------------------------------------------------------*
       1400-ADJUDICATE-COVERAGE.
      * CL-401: SUICIDE WITHIN SUICIDE WINDOW
           COMPUTE WS-DAYS-SUICIDE-WINDOW =
               PM-SUICIDE-YRS * 365
           COMPUTE WS-DAYS-SINCE-ISSUE =
               PM-DATE-OF-DEATH - PM-ISSUE-DATE
           IF PM-CAUSE-SUICIDE AND
              WS-DAYS-SINCE-ISSUE <= WS-DAYS-SUICIDE-WINDOW
               MOVE 21 TO WS-RESULT-CODE
               MOVE 'SUICIDE WITHIN POLICY SUICIDE WINDOW: REJECTED'
                   TO WS-RESULT-MESSAGE
               MOVE 'R' TO PM-CLAIM-DECISION
               EXIT PARAGRAPH
           END-IF
      * CL-402: DEATH AFTER EXPIRY DATE
           IF PM-DATE-OF-DEATH > PM-EXPIRY-DATE
               MOVE 22 TO WS-RESULT-CODE
               MOVE 'DATE OF DEATH IS AFTER POLICY EXPIRY DATE'
                   TO WS-RESULT-MESSAGE
               MOVE 'R' TO PM-CLAIM-DECISION
           END-IF.

      *---------------------------------------------------------------*
      * 1500 - CALCULATE SETTLEMENT   (CL-501 THRU CL-504)           *
      *---------------------------------------------------------------*
       1500-CALCULATE-SETTLEMENT.
      * CL-501: BASE PAYOUT = SUM ASSURED
           MOVE PM-SUM-ASSURED TO PM-CLAIM-PAYMENT-AMT
      * CL-502: ADD ADB RIDER SA IF ACCIDENTAL DEATH
           IF PM-CAUSE-ACCIDENT
               PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
                   UNTIL PM-RIDER-IDX > 5
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01' AND
                      PM-RIDER-ACTIVE(PM-RIDER-IDX)
                       ADD PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)
                           TO PM-CLAIM-PAYMENT-AMT
                       MOVE 'Y' TO WS-ADB-FOUND
                   END-IF
               END-PERFORM
           END-IF
      * CL-503: DEDUCT MODAL PREMIUM IF IN GRACE PERIOD
           IF PM-STATUS-GRACE
               SUBTRACT PM-MODAL-PREMIUM FROM PM-CLAIM-PAYMENT-AMT
           END-IF
      * CL-504: DEDUCT OUTSTANDING LOAN BALANCE
           IF PM-POLICY-LOAN-BALANCE > 0
               SUBTRACT PM-POLICY-LOAN-BALANCE
                   FROM PM-CLAIM-PAYMENT-AMT
           END-IF
      * FLOOR AT ZERO
           IF PM-CLAIM-PAYMENT-AMT < 0
               MOVE ZEROS TO PM-CLAIM-PAYMENT-AMT
           END-IF.

      *---------------------------------------------------------------*
      * 1600 - SETTLE CLAIM            (CL-601)                      *
      *---------------------------------------------------------------*
       1600-SETTLE-CLAIM.
           MOVE 'A' TO PM-CLAIM-DECISION
           MOVE 'C' TO PM-INVESTIGATION-STATUS
           MOVE 'CL' TO PM-CONTRACT-STATUS
           MOVE PM-PROCESS-DATE TO PM-CLAIM-ADJUDIC-DATE
           MOVE PM-PROCESS-DATE TO PM-CLAIM-SETTLE-DATE
           IF PM-CLAIM-PAYMENT-MODE = SPACES
               MOVE 'A' TO PM-CLAIM-PAYMENT-MODE
           END-IF
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'CLAIM APPROVED AND SETTLED' TO PM-RETURN-MESSAGE.

      *---------------------------------------------------------------*
      * 9000 - RETURN ERROR                                           *
      *---------------------------------------------------------------*
       9000-RETURN-ERROR.
           MOVE WS-RESULT-CODE TO PM-RETURN-CODE
           MOVE WS-RESULT-MESSAGE TO PM-RETURN-MESSAGE
           MOVE 'R' TO PM-CLAIM-DECISION.

      *---------------------------------------------------------------*
      * 9000 - RETURN PENDING                                         *
      *---------------------------------------------------------------*
       9000-RETURN-PENDING.
           MOVE 2 TO PM-RETURN-CODE
           MOVE 'CLAIM PENDING INVESTIGATION' TO PM-RETURN-MESSAGE
           MOVE 'P' TO PM-CLAIM-DECISION.
