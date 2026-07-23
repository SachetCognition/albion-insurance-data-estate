      *===============================================================*
      * PROGRAM:   SVCBILB                                           *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    R. KOWALSKI                                       *
      * DATE:      1998-03-05                                        *
      * VERSION:   1.1                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *            1998-07-22 - ADDED REINSTATEMENT LOGIC           *
      *---------------------------------------------------------------*
      * BATCH POLICY SERVICING AND BILLING                           *
      * DOMAIN:  TERM LIFE - SERVICING AND AMENDMENTS               *
      * PURPOSE: RE-PRICE POLICY CHANGES, CONTROL STATUS            *
      *          TRANSITIONS, REINSTATE LAPSED BUSINESS, CALCULATE  *
      *          AMENDMENT FEES.                                      *
      *---------------------------------------------------------------*
      * CALLED BY: RUNSVC (CL), DLYUPD (CL - NIGHTLY BATCH)         *
      * FILES:     POLMST (I-O INDEXED), SVCPF (I-O INDEXED)        *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *---------------------------------------------------------------*
      * RETURN CODES:                                                 *
      *  00 - AMENDMENT APPLIED SUCCESSFULLY                         *
      *  11 - POLICY IN CLAIMED OR TERMINATED STATUS                 *
      *  12 - AMENDMENT TYPE NOT PROVIDED                            *
      *  13 - PLAN CHANGE: POLICY NOT ACTIVE OR IN GRACE            *
      *  14 - PLAN CHANGE: NEW PLAN AGE/MATURITY VALIDATION FAILED  *
      *  15 - SA CHANGE: NEW SUM ASSURED MISSING OR OUT OF LIMITS   *
      *  16 - BILLING MODE CHANGE: INVALID NEW MODE                 *
      *  17 - ADD RIDER: MAXIMUM 5 RIDERS ALREADY ON POLICY         *
      *  18 - ADD RIDER: ADB NOT PERMITTED ABOVE AGE 60             *
      *  19 - REMOVE RIDER: NO ACTIVE ADB01 RIDER FOUND             *
      *  21 - REINSTATEMENT: POLICY NOT LAPSED                      *
      *  22 - REINSTATEMENT: LAPSED MORE THAN 730 DAYS              *
      *  31 - SA CHANGE: INCREASE > 25% OR SA > 25B REQUIRES UW    *
      *  33 - T65 PLAN CHANGE: REMAINING TERM = 0                   *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SVCBILB.
       AUTHOR.     R. KOWALSKI.
       DATE-WRITTEN. 1998-03-05.

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
           SELECT SVCPF
               ASSIGN TO DATABASE-SVCPF
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS PM-SERVICING-DETAILS
               FILE STATUS IS WS-SVCPF-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  POLMST.
       COPY POLDATA.
       FD  SVCPF.
       01  SVC-RECORD.
           05  SVC-SVC-ID            PIC X(12).
           05  SVC-POL-ID            PIC X(12).
           05  FILLER                PIC X(200).

       WORKING-STORAGE SECTION.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-SVCPF-STATUS           PIC X(02) VALUE SPACES.
       77  WS-RESULT-CODE            PIC 9(02) VALUE 0.
       77  WS-RESULT-MESSAGE         PIC X(100) VALUE SPACES.
       77  WS-OLD-TOTAL-PREMIUM      PIC 9(13)V99 VALUE 0.
       77  WS-DAYS-SINCE-PAID        PIC 9(07) VALUE 0.
       77  WS-DAYS-SINCE-LAPSE       PIC 9(07) VALUE 0.
       77  WS-RIDER-IDX              PIC 9(02) VALUE 0.
       77  WS-MODAL-DIVISOR          PIC 9(02) VALUE 1.
       77  WS-MODAL-FACTOR           PIC 9(01)V9999 VALUE 1.0000.
       77  WS-RIDER-COUNT            PIC 9(02) VALUE 0.

       LINKAGE SECTION.
       01  LK-POLICY-ID              PIC X(12).
       01  LK-SVC-ID                 PIC X(12).

       PROCEDURE DIVISION USING LK-POLICY-ID LK-SVC-ID.

       MAIN-PROCESS.
           OPEN I-O POLMST
           OPEN I-O SVCPF
           MOVE LK-POLICY-ID TO PM-POLICY-ID
           READ POLMST
               INVALID KEY
                   MOVE 11 TO WS-RESULT-CODE
                   MOVE 'POLICY RECORD NOT FOUND' TO WS-RESULT-MESSAGE
                   CLOSE POLMST SVCPF
                   GOBACK
           END-READ
           PERFORM 1000-INITIALIZE
           PERFORM 1100-LOAD-PLAN-PARAMETERS
           PERFORM 1200-CALCULATE-ATTAINED-AGE
           PERFORM 1300-EVALUATE-PAYMENT-STATUS
           PERFORM 1400-VALIDATE-SERVICING-REQUEST
           IF WS-RESULT-CODE NOT = 0
               MOVE WS-RESULT-CODE TO PM-RETURN-CODE
               MOVE WS-RESULT-MESSAGE TO PM-RETURN-MESSAGE
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST SVCPF
               GOBACK
           END-IF
           EVALUATE PM-AMENDMENT-TYPE
               WHEN 'PL' PERFORM 2100-CHANGE-PLAN
               WHEN 'SA' PERFORM 2200-CHANGE-SUM-ASSURED
               WHEN 'BM' PERFORM 2300-CHANGE-BILLING-MODE
               WHEN 'AR' PERFORM 2400-ADD-RIDER
               WHEN 'RR' PERFORM 2500-REMOVE-RIDER
               WHEN 'RI' PERFORM 2600-PROCESS-REINSTATEMENT
           END-EVALUATE
           MOVE WS-RESULT-CODE TO PM-RETURN-CODE
           MOVE WS-RESULT-MESSAGE TO PM-RETURN-MESSAGE
           REWRITE WS-POLICY-MASTER-REC
           CLOSE POLMST SVCPF
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - INITIALIZE                                             *
      *---------------------------------------------------------------*
       1000-INITIALIZE.
           MOVE PM-TOTAL-ANNUAL-PREMIUM TO WS-OLD-TOTAL-PREMIUM
           MOVE ZEROS TO PM-PREMIUM-DELTA
           MOVE 'PE' TO PM-AMENDMENT-STATUS
           MOVE ZEROS TO WS-RESULT-CODE
           MOVE SPACES TO WS-RESULT-MESSAGE
      *Y2K-REVIEWED 1998-11-14
           IF PM-PROCESS-DATE = 0
               ACCEPT PM-PROCESS-DATE FROM DATE YYYYMMDD
           END-IF
           MOVE 'SVCBILB' TO PM-LAST-ACTION-USER
           MOVE PM-PROCESS-DATE TO PM-LAST-ACTION-DATE.

      *---------------------------------------------------------------*
      * 1100 - LOAD PLAN PARAMETERS   (SV-101)                       *
      *---------------------------------------------------------------*
       1100-LOAD-PLAN-PARAMETERS.
           EVALUATE PM-PLAN-CODE
               WHEN 'T1001'
                   MOVE 10 TO PM-TERM-YEARS
                   MOVE 70 TO PM-MATURITY-AGE
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 60 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  50000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 4500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T2001'
                   MOVE 20 TO PM-TERM-YEARS
                   MOVE 75 TO PM-MATURITY-AGE
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 55 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  90000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 5500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T6501'
                   MOVE 65 TO PM-MATURITY-AGE
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 50 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  75000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 6000 TO PM-ANNUAL-POLICY-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
                   COMPUTE PM-TERM-YEARS =
                       PM-MATURITY-AGE - PM-ISSUE-AGE
           END-EVALUATE.

      *---------------------------------------------------------------*
      * 1200 - CALCULATE ATTAINED AGE                                 *
      *---------------------------------------------------------------*
       1200-CALCULATE-ATTAINED-AGE.
      *Y2K-REVIEWED 1998-11-14
           COMPUTE PM-ATTAINED-AGE =
               PM-ISSUE-AGE +
               ((PM-PROCESS-DATE - PM-ISSUE-DATE) / 365).

      *---------------------------------------------------------------*
      * 1300 - EVALUATE PAYMENT STATUS (SV-201 THRU SV-202)          *
      *---------------------------------------------------------------*
       1300-EVALUATE-PAYMENT-STATUS.
      *Y2K-REVIEWED 1998-11-14
           COMPUTE WS-DAYS-SINCE-PAID =
               PM-PROCESS-DATE - PM-PAID-TO-DATE
      * SV-201: GRACE PERIOD TRANSITION
           IF PM-STATUS-ACTIVE AND
              WS-DAYS-SINCE-PAID > 0 AND
              WS-DAYS-SINCE-PAID <= PM-GRACE-DAYS
               MOVE 'GR' TO PM-CONTRACT-STATUS
           END-IF
      * LAPSE TRANSITION
           IF (PM-STATUS-ACTIVE OR PM-STATUS-GRACE) AND
              WS-DAYS-SINCE-PAID > PM-GRACE-DAYS
               MOVE 'LA' TO PM-CONTRACT-STATUS
           END-IF
      * SV-202: OUTSTANDING PREMIUM IF OVERDUE
           IF WS-DAYS-SINCE-PAID > 0
               MOVE PM-MODAL-PREMIUM TO PM-OUTSTANDING-PREMIUM
           END-IF.

      *---------------------------------------------------------------*
      * 1400 - VALIDATE SERVICING REQUEST (SV-301 THRU SV-302)       *
      *---------------------------------------------------------------*
       1400-VALIDATE-SERVICING-REQUEST.
      * SV-301: CLAIMED OR TERMINATED = NO SERVICE
           IF PM-STATUS-CLAIMED OR PM-STATUS-TERMINATED
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'CLAIMED OR TERMINATED POLICY CANNOT BE SERVICED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * SV-302: AMENDMENT TYPE REQUIRED
           IF PM-AMENDMENT-TYPE = SPACES
               MOVE 12 TO WS-RESULT-CODE
               MOVE 'AMENDMENT TYPE IS REQUIRED'
                   TO WS-RESULT-MESSAGE
           END-IF.

      *---------------------------------------------------------------*
      * 2100 - CHANGE PLAN             (SV-401 THRU SV-403)          *
      *---------------------------------------------------------------*
       2100-CHANGE-PLAN.
           IF NOT PM-STATUS-ACTIVE AND NOT PM-STATUS-GRACE
               MOVE 13 TO WS-RESULT-CODE
               MOVE 'PLAN CHANGE: POLICY MUST BE ACTIVE OR IN GRACE'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           MOVE PM-PLAN-CODE TO PM-OLD-PLAN-CODE
           MOVE PM-NEW-PLAN-CODE TO PM-PLAN-CODE
           PERFORM 1100-LOAD-PLAN-PARAMETERS
           IF PM-PLAN-CODE = 'T6501'
               COMPUTE PM-TERM-YEARS =
                   PM-MATURITY-AGE - PM-ATTAINED-AGE
               IF PM-TERM-YEARS <= 0
                   MOVE 33 TO WS-RESULT-CODE
                   MOVE 'T65 PLAN CHANGE: REMAINING TERM IS ZERO'
                       TO WS-RESULT-MESSAGE
                   MOVE PM-OLD-PLAN-CODE TO PM-PLAN-CODE
                   EXIT PARAGRAPH
               END-IF
           END-IF
           IF PM-ATTAINED-AGE < PM-MIN-ISSUE-AGE OR
              PM-ATTAINED-AGE > PM-MAX-ISSUE-AGE
               MOVE 14 TO WS-RESULT-CODE
               MOVE 'PLAN CHANGE: ATTAINED AGE OUTSIDE NEW PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               MOVE PM-OLD-PLAN-CODE TO PM-PLAN-CODE
               EXIT PARAGRAPH
           END-IF
           PERFORM 3100-REPRICE-POLICY
           ADD PM-SERVICE-FEE TO PM-SERVICE-FEE-CHARGED
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'PLAN CHANGE APPLIED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 2200 - CHANGE SUM ASSURED      (SV-501 THRU SV-502)          *
      *---------------------------------------------------------------*
       2200-CHANGE-SUM-ASSURED.
           IF PM-NEW-SUM-ASSURED = 0 OR
              PM-NEW-SUM-ASSURED < PM-MIN-SUM-ASSURED OR
              PM-NEW-SUM-ASSURED > PM-MAX-SUM-ASSURED
               MOVE 15 TO WS-RESULT-CODE
               MOVE 'NEW SUM ASSURED MISSING OR OUT OF PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * SV-502: SA INCREASE > 25% OR SA > 25B REQUIRES UW
           IF PM-NEW-SUM-ASSURED > PM-SUM-ASSURED
               COMPUTE WS-RESULT-CODE = 0
               IF PM-NEW-SUM-ASSURED > (PM-SUM-ASSURED * 1.25) OR
                  PM-NEW-SUM-ASSURED > 25000000000000
                   MOVE 'Y' TO PM-UW-REQUIRED
                   MOVE 31 TO WS-RESULT-CODE
                   MOVE 'SA INCREASE REQUIRES UNDERWRITING REVIEW'
                       TO WS-RESULT-MESSAGE
                   MOVE 'PE' TO PM-AMENDMENT-STATUS
                   EXIT PARAGRAPH
               END-IF
           END-IF
           MOVE PM-SUM-ASSURED TO PM-OLD-SUM-ASSURED
           MOVE PM-NEW-SUM-ASSURED TO PM-SUM-ASSURED
           PERFORM 3100-REPRICE-POLICY
           ADD PM-SERVICE-FEE TO PM-SERVICE-FEE-CHARGED
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'SUM ASSURED CHANGE APPLIED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 2300 - CHANGE BILLING MODE     (SV-601)                      *
      *---------------------------------------------------------------*
       2300-CHANGE-BILLING-MODE.
           IF PM-NEW-BILLING-MODE NOT = 'A' AND
              PM-NEW-BILLING-MODE NOT = 'S' AND
              PM-NEW-BILLING-MODE NOT = 'Q' AND
              PM-NEW-BILLING-MODE NOT = 'M'
               MOVE 16 TO WS-RESULT-CODE
               MOVE 'INVALID BILLING MODE - MUST BE A S Q OR M'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           MOVE PM-BILLING-MODE TO PM-OLD-BILLING-MODE
           MOVE PM-NEW-BILLING-MODE TO PM-BILLING-MODE
           PERFORM 3200-RECALCULATE-MODAL-PREMIUM
           ADD 1000 TO PM-SERVICE-FEE-CHARGED
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'BILLING MODE CHANGE APPLIED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 2400 - ADD RIDER               (SV-701 THRU SV-702)          *
      *---------------------------------------------------------------*
       2400-ADD-RIDER.
           MOVE 0 TO WS-RIDER-COUNT
           PERFORM VARYING WS-RIDER-IDX FROM 1 BY 1
               UNTIL WS-RIDER-IDX > 5
               IF PM-RIDER-CODE(WS-RIDER-IDX) NOT = SPACES AND
                  PM-RIDER-ACTIVE(WS-RIDER-IDX)
                   ADD 1 TO WS-RIDER-COUNT
               END-IF
           END-PERFORM
           IF WS-RIDER-COUNT >= 5
               MOVE 17 TO WS-RESULT-CODE
               MOVE 'MAXIMUM 5 RIDERS ALREADY ON POLICY'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * SV-702: ADB NOT ABOVE AGE 60
           IF PM-ATTAINED-AGE > 60
               MOVE 18 TO WS-RESULT-CODE
               MOVE 'ADB RIDER: CANNOT ADD ABOVE AGE 60'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * ADD ADB01 WITH SA = BASE SA
           PERFORM VARYING WS-RIDER-IDX FROM 1 BY 1
               UNTIL WS-RIDER-IDX > 5
               IF PM-RIDER-CODE(WS-RIDER-IDX) = SPACES
                   MOVE 'ADB01' TO PM-RIDER-CODE(WS-RIDER-IDX)
                   MOVE PM-SUM-ASSURED
                       TO PM-RIDER-SUM-ASSURED(WS-RIDER-IDX)
                   MOVE 'A' TO PM-RIDER-STATUS(WS-RIDER-IDX)
                   STOP PERFORM
               END-IF
           END-PERFORM
           PERFORM 3100-REPRICE-POLICY
           ADD 1200 TO PM-SERVICE-FEE-CHARGED
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'ADB RIDER ADDED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 2500 - REMOVE RIDER            (SV-801)                      *
      *---------------------------------------------------------------*
       2500-REMOVE-RIDER.
           MOVE 'N' TO WS-ADB-FOUND OF PROCEDURE DIVISION
           PERFORM VARYING WS-RIDER-IDX FROM 1 BY 1
               UNTIL WS-RIDER-IDX > 5
               IF PM-RIDER-CODE(WS-RIDER-IDX) = 'ADB01' AND
                  PM-RIDER-ACTIVE(WS-RIDER-IDX)
                   MOVE 'R' TO PM-RIDER-STATUS(WS-RIDER-IDX)
                   MOVE ZEROS TO PM-RIDER-SUM-ASSURED(WS-RIDER-IDX)
                   MOVE ZEROS TO PM-RIDER-RATE(WS-RIDER-IDX)
                   MOVE ZEROS TO PM-RIDER-ANNUAL-PREM(WS-RIDER-IDX)
                   STOP PERFORM
               END-IF
           END-PERFORM
           PERFORM 3100-REPRICE-POLICY
           ADD 1000 TO PM-SERVICE-FEE-CHARGED
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'ADB RIDER REMOVED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 2600 - PROCESS REINSTATEMENT   (SV-901 THRU SV-902)          *
      *---------------------------------------------------------------*
       2600-PROCESS-REINSTATEMENT.
      * SV-901: ONLY LAPSED POLICIES
           IF NOT PM-STATUS-LAPSED
               MOVE 21 TO WS-RESULT-CODE
               MOVE 'REINSTATEMENT: POLICY IS NOT LAPSED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      *Y2K-REVIEWED 1998-11-14
           COMPUTE WS-DAYS-SINCE-LAPSE =
               PM-PROCESS-DATE - PM-PAID-TO-DATE
           IF WS-DAYS-SINCE-LAPSE > PM-REINSTATE-WINDOW
               MOVE 22 TO WS-RESULT-CODE
               MOVE 'REINSTATEMENT: LAPSED MORE THAN 730 DAYS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * SV-902: OUTSTANDING PREMIUM + REINSTATE FEE
           MOVE PM-MODAL-PREMIUM TO PM-OUTSTANDING-PREMIUM
           ADD 1500 TO PM-SERVICE-FEE-CHARGED
           ADD 2500 TO PM-SERVICE-FEE-CHARGED
           MOVE 'RS' TO PM-CONTRACT-STATUS
           MOVE 'AP' TO PM-AMENDMENT-STATUS
           MOVE 0 TO WS-RESULT-CODE
           MOVE 'POLICY REINSTATED' TO WS-RESULT-MESSAGE.

      *---------------------------------------------------------------*
      * 3100 - REPRICE POLICY          (SV-1001)                     *
      *---------------------------------------------------------------*
       3100-REPRICE-POLICY.
           PERFORM 3110-LOAD-RATING-FACTORS
           PERFORM 3120-CALCULATE-BASE-ANNUAL
           PERFORM 3130-CALCULATE-RIDER-ANNUAL
           PERFORM 3140-CALCULATE-TOTAL-ANNUAL
           PERFORM 3200-RECALCULATE-MODAL-PREMIUM
           COMPUTE PM-PREMIUM-DELTA =
               PM-TOTAL-ANNUAL-PREMIUM - WS-OLD-TOTAL-PREMIUM.

      *---------------------------------------------------------------*
      * 3110 - LOAD RATING FACTORS (ATTAINED AGE)                    *
      *---------------------------------------------------------------*
       3110-LOAD-RATING-FACTORS.
           EVALUATE TRUE
               WHEN PM-ATTAINED-AGE <= 30
                   MOVE 0.8500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ATTAINED-AGE <= 40
                   MOVE 1.2000 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ATTAINED-AGE <= 50
                   MOVE 2.1500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ATTAINED-AGE <= 60
                   MOVE 4.1000 TO PM-BASE-MORTALITY-RATE
               WHEN OTHER
                   MOVE 7.2500 TO PM-BASE-MORTALITY-RATE
           END-EVALUATE
           IF PM-FEMALE
               MOVE 0.9200 TO PM-GENDER-FACTOR
           ELSE
               MOVE 1.0000 TO PM-GENDER-FACTOR
           END-IF
           IF PM-SMOKER
               MOVE 1.7500 TO PM-SMOKER-FACTOR
           ELSE
               MOVE 1.0000 TO PM-SMOKER-FACTOR
           END-IF
           EVALUATE PM-OCCUPATION-CLASS
               WHEN 1 MOVE 1.0000 TO PM-OCCUPATION-FACTOR
               WHEN 2 MOVE 1.1500 TO PM-OCCUPATION-FACTOR
               WHEN 3 MOVE 1.4000 TO PM-OCCUPATION-FACTOR
               WHEN OTHER MOVE 1.0000 TO PM-OCCUPATION-FACTOR
           END-EVALUATE
           EVALUATE PM-UW-CLASS
               WHEN 'PR' MOVE 0.9000 TO PM-UW-FACTOR
               WHEN 'ST' MOVE 1.0000 TO PM-UW-FACTOR
               WHEN 'TB' MOVE 1.2500 TO PM-UW-FACTOR
               WHEN OTHER MOVE 1.0000 TO PM-UW-FACTOR
           END-EVALUATE.

      *---------------------------------------------------------------*
      * 3120 - CALCULATE BASE ANNUAL                                  *
      *---------------------------------------------------------------*
       3120-CALCULATE-BASE-ANNUAL.
           COMPUTE PM-BASE-ANNUAL-PREMIUM =
               (PM-SUM-ASSURED / 1000)
               * PM-BASE-MORTALITY-RATE
               * PM-GENDER-FACTOR
               * PM-SMOKER-FACTOR
               * PM-OCCUPATION-FACTOR
               * PM-UW-FACTOR.

      *---------------------------------------------------------------*
      * 3130 - CALCULATE RIDER ANNUAL (ACTIVE RIDERS ONLY)            *
      *---------------------------------------------------------------*
       3130-CALCULATE-RIDER-ANNUAL.
           MOVE ZEROS TO PM-RIDER-ANNUAL-TOTAL
           PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
               UNTIL PM-RIDER-IDX > 5
               IF PM-RIDER-CODE(PM-RIDER-IDX) NOT = SPACES AND
                  PM-RIDER-ACTIVE(PM-RIDER-IDX)
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           (PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)
                           / 1000) * 0.1800
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'WOP01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           PM-BASE-ANNUAL-PREMIUM * 0.06
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'CI001'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           (PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)
                           / 1000) * 1.2500
                   END-IF
                   ADD PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX)
                       TO PM-RIDER-ANNUAL-TOTAL
               END-IF
           END-PERFORM.

      *---------------------------------------------------------------*
      * 3140 - CALCULATE TOTAL ANNUAL                                 *
      *---------------------------------------------------------------*
       3140-CALCULATE-TOTAL-ANNUAL.
           COMPUTE PM-GROSS-ANNUAL-PREMIUM =
               PM-BASE-ANNUAL-PREMIUM +
               PM-RIDER-ANNUAL-TOTAL +
               PM-ANNUAL-POLICY-FEE
           COMPUTE PM-TAX-AMOUNT =
               PM-GROSS-ANNUAL-PREMIUM * PM-TAX-RATE
           COMPUTE PM-TOTAL-ANNUAL-PREMIUM =
               PM-GROSS-ANNUAL-PREMIUM + PM-TAX-AMOUNT.

      *---------------------------------------------------------------*
      * 3200 - RECALCULATE MODAL PREMIUM                              *
      *---------------------------------------------------------------*
       3200-RECALCULATE-MODAL-PREMIUM.
           EVALUATE PM-BILLING-MODE
               WHEN 'A'
                   MOVE 1 TO WS-MODAL-DIVISOR
                   MOVE 1.0000 TO WS-MODAL-FACTOR
               WHEN 'S'
                   MOVE 2 TO WS-MODAL-DIVISOR
                   MOVE 1.0150 TO WS-MODAL-FACTOR
               WHEN 'Q'
                   MOVE 4 TO WS-MODAL-DIVISOR
                   MOVE 1.0300 TO WS-MODAL-FACTOR
               WHEN 'M'
                   MOVE 12 TO WS-MODAL-DIVISOR
                   MOVE 1.0800 TO WS-MODAL-FACTOR
           END-EVALUATE
           COMPUTE PM-MODAL-PREMIUM =
               (PM-TOTAL-ANNUAL-PREMIUM / WS-MODAL-DIVISOR)
               * WS-MODAL-FACTOR.
