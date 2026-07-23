      *===============================================================*
      * PROGRAM:   CLMMNT                                            *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    D. BRENNAN                                        *
      * DATE:      1997-11-10                                        *
      * VERSION:   1.2                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *            1998-02-15 - ADDED ADB PAYOUT FOR ACCIDENTS      *
      *---------------------------------------------------------------*
      * INTERACTIVE CLAIMS MAINTENANCE                               *
      * SCREEN FLOW:                                                  *
      *   CLMHDR (LOOKUP POLICY) -> CLMDETAIL -> CLMDOCS            *
      *   -> F6=SUBMIT (ADJUDICATE) -> CLMRESULT                     *
      *---------------------------------------------------------------*
      * CALLED BY: MAINMENU                                           *
      * FILES:     CLMDSPF (WORKSTATION), POLMST (INDEXED I-O),      *
      *            CLMPF (INDEXED I-O)                               *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLMMNT.
       AUTHOR.     D. BRENNAN.
       DATE-WRITTEN. 1997-11-10.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-AS400.
       OBJECT-COMPUTER. IBM-AS400.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CLMDSPF
               ASSIGN TO WORKSTATION-CLMDSPF
               ORGANIZATION IS TRANSACTION
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-DSP-STATUS.
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
       FD  CLMDSPF.
       01  CLM-DSP-RECORD            PIC X(80).
       FD  POLMST.
       COPY POLDATA.
       FD  CLMPF.
       01  CLMPF-RECORD              PIC X(324).

       WORKING-STORAGE SECTION.
       77  WS-DSP-STATUS             PIC X(02) VALUE SPACES.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-CLMPF-STATUS           PIC X(02) VALUE SPACES.
       77  WS-CONTINUE               PIC X VALUE 'Y'.
       77  WS-RESULT-CODE            PIC 9(02) VALUE 0.
       77  WS-RESULT-MESSAGE         PIC X(100) VALUE SPACES.
       77  WS-DAYS-SINCE-ISSUE       PIC 9(07) VALUE 0.
       77  WS-DAYS-CONTESTABLE       PIC 9(07) VALUE 0.
       77  WS-DAYS-SUICIDE-WINDOW    PIC 9(07) VALUE 0.
       77  WS-RIDER-IDX              PIC 9(02) VALUE 0.

       PROCEDURE DIVISION.

       MAIN-PROCESS.
           OPEN I-O CLMDSPF
           OPEN I-O POLMST
           OPEN I-O CLMPF
           PERFORM UNTIL WS-CONTINUE = 'N'
               PERFORM 1000-DISPLAY-HEADER
               IF *IN03 = '1' OR *IN12 = '1'
                   MOVE 'N' TO WS-CONTINUE
               ELSE IF WS-POLMST-STATUS NOT = '00'
                   MOVE 'POLICY NOT FOUND - PLEASE RE-ENTER'
                       TO CLMSG
                   WRITE CLM-DSP-RECORD FORMAT IS 'CLMRESULT'
               ELSE
                   PERFORM 2000-DISPLAY-CLAIM-DETAIL
                   IF *IN03 = '1' OR *IN12 = '1'
                       MOVE 'N' TO WS-CONTINUE
                   ELSE
                       PERFORM 3000-DISPLAY-DOCS
                       IF *IN06 = '1'
                           PERFORM 4000-ADJUDICATE-CLAIM
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           CLOSE CLMDSPF POLMST CLMPF
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - DISPLAY HEADER AND LOOK UP POLICY                      *
      *---------------------------------------------------------------*
       1000-DISPLAY-HEADER.
           MOVE SPACES TO CLMID
           MOVE SPACES TO CLPOLID
      *Y2K-REVIEWED 1998-11-14
           ACCEPT CLPRCDT FROM DATE YYYYMMDD
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMHDR'
           READ CLMDSPF FORMAT IS 'CLMHDR'
           MOVE CLMID TO PM-CLAIM-ID
           MOVE CLPOLID TO PM-POLICY-ID
           MOVE CLPRCDT TO PM-PROCESS-DATE
           READ POLMST KEY IS PM-POLICY-ID
               INVALID KEY
                   CONTINUE
               NOT INVALID KEY
                   MOVE PM-CONTRACT-STATUS TO CLPOLSTS
                   MOVE PM-INSURED-NAME TO CLINSNAM
           END-READ.

      *---------------------------------------------------------------*
      * 2000 - DISPLAY CLAIM DETAILS                                  *
      *---------------------------------------------------------------*
       2000-DISPLAY-CLAIM-DETAIL.
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMDETAIL'
           READ CLMDSPF FORMAT IS 'CLMDETAIL'
           MOVE CLTYPE TO PM-CLAIM-TYPE
           MOVE CLCAUSD TO PM-CAUSE-OF-DEATH
           MOVE CLDTHDTC TO PM-DATE-OF-DEATH
           MOVE CLBENNAM TO PM-BENEFICIARY-NAME
           MOVE CLBENREL TO PM-BENEFICIARY-RELATION
           MOVE CLPYMTMD TO PM-CLAIM-PAYMENT-MODE.

      *---------------------------------------------------------------*
      * 3000 - DISPLAY DOCUMENT CHECKLIST                             *
      *---------------------------------------------------------------*
       3000-DISPLAY-DOCS.
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMDOCS'
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMFKEYS'
           READ CLMDSPF FORMAT IS 'CLMDOCS'
           MOVE CLDTHCRT TO PM-DEATH-CERT-RECD
           MOVE CLCLMFRM TO PM-CLAIM-FORM-RECD
           MOVE CLIDPROF TO PM-ID-PROOF-RECD
           MOVE CLMEDRCS TO PM-MEDICAL-RECORDS-RECD.

      *---------------------------------------------------------------*
      * 4000 - ADJUDICATE CLAIM                                       *
      *---------------------------------------------------------------*
       4000-ADJUDICATE-CLAIM.
           MOVE ZEROS TO WS-RESULT-CODE
           MOVE SPACES TO WS-RESULT-MESSAGE
      * VALIDATE
           PERFORM 4100-VALIDATE-CLAIM
           IF WS-RESULT-CODE NOT = 0 AND WS-RESULT-CODE NOT = 2
               PERFORM 9000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
           IF WS-RESULT-CODE = 2
               PERFORM 9000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * DETERMINE INVESTIGATION
           PERFORM 4200-CHECK-INVESTIGATION
           IF WS-RESULT-CODE = 2
               PERFORM 9000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * ADJUDICATE
           PERFORM 4300-ADJUDICATE-COVERAGE
           IF WS-RESULT-CODE NOT = 0
               PERFORM 9000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * SETTLE
           PERFORM 4400-CALCULATE-SETTLEMENT
           PERFORM 4500-SETTLE-CLAIM
      * WRITE POLMST AND CLMPF
           REWRITE WS-POLICY-MASTER-REC
           WRITE CLMPF-RECORD
           PERFORM 9000-DISPLAY-RESULT.

       4100-VALIDATE-CLAIM.
           IF NOT PM-CLAIM-DEATH
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'ONLY DEATH CLAIMS ARE SUPPORTED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF NOT PM-STATUS-ACTIVE AND NOT PM-STATUS-GRACE
               MOVE 12 TO WS-RESULT-CODE
               MOVE 'POLICY IS NOT ACTIVE OR IN GRACE PERIOD'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-CLAIM-ID = SPACES OR PM-DATE-OF-DEATH = 0 OR
              PM-BENEFICIARY-NAME = SPACES
               MOVE 13 TO WS-RESULT-CODE
               MOVE 'MISSING CLAIM ID DATE OF DEATH OR BENEFICIARY'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-DEATH-CERT-RECD NOT = 'Y' OR
              PM-CLAIM-FORM-RECD NOT = 'Y' OR
              PM-ID-PROOF-RECD NOT = 'Y'
               MOVE 2 TO WS-RESULT-CODE
               MOVE 'MISSING REQUIRED DOCUMENTS - MANUAL REVIEW'
                   TO WS-RESULT-MESSAGE
           END-IF.

       4200-CHECK-INVESTIGATION.
           MOVE 'N' TO PM-INVESTIGATION-STATUS
           COMPUTE WS-DAYS-SINCE-ISSUE =
               PM-DATE-OF-DEATH - PM-ISSUE-DATE
           COMPUTE WS-DAYS-CONTESTABLE = 2 * 365
           IF WS-DAYS-SINCE-ISSUE <= WS-DAYS-CONTESTABLE
               MOVE 'P' TO PM-INVESTIGATION-STATUS
               MOVE 2 TO WS-RESULT-CODE
               MOVE 'DEATH WITHIN CONTESTABILITY PERIOD - INVESTIGATION'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-CAUSE-UNKNOWN OR PM-CAUSE-HOMICIDE OR PM-CAUSE-SUICIDE
               MOVE 'P' TO PM-INVESTIGATION-STATUS
               MOVE 2 TO WS-RESULT-CODE
               MOVE 'CLAIM REQUIRES INVESTIGATION' TO WS-RESULT-MESSAGE
           END-IF.

       4300-ADJUDICATE-COVERAGE.
           COMPUTE WS-DAYS-SUICIDE-WINDOW = 2 * 365
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
           IF PM-DATE-OF-DEATH > PM-EXPIRY-DATE
               MOVE 22 TO WS-RESULT-CODE
               MOVE 'DATE OF DEATH IS AFTER POLICY EXPIRY DATE'
                   TO WS-RESULT-MESSAGE
               MOVE 'R' TO PM-CLAIM-DECISION
           END-IF.

       4400-CALCULATE-SETTLEMENT.
           MOVE PM-SUM-ASSURED TO PM-CLAIM-PAYMENT-AMT
           IF PM-CAUSE-ACCIDENT
               PERFORM VARYING WS-RIDER-IDX FROM 1 BY 1
                   UNTIL WS-RIDER-IDX > 5
                   IF PM-RIDER-CODE(WS-RIDER-IDX) = 'ADB01' AND
                      PM-RIDER-ACTIVE(WS-RIDER-IDX)
                       ADD PM-RIDER-SUM-ASSURED(WS-RIDER-IDX)
                           TO PM-CLAIM-PAYMENT-AMT
                   END-IF
               END-PERFORM
           END-IF
           IF PM-STATUS-GRACE
               SUBTRACT PM-MODAL-PREMIUM FROM PM-CLAIM-PAYMENT-AMT
           END-IF
           IF PM-POLICY-LOAN-BALANCE > 0
               SUBTRACT PM-POLICY-LOAN-BALANCE
                   FROM PM-CLAIM-PAYMENT-AMT
           END-IF
           IF PM-CLAIM-PAYMENT-AMT < 0
               MOVE ZEROS TO PM-CLAIM-PAYMENT-AMT
           END-IF.

       4500-SETTLE-CLAIM.
           MOVE 'A' TO PM-CLAIM-DECISION
           MOVE 'C' TO PM-INVESTIGATION-STATUS
           MOVE 'CL' TO PM-CONTRACT-STATUS
           MOVE PM-PROCESS-DATE TO PM-CLAIM-ADJUDIC-DATE
           MOVE PM-PROCESS-DATE TO PM-CLAIM-SETTLE-DATE
           IF PM-CLAIM-PAYMENT-MODE = SPACES
               MOVE 'A' TO PM-CLAIM-PAYMENT-MODE
           END-IF
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'CLAIM APPROVED AND SETTLED' TO WS-RESULT-MESSAGE
           MOVE 'CLMMNT' TO PM-LAST-ACTION-USER
           MOVE PM-PROCESS-DATE TO PM-LAST-ACTION-DATE.

       9000-DISPLAY-RESULT.
           MOVE PM-CLAIM-DECISION TO CLMDEC
           MOVE PM-CLAIM-PAYMENT-AMT TO CLPYMTAM
           MOVE PM-INVESTIGATION-STATUS TO CLINVSTS
           MOVE WS-RESULT-MESSAGE TO CLMSG
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMRESULT'
           WRITE CLM-DSP-RECORD FORMAT IS 'CLMFKEYS'
           READ CLMDSPF FORMAT IS 'CLMRESULT'.
