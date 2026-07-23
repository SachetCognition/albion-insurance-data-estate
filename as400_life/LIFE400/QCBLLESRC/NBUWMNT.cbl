      *===============================================================*
      * PROGRAM:   NBUWMNT                                          *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    R. KOWALSKI                                       *
      * DATE:      1997-09-15                                        *
      * VERSION:   1.4                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *            1998-04-10 - ADDED RIDER ENTRY SECTION           *
      *            1998-01-08 - ADDED T6501 PLAN SUPPORT            *
      *---------------------------------------------------------------*
      * INTERACTIVE NEW BUSINESS MAINTENANCE                         *
      * SCREEN FLOW:                                                  *
      *   NBHDR -> NBINSKD -> NBBENEFIT -> NBRIDERS                  *
      *   -> F6=ISSUE (VALIDATE + CALC + WRITE POLMST)               *
      *   -> NBRESULT (DISPLAY OUTCOME)                               *
      *---------------------------------------------------------------*
      * CALLED BY: MAINMENU                                           *
      * FILES:     NBUWDSPF (WORKSTATION), POLMST (INDEXED I-O)      *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NBUWMNT.
       AUTHOR.     R. KOWALSKI.
       DATE-WRITTEN. 1997-09-15.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-AS400.
       OBJECT-COMPUTER. IBM-AS400.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT NBUWDSPF
               ASSIGN TO WORKSTATION-NBUWDSPF
               ORGANIZATION IS TRANSACTION
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-DSP-STATUS.
           SELECT POLMST
               ASSIGN TO DATABASE-POLMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS PM-POLICY-ID
               FILE STATUS IS WS-POLMST-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  NBUWDSPF.
       01  NB-DSP-RECORD             PIC X(80).
       FD  POLMST.
       COPY POLDATA.

       WORKING-STORAGE SECTION.
       77  WS-DSP-STATUS             PIC X(02) VALUE SPACES.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-CONTINUE               PIC X VALUE 'Y'.
       77  WS-RIDER-IDX              PIC 9(02) VALUE 0.
       77  WS-MODAL-DIVISOR          PIC 9(02) VALUE 1.
       77  WS-MODAL-FACTOR           PIC 9(01)V9999 VALUE 1.0000.
       77  WS-REINSURANCE-REFERRAL   PIC X VALUE 'N'.
       77  WS-UW-REFERRAL            PIC X VALUE 'N'.
       77  WS-RESULT-CODE            PIC 9(02) VALUE 0.
       77  WS-RESULT-MESSAGE         PIC X(100) VALUE SPACES.

       PROCEDURE DIVISION.

       MAIN-PROCESS.
           OPEN I-O NBUWDSPF
           OPEN I-O POLMST
           PERFORM UNTIL WS-CONTINUE = 'N'
               PERFORM 1000-DISPLAY-HEADER
               IF *IN03 = '1' OR *IN12 = '1'
                   MOVE 'N' TO WS-CONTINUE
               ELSE
                   PERFORM 2000-DISPLAY-INSURED
                   IF *IN03 = '1' OR *IN12 = '1'
                       MOVE 'N' TO WS-CONTINUE
                   ELSE
                       PERFORM 3000-DISPLAY-BENEFIT
                       IF *IN03 = '1' OR *IN12 = '1'
                           MOVE 'N' TO WS-CONTINUE
                       ELSE
                           PERFORM 4000-DISPLAY-RIDERS
                           IF *IN06 = '1'
                               PERFORM 5000-ISSUE-POLICY
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           CLOSE NBUWDSPF POLMST
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - DISPLAY HEADER SCREEN                                  *
      *---------------------------------------------------------------*
       1000-DISPLAY-HEADER.
      *Y2K-REVIEWED 1998-11-14
           ACCEPT NBPRCDT FROM DATE YYYYMMDD
           WRITE NB-DSP-RECORD FORMAT IS 'NBHDR'
           READ NBUWDSPF FORMAT IS 'NBHDR'
           MOVE NBPOLID TO PM-POLICY-ID
           MOVE NBAPPID TO PM-APPLICATION-ID
           MOVE NBPLANC TO PM-PLAN-CODE
           MOVE NBPRCDT TO PM-PROCESS-DATE
           MOVE NBISSCHN TO PM-ISSUE-CHANNEL
           MOVE NBCURCD TO PM-CURRENCY-CODE.

      *---------------------------------------------------------------*
      * 2000 - DISPLAY INSURED SECTION                                *
      *---------------------------------------------------------------*
       2000-DISPLAY-INSURED.
           WRITE NB-DSP-RECORD FORMAT IS 'NBINSKD'
           READ NBUWDSPF FORMAT IS 'NBINSKD'
           MOVE NBINSNAM TO PM-INSURED-NAME
           MOVE NBINSDOB TO PM-DATE-OF-BIRTH
           MOVE NBGENDER TO PM-GENDER
           MOVE NBSMOKER TO PM-SMOKER-STATUS
           MOVE NBOCCLAS TO PM-OCCUPATION-CLASS
           MOVE NBHIRAVOC TO PM-HIGH-RISK-AVOCATION
           IF NBFLTXTR NOT = SPACES
               MOVE NBFLTXTR TO PM-FLAT-EXTRA-RATE
           END-IF.

      *---------------------------------------------------------------*
      * 3000 - DISPLAY BENEFIT SECTION                                *
      *---------------------------------------------------------------*
       3000-DISPLAY-BENEFIT.
           WRITE NB-DSP-RECORD FORMAT IS 'NBBENEFIT'
           READ NBUWDSPF FORMAT IS 'NBBENEFIT'
           IF NBSUMASR NOT = SPACES
               MOVE NBSUMASR TO PM-SUM-ASSURED
           END-IF
           MOVE NBBILMOD TO PM-BILLING-MODE.

      *---------------------------------------------------------------*
      * 4000 - DISPLAY RIDER SECTION                                  *
      *---------------------------------------------------------------*
       4000-DISPLAY-RIDERS.
           MOVE PM-RIDER-CODE(1) TO NBRID1CD
           MOVE PM-RIDER-CODE(2) TO NBRID2CD
           MOVE PM-RIDER-CODE(3) TO NBRID3CD
           WRITE NB-DSP-RECORD FORMAT IS 'NBRIDERS'
           READ NBUWDSPF FORMAT IS 'NBRIDERS'
           IF NBRID1CD NOT = SPACES
               MOVE NBRID1CD TO PM-RIDER-CODE(1)
               IF NBRID1SA NOT = SPACES
                   MOVE NBRID1SA TO PM-RIDER-SUM-ASSURED(1)
               END-IF
           END-IF
           IF NBRID2CD NOT = SPACES
               MOVE NBRID2CD TO PM-RIDER-CODE(2)
               IF NBRID2SA NOT = SPACES
                   MOVE NBRID2SA TO PM-RIDER-SUM-ASSURED(2)
               END-IF
           END-IF
           IF NBRID3CD NOT = SPACES
               MOVE NBRID3CD TO PM-RIDER-CODE(3)
               IF NBRID3SA NOT = SPACES
                   MOVE NBRID3SA TO PM-RIDER-SUM-ASSURED(3)
               END-IF
           END-IF.

      *---------------------------------------------------------------*
      * 5000 - ISSUE POLICY (VALIDATE + CALCULATE + WRITE)           *
      *---------------------------------------------------------------*
       5000-ISSUE-POLICY.
      * LOAD PLAN PARAMETERS
           PERFORM 1100-LOAD-PLAN-PARAMETERS
           IF WS-RESULT-CODE NOT = 0
               PERFORM 8000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * VALIDATE
           PERFORM 1200-VALIDATE-APPLICATION
           IF WS-RESULT-CODE NOT = 0
               PERFORM 8000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * UW CLASS AND FACTORS
           PERFORM 1300-DETERMINE-UW-CLASS
           IF WS-RESULT-CODE NOT = 0
               PERFORM 8000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
           PERFORM 1400-LOAD-RATE-FACTORS
           PERFORM 1500-VALIDATE-RIDERS
           IF WS-RESULT-CODE NOT = 0
               PERFORM 8000-DISPLAY-RESULT
               EXIT PARAGRAPH
           END-IF
      * CALCULATE PREMIUM
           PERFORM 1600-CALCULATE-BASE-PREMIUM
           PERFORM 1700-CALCULATE-RIDER-PREMIUM
           PERFORM 1800-CALCULATE-TOTAL-PREMIUM
           PERFORM 1900-EVALUATE-REFERRALS
           PERFORM 2000-ISSUE-POLICY-RECORD
      * WRITE OR REWRITE POLMST
           READ POLMST KEY IS PM-POLICY-ID
               INVALID KEY
                   WRITE WS-POLICY-MASTER-REC
               NOT INVALID KEY
                   REWRITE WS-POLICY-MASTER-REC
           END-READ
           PERFORM 8000-DISPLAY-RESULT.

      *---------------------------------------------------------------*
      * 8000 - DISPLAY RESULT SCREEN                                  *
      *---------------------------------------------------------------*
       8000-DISPLAY-RESULT.
           MOVE WS-RESULT-CODE TO NBRETCD
           MOVE PM-CONTRACT-STATUS TO NBCNTRST
           MOVE PM-MODAL-PREMIUM TO NBMODPRM
           MOVE PM-TOTAL-ANNUAL-PREMIUM TO NBANPREM
           MOVE WS-RESULT-MESSAGE TO NBMSG
           WRITE NB-DSP-RECORD FORMAT IS 'NBRESULT'
           WRITE NB-DSP-RECORD FORMAT IS 'NBFKEYS'
           READ NBUWDSPF FORMAT IS 'NBRESULT'.

      *---------------------------------------------------------------*
      *  BUSINESS RULE PARAGRAPHS - SAME LOGIC AS NBUWB.CBLE         *
      *  MAINTAINED IN SYNC WITH BATCH PROGRAM.                       *
      *  VERSION: 1.4  LAST SYNC: 1998-11-14                         *
      *---------------------------------------------------------------*
       1100-LOAD-PLAN-PARAMETERS.
           EVALUATE PM-PLAN-CODE
               WHEN 'T1001'
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 60 TO PM-MAX-ISSUE-AGE
                   MOVE 10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE 50000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 10 TO PM-TERM-YEARS
                   MOVE 70 TO PM-MATURITY-AGE
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 4500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 1500 TO PM-SERVICE-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T2001'
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 55 TO PM-MAX-ISSUE-AGE
                   MOVE 10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE 90000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 20 TO PM-TERM-YEARS
                   MOVE 75 TO PM-MATURITY-AGE
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 5500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 1500 TO PM-SERVICE-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T6501'
                   MOVE 18 TO PM-MIN-ISSUE-AGE
                   MOVE 50 TO PM-MAX-ISSUE-AGE
                   MOVE 10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE 75000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE 65 TO PM-MATURITY-AGE
                   MOVE 30 TO PM-GRACE-DAYS
                   MOVE 2 TO PM-CONTESTABILITY-YRS
                   MOVE 2 TO PM-SUICIDE-YRS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 6000 TO PM-ANNUAL-POLICY-FEE
                   MOVE 1500 TO PM-SERVICE-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
                   COMPUTE PM-TERM-YEARS =
                       PM-MATURITY-AGE - PM-ISSUE-AGE
               WHEN OTHER
                   MOVE 21 TO WS-RESULT-CODE
                   MOVE 'INVALID PLAN CODE' TO WS-RESULT-MESSAGE
           END-EVALUATE.

       1200-VALIDATE-APPLICATION.
           IF PM-POLICY-ID = SPACES
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'POLICY ID IS REQUIRED' TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-INSURED-NAME = SPACES
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'INSURED NAME IS REQUIRED' TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-GENDER NOT = 'M' AND PM-GENDER NOT = 'F'
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'GENDER MUST BE M OR F' TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-SMOKER-STATUS NOT = 'S' AND
              PM-SMOKER-STATUS NOT = 'N'
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'SMOKER STATUS MUST BE S OR N'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-BILLING-MODE NOT = 'A' AND
              PM-BILLING-MODE NOT = 'S' AND
              PM-BILLING-MODE NOT = 'Q' AND
              PM-BILLING-MODE NOT = 'M'
               MOVE 11 TO WS-RESULT-CODE
               MOVE 'BILLING MODE MUST BE A S Q OR M'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-ISSUE-AGE < PM-MIN-ISSUE-AGE OR
              PM-ISSUE-AGE > PM-MAX-ISSUE-AGE
               MOVE 12 TO WS-RESULT-CODE
               MOVE 'ISSUE AGE OUTSIDE PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-SUM-ASSURED < PM-MIN-SUM-ASSURED OR
              PM-SUM-ASSURED > PM-MAX-SUM-ASSURED
               MOVE 13 TO WS-RESULT-CODE
               MOVE 'SUM ASSURED OUTSIDE PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-ISSUE-AGE + PM-TERM-YEARS > PM-MATURITY-AGE
               MOVE 14 TO WS-RESULT-CODE
               MOVE 'ISSUE AGE + TERM EXCEEDS MATURITY AGE'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-PLAN-CODE = 'T6501' AND
              PM-OCCUPATION-CLASS = 3
               MOVE 15 TO WS-RESULT-CODE
               MOVE 'T65 PLAN: HAZARDOUS OCCUPATION NOT PERMITTED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
           IF PM-OCCUPATION-CLASS = 4
               MOVE 16 TO WS-RESULT-CODE
               MOVE 'SEVERE OCCUPATION: APPLICATION DECLINED'
                   TO WS-RESULT-MESSAGE
               MOVE 'DP' TO PM-UW-CLASS
           END-IF.

       1300-DETERMINE-UW-CLASS.
           MOVE 'ST' TO PM-UW-CLASS
           IF PM-NON-SMOKER AND PM-OCCUPATION-CLASS = 1 AND
              PM-ISSUE-AGE <= 45 AND PM-HIGH-RISK-AVOCATION = 'N'
               MOVE 'PR' TO PM-UW-CLASS
           END-IF
           IF PM-SMOKER OR PM-OCCUPATION-CLASS = 3 OR
              PM-HIGH-RISK-AVOCATION = 'Y'
               MOVE 'TB' TO PM-UW-CLASS
           END-IF
           IF PM-SMOKER AND PM-ISSUE-AGE > 60 AND
              PM-SUM-ASSURED > 25000000000000
               MOVE 22 TO WS-RESULT-CODE
               MOVE 'SMOKER OVER 60 SA EXCEEDS 25B: DECLINED'
                   TO WS-RESULT-MESSAGE
               MOVE 'DP' TO PM-UW-CLASS
           END-IF.

       1400-LOAD-RATE-FACTORS.
           EVALUATE TRUE
               WHEN PM-ISSUE-AGE <= 30 MOVE 0.8500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 40 MOVE 1.2000 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 50 MOVE 2.1500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 60 MOVE 4.1000 TO PM-BASE-MORTALITY-RATE
               WHEN OTHER              MOVE 7.2500 TO PM-BASE-MORTALITY-RATE
           END-EVALUATE
           IF PM-FEMALE MOVE 0.9200 TO PM-GENDER-FACTOR
           ELSE MOVE 1.0000 TO PM-GENDER-FACTOR END-IF
           IF PM-SMOKER MOVE 1.7500 TO PM-SMOKER-FACTOR
           ELSE MOVE 1.0000 TO PM-SMOKER-FACTOR END-IF
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

       1500-VALIDATE-RIDERS.
           MOVE 0 TO WS-RIDER-IDX
           PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
               UNTIL PM-RIDER-IDX > 5
               IF PM-RIDER-CODE(PM-RIDER-IDX) NOT = SPACES
                   ADD 1 TO WS-RIDER-IDX
                   IF WS-RIDER-IDX > 5
                       MOVE 23 TO WS-RESULT-CODE
                       MOVE 'MAXIMUM 5 RIDERS ALLOWED' TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01' AND
                      PM-ISSUE-AGE > 60
                       MOVE 24 TO WS-RESULT-CODE
                       MOVE 'ADB RIDER: INSURED MUST BE AGE 60 OR UNDER'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'WOP01' AND
                      (PM-ISSUE-AGE < 18 OR PM-ISSUE-AGE > 55)
                       MOVE 25 TO WS-RESULT-CODE
                       MOVE 'WOP RIDER: INSURED MUST BE AGE 18 TO 55'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'CI001' AND
                      PM-RIDER-SUM-ASSURED(PM-RIDER-IDX) > 500000
                       MOVE 26 TO WS-RESULT-CODE
                       MOVE 'CI RIDER: SUM ASSURED EXCEEDS 500,000'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
               END-IF
           END-PERFORM.

       1600-CALCULATE-BASE-PREMIUM.
           COMPUTE PM-BASE-ANNUAL-PREMIUM =
               (PM-SUM-ASSURED / 1000) * PM-BASE-MORTALITY-RATE
               * PM-GENDER-FACTOR * PM-SMOKER-FACTOR
               * PM-OCCUPATION-FACTOR * PM-UW-FACTOR
           IF PM-FLAT-EXTRA-RATE > 0
               COMPUTE PM-BASE-ANNUAL-PREMIUM = PM-BASE-ANNUAL-PREMIUM
                   + ((PM-SUM-ASSURED / 1000) * PM-FLAT-EXTRA-RATE)
           END-IF.

       1700-CALCULATE-RIDER-PREMIUM.
           MOVE ZEROS TO PM-RIDER-ANNUAL-TOTAL
           PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
               UNTIL PM-RIDER-IDX > 5
               IF PM-RIDER-CODE(PM-RIDER-IDX) NOT = SPACES
                   MOVE 'A' TO PM-RIDER-STATUS(PM-RIDER-IDX)
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           (PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)/1000)*0.1800
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'WOP01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           PM-BASE-ANNUAL-PREMIUM * 0.06
                   END-IF
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'CI001'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           (PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)/1000)*1.2500
                   END-IF
                   ADD PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX)
                       TO PM-RIDER-ANNUAL-TOTAL
               END-IF
           END-PERFORM.

       1800-CALCULATE-TOTAL-PREMIUM.
           COMPUTE PM-GROSS-ANNUAL-PREMIUM =
               PM-BASE-ANNUAL-PREMIUM + PM-RIDER-ANNUAL-TOTAL
               + PM-ANNUAL-POLICY-FEE
           COMPUTE PM-TAX-AMOUNT =
               PM-GROSS-ANNUAL-PREMIUM * PM-TAX-RATE
           COMPUTE PM-TOTAL-ANNUAL-PREMIUM =
               PM-GROSS-ANNUAL-PREMIUM + PM-TAX-AMOUNT
           EVALUATE PM-BILLING-MODE
               WHEN 'A' MOVE 1 TO WS-MODAL-DIVISOR
                        MOVE 1.0000 TO WS-MODAL-FACTOR
               WHEN 'S' MOVE 2 TO WS-MODAL-DIVISOR
                        MOVE 1.0150 TO WS-MODAL-FACTOR
               WHEN 'Q' MOVE 4 TO WS-MODAL-DIVISOR
                        MOVE 1.0300 TO WS-MODAL-FACTOR
               WHEN 'M' MOVE 12 TO WS-MODAL-DIVISOR
                        MOVE 1.0800 TO WS-MODAL-FACTOR
           END-EVALUATE
           COMPUTE PM-MODAL-PREMIUM =
               (PM-TOTAL-ANNUAL-PREMIUM / WS-MODAL-DIVISOR)
               * WS-MODAL-FACTOR.

       1900-EVALUATE-REFERRALS.
           IF PM-SUM-ASSURED > 45000000000000
               MOVE 'Y' TO WS-REINSURANCE-REFERRAL
           END-IF
           IF PM-UW-TABLE-B OR PM-HIGH-RISK-AVOCATION = 'Y' OR
              PM-FLAT-EXTRA-RATE > 2.50
               MOVE 'Y' TO WS-UW-REFERRAL
           END-IF.

       2000-ISSUE-POLICY-RECORD.
           IF WS-REINSURANCE-REFERRAL = 'Y' OR WS-UW-REFERRAL = 'Y'
               MOVE 'PE' TO PM-CONTRACT-STATUS
               MOVE 2 TO WS-RESULT-CODE
               MOVE 'POLICY REFERRED FOR REVIEW' TO WS-RESULT-MESSAGE
           ELSE
               MOVE PM-PROCESS-DATE TO PM-ISSUE-DATE
               MOVE PM-PROCESS-DATE TO PM-EFFECTIVE-DATE
               MOVE PM-PROCESS-DATE TO PM-PAID-TO-DATE
               COMPUTE PM-EXPIRY-DATE =
                   PM-PROCESS-DATE + (PM-TERM-YEARS * 365)
               MOVE 'AC' TO PM-CONTRACT-STATUS
               MOVE 0 TO WS-RESULT-CODE
               MOVE 'POLICY ISSUED SUCCESSFULLY' TO WS-RESULT-MESSAGE
           END-IF
           MOVE 'NBUWMNT' TO PM-LAST-ACTION-USER
           MOVE PM-PROCESS-DATE TO PM-LAST-ACTION-DATE.
