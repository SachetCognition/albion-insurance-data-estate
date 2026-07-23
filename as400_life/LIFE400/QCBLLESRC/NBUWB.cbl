      *===============================================================*
      * PROGRAM:   NBUWB                                             *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    R. KOWALSKI                                       *
      * DATE:      1997-09-15                                        *
      * VERSION:   1.3                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *            1998-05-20 - ADDED REINSURANCE REFERRAL LOGIC    *
      *            1998-01-08 - ADDED T6501 PLAN CODE               *
      *---------------------------------------------------------------*
      * BATCH NEW BUSINESS AND UNDERWRITING                          *
      * DOMAIN:  TERM LIFE - NEW BUSINESS AND POLICY ISSUANCE       *
      * PURPOSE: VALIDATE ELIGIBILITY, LOAD PLAN PARAMETERS,        *
      *          DETERMINE UW CLASS, CALCULATE PREMIUM, VALIDATE    *
      *          RIDERS, AND DECIDE WHETHER TO ISSUE, REFER OR      *
      *          DECLINE THE APPLICATION.                            *
      *---------------------------------------------------------------*
      * CALLED BY: RUNNBUW (CL)                                      *
      * FILES:     POLMST (I-O INDEXED)                              *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *---------------------------------------------------------------*
      * RETURN CODES:                                                 *
      *  00 - POLICY ISSUED SUCCESSFULLY                             *
      *  02 - REFERRED (MANUAL UW OR REINSURANCE REVIEW)            *
      *  11 - MISSING MANDATORY FIELDS                               *
      *  12 - ISSUE AGE OUT OF PLAN LIMITS                          *
      *  13 - SUM ASSURED OUT OF PLAN LIMITS                        *
      *  14 - MATURITY AGE EXCEEDED                                  *
      *  15 - T65 PLAN: HAZARDOUS OCCUPATION NOT ALLOWED            *
      *  16 - SEVERE OCCUPATION - AUTOMATIC DECLINE                 *
      *  21 - INVALID PLAN CODE                                      *
      *  22 - SMOKER + AGE>60 + SA>25B: DECLINE                    *
      *  23 - RIDER LIMIT EXCEEDED                                   *
      *  24 - ADB RIDER: INSURED OVER AGE 60                        *
      *  25 - WOP RIDER: AGE NOT IN 18-55 RANGE                     *
      *  26 - CI RIDER: SUM ASSURED EXCEEDS 500000                  *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NBUWB.
       AUTHOR.     R. KOWALSKI.
       DATE-WRITTEN. 1997-09-15.

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

       DATA DIVISION.
       FILE SECTION.
       FD  POLMST.
       COPY POLDATA.

       WORKING-STORAGE SECTION.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-CURR-DATE              PIC 9(08).
       77  WS-RIDER-IDX              PIC 9(02) VALUE 0.
       77  WS-DATE-INT               PIC 9(09) VALUE 0.
       77  WS-MODAL-DIVISOR          PIC 9(02) VALUE 1.
       77  WS-MODAL-FACTOR           PIC 9(01)V9999 VALUE 1.0000.
       77  WS-REINSURANCE-REFERRAL   PIC X VALUE 'N'.
           88  WS-REFERRED           VALUE 'Y'.
       77  WS-UW-REFERRAL            PIC X VALUE 'N'.
           88  WS-MANUAL-UW          VALUE 'Y'.
       77  WS-RESULT-CODE            PIC 9(02) VALUE 0.
       77  WS-RESULT-MESSAGE         PIC X(100) VALUE SPACES.

       LINKAGE SECTION.
       01  LK-POLICY-ID              PIC X(12).

       PROCEDURE DIVISION USING LK-POLICY-ID.

       MAIN-PROCESS.
           MOVE LK-POLICY-ID TO PM-POLICY-ID
           OPEN I-O POLMST
           READ POLMST
               INVALID KEY
                   MOVE 21 TO WS-RESULT-CODE
                   MOVE 'POLICY RECORD NOT FOUND' TO WS-RESULT-MESSAGE
                   PERFORM 9000-RETURN-ERROR
                   CLOSE POLMST
                   GOBACK
           END-READ
           PERFORM 1000-INITIALIZE
           PERFORM 1100-LOAD-PLAN-PARAMETERS
           PERFORM 1200-VALIDATE-APPLICATION
           IF WS-RESULT-CODE NOT = 0
               PERFORM 9000-RETURN-ERROR
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST
               GOBACK
           END-IF
           PERFORM 1300-DETERMINE-UW-CLASS
           PERFORM 1400-LOAD-RATE-FACTORS
           PERFORM 1500-VALIDATE-RIDERS
           IF WS-RESULT-CODE NOT = 0
               PERFORM 9000-RETURN-ERROR
               REWRITE WS-POLICY-MASTER-REC
               CLOSE POLMST
               GOBACK
           END-IF
           PERFORM 1600-CALCULATE-BASE-PREMIUM
           PERFORM 1700-CALCULATE-RIDER-PREMIUM
           PERFORM 1800-CALCULATE-TOTAL-PREMIUM
           PERFORM 1900-EVALUATE-REFERRALS
           PERFORM 2000-ISSUE-POLICY
           REWRITE WS-POLICY-MASTER-REC
           CLOSE POLMST
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - INITIALIZE                                             *
      *---------------------------------------------------------------*
       1000-INITIALIZE.
           MOVE ZEROS TO PM-BASE-ANNUAL-PREMIUM
           MOVE ZEROS TO PM-RIDER-ANNUAL-TOTAL
           MOVE ZEROS TO PM-GROSS-ANNUAL-PREMIUM
           MOVE ZEROS TO PM-TAX-AMOUNT
           MOVE ZEROS TO PM-TOTAL-ANNUAL-PREMIUM
           MOVE ZEROS TO PM-MODAL-PREMIUM
           MOVE ZEROS TO WS-RESULT-CODE
           MOVE SPACES TO WS-RESULT-MESSAGE
           MOVE 'N' TO WS-REINSURANCE-REFERRAL
           MOVE 'N' TO WS-UW-REFERRAL
      *Y2K-REVIEWED 1998-11-14 - PROCESS DATE ALREADY 8-DIGIT YYYYMMDD
           IF PM-PROCESS-DATE = 0
               ACCEPT WS-CURR-DATE FROM DATE YYYYMMDD
               MOVE WS-CURR-DATE TO PM-PROCESS-DATE
           END-IF
           MOVE 'NBUWB' TO PM-LAST-ACTION-USER
           MOVE PM-PROCESS-DATE TO PM-LAST-ACTION-DATE.

      *---------------------------------------------------------------*
      * 1100 - LOAD PLAN PARAMETERS   (NB-101)                       *
      *---------------------------------------------------------------*
       1100-LOAD-PLAN-PARAMETERS.
           EVALUATE PM-PLAN-CODE
               WHEN 'T1001'
                   MOVE  18 TO PM-MIN-ISSUE-AGE
                   MOVE  60 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  50000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE  10 TO PM-TERM-YEARS
                   MOVE  70 TO PM-MATURITY-AGE
                   MOVE  30 TO PM-GRACE-DAYS
                   MOVE   2 TO PM-CONTESTABILITY-YRS
                   MOVE   2 TO PM-SUICIDE-YRS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 4500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 1500 TO PM-SERVICE-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T2001'
                   MOVE  18 TO PM-MIN-ISSUE-AGE
                   MOVE  55 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  90000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE  20 TO PM-TERM-YEARS
                   MOVE  75 TO PM-MATURITY-AGE
                   MOVE  30 TO PM-GRACE-DAYS
                   MOVE   2 TO PM-CONTESTABILITY-YRS
                   MOVE   2 TO PM-SUICIDE-YRS
                   MOVE 730 TO PM-REINSTATE-WINDOW
                   MOVE 5500 TO PM-ANNUAL-POLICY-FEE
                   MOVE 1500 TO PM-SERVICE-FEE
                   MOVE 0.0200 TO PM-TAX-RATE
               WHEN 'T6501'
                   MOVE  18 TO PM-MIN-ISSUE-AGE
                   MOVE  50 TO PM-MAX-ISSUE-AGE
                   MOVE  10000000000000 TO PM-MIN-SUM-ASSURED
                   MOVE  75000000000000 TO PM-MAX-SUM-ASSURED
                   MOVE  65 TO PM-MATURITY-AGE
                   MOVE  30 TO PM-GRACE-DAYS
                   MOVE   2 TO PM-CONTESTABILITY-YRS
                   MOVE   2 TO PM-SUICIDE-YRS
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

      *---------------------------------------------------------------*
      * 1200 - VALIDATE APPLICATION   (NB-201 THRU NB-206)           *
      *---------------------------------------------------------------*
       1200-VALIDATE-APPLICATION.
      * NB-201: MANDATORY FIELDS
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
      * NB-202: ISSUE AGE LIMITS
           IF PM-ISSUE-AGE < PM-MIN-ISSUE-AGE OR
              PM-ISSUE-AGE > PM-MAX-ISSUE-AGE
               MOVE 12 TO WS-RESULT-CODE
               MOVE 'ISSUE AGE OUTSIDE PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * NB-203: SUM ASSURED LIMITS
           IF PM-SUM-ASSURED < PM-MIN-SUM-ASSURED OR
              PM-SUM-ASSURED > PM-MAX-SUM-ASSURED
               MOVE 13 TO WS-RESULT-CODE
               MOVE 'SUM ASSURED OUTSIDE PLAN LIMITS'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * NB-204: MATURITY AGE RULE
           IF PM-ISSUE-AGE + PM-TERM-YEARS > PM-MATURITY-AGE
               MOVE 14 TO WS-RESULT-CODE
               MOVE 'ISSUE AGE + TERM EXCEEDS MATURITY AGE'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * NB-205: T65 PLAN - NO HAZARDOUS OCCUPATION
           IF PM-PLAN-CODE = 'T6501' AND
              PM-OCCUPATION-CLASS = 3
               MOVE 15 TO WS-RESULT-CODE
               MOVE 'T65 PLAN: HAZARDOUS OCCUPATION NOT PERMITTED'
                   TO WS-RESULT-MESSAGE
               EXIT PARAGRAPH
           END-IF
      * NB-206: SEVERE OCCUPATION = AUTOMATIC DECLINE
           IF PM-OCCUPATION-CLASS = 4
               MOVE 16 TO WS-RESULT-CODE
               MOVE 'SEVERE OCCUPATION: APPLICATION DECLINED'
                   TO WS-RESULT-MESSAGE
               MOVE 'DP' TO PM-UW-CLASS
               EXIT PARAGRAPH
           END-IF.

      *---------------------------------------------------------------*
      * 1300 - DETERMINE UW CLASS     (NB-301 THRU NB-303)           *
      *---------------------------------------------------------------*
       1300-DETERMINE-UW-CLASS.
      * NB-301: DEFAULT TO PREFERRED IF MEETS ALL CRITERIA
           MOVE 'ST' TO PM-UW-CLASS
           IF PM-NON-SMOKER AND
              PM-OCCUPATION-CLASS = 1 AND
              PM-ISSUE-AGE <= 45 AND
              PM-HIGH-RISK-AVOCATION = 'N'
               MOVE 'PR' TO PM-UW-CLASS
           END-IF
      * NB-302: TABLE-B CONDITIONS
           IF PM-SMOKER OR
              PM-OCCUPATION-CLASS = 3 OR
              PM-HIGH-RISK-AVOCATION = 'Y'
               MOVE 'TB' TO PM-UW-CLASS
           END-IF
      * NB-303: DECLINE - SMOKER OVER 60 WITH HIGH SA
           IF PM-SMOKER AND
              PM-ISSUE-AGE > 60 AND
              PM-SUM-ASSURED > 25000000000000
               MOVE 22 TO WS-RESULT-CODE
               MOVE 'SMOKER OVER 60 SA EXCEEDS 25B: DECLINED'
                   TO WS-RESULT-MESSAGE
               MOVE 'DP' TO PM-UW-CLASS
           END-IF.

      *---------------------------------------------------------------*
      * 1400 - LOAD RATE FACTORS       (NB-401 THRU NB-404)          *
      *---------------------------------------------------------------*
       1400-LOAD-RATE-FACTORS.
      * NB-401: BASE MORTALITY RATE BY AGE BAND
           EVALUATE TRUE
               WHEN PM-ISSUE-AGE <= 30
                   MOVE 0.8500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 40
                   MOVE 1.2000 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 50
                   MOVE 2.1500 TO PM-BASE-MORTALITY-RATE
               WHEN PM-ISSUE-AGE <= 60
                   MOVE 4.1000 TO PM-BASE-MORTALITY-RATE
               WHEN OTHER
                   MOVE 7.2500 TO PM-BASE-MORTALITY-RATE
           END-EVALUATE
      * NB-402: GENDER FACTOR
           IF PM-FEMALE
               MOVE 0.9200 TO PM-GENDER-FACTOR
           ELSE
               MOVE 1.0000 TO PM-GENDER-FACTOR
           END-IF
      * NB-403: SMOKER FACTOR
           IF PM-SMOKER
               MOVE 1.7500 TO PM-SMOKER-FACTOR
           ELSE
               MOVE 1.0000 TO PM-SMOKER-FACTOR
           END-IF
      * NB-404: OCCUPATION FACTOR
           EVALUATE PM-OCCUPATION-CLASS
               WHEN 1 MOVE 1.0000 TO PM-OCCUPATION-FACTOR
               WHEN 2 MOVE 1.1500 TO PM-OCCUPATION-FACTOR
               WHEN 3 MOVE 1.4000 TO PM-OCCUPATION-FACTOR
               WHEN OTHER MOVE 1.0000 TO PM-OCCUPATION-FACTOR
           END-EVALUATE
      * NB-405: UW CLASS FACTOR
           EVALUATE PM-UW-CLASS
               WHEN 'PR' MOVE 0.9000 TO PM-UW-FACTOR
               WHEN 'ST' MOVE 1.0000 TO PM-UW-FACTOR
               WHEN 'TB' MOVE 1.2500 TO PM-UW-FACTOR
               WHEN OTHER MOVE 1.0000 TO PM-UW-FACTOR
           END-EVALUATE.

      *---------------------------------------------------------------*
      * 1500 - VALIDATE RIDERS         (NB-501 THRU NB-504)          *
      *---------------------------------------------------------------*
       1500-VALIDATE-RIDERS.
           MOVE 0 TO WS-RIDER-IDX
           PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
               UNTIL PM-RIDER-IDX > 5
               IF PM-RIDER-CODE(PM-RIDER-IDX) NOT = SPACES
                   ADD 1 TO WS-RIDER-IDX
      * NB-501: MAX 5 RIDERS
                   IF WS-RIDER-IDX > 5
                       MOVE 23 TO WS-RESULT-CODE
                       MOVE 'MAXIMUM 5 RIDERS ALLOWED'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
      * NB-502: ADB01 - AGE CAP 60
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01' AND
                      PM-ISSUE-AGE > 60
                       MOVE 24 TO WS-RESULT-CODE
                       MOVE 'ADB RIDER: INSURED MUST BE AGE 60 OR UNDER'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
      * NB-503: WOP01 - AGE 18-55 ONLY
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'WOP01' AND
                      (PM-ISSUE-AGE < 18 OR PM-ISSUE-AGE > 55)
                       MOVE 25 TO WS-RESULT-CODE
                       MOVE 'WOP RIDER: INSURED MUST BE AGE 18 TO 55'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
      * NB-504: CI001 - MAX RIDER SA 500000
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'CI001' AND
                      PM-RIDER-SUM-ASSURED(PM-RIDER-IDX) > 500000
                       MOVE 26 TO WS-RESULT-CODE
                       MOVE 'CI RIDER: SUM ASSURED EXCEEDS 500,000'
                           TO WS-RESULT-MESSAGE
                       EXIT PARAGRAPH
                   END-IF
               END-IF
           END-PERFORM.

      *---------------------------------------------------------------*
      * 1600 - CALCULATE BASE PREMIUM  (NB-601)                      *
      *---------------------------------------------------------------*
       1600-CALCULATE-BASE-PREMIUM.
           COMPUTE PM-BASE-ANNUAL-PREMIUM =
               (PM-SUM-ASSURED / 1000)
               * PM-BASE-MORTALITY-RATE
               * PM-GENDER-FACTOR
               * PM-SMOKER-FACTOR
               * PM-OCCUPATION-FACTOR
               * PM-UW-FACTOR
           IF PM-FLAT-EXTRA-RATE > 0
               COMPUTE PM-BASE-ANNUAL-PREMIUM =
                   PM-BASE-ANNUAL-PREMIUM +
                   ((PM-SUM-ASSURED / 1000) * PM-FLAT-EXTRA-RATE)
           END-IF.

      *---------------------------------------------------------------*
      * 1700 - CALCULATE RIDER PREMIUMS (NB-701 THRU NB-703)         *
      *---------------------------------------------------------------*
       1700-CALCULATE-RIDER-PREMIUM.
           MOVE ZEROS TO PM-RIDER-ANNUAL-TOTAL
           PERFORM VARYING PM-RIDER-IDX FROM 1 BY 1
               UNTIL PM-RIDER-IDX > 5
               IF PM-RIDER-CODE(PM-RIDER-IDX) NOT = SPACES
                   MOVE 'A' TO PM-RIDER-STATUS(PM-RIDER-IDX)
      * NB-701: ADB01 - 0.1800 PER THOUSAND
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'ADB01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           (PM-RIDER-SUM-ASSURED(PM-RIDER-IDX)
                           / 1000) * 0.1800
                   END-IF
      * NB-702: WOP01 - 6% OF BASE ANNUAL PREMIUM
                   IF PM-RIDER-CODE(PM-RIDER-IDX) = 'WOP01'
                       COMPUTE PM-RIDER-ANNUAL-PREM(PM-RIDER-IDX) =
                           PM-BASE-ANNUAL-PREMIUM * 0.06
                   END-IF
      * NB-703: CI001 - 1.2500 PER THOUSAND
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
      * 1800 - CALCULATE TOTAL PREMIUM (NB-801 THRU NB-802)          *
      *---------------------------------------------------------------*
       1800-CALCULATE-TOTAL-PREMIUM.
      * NB-801: GROSS = BASE + RIDERS + POLICY FEE
           COMPUTE PM-GROSS-ANNUAL-PREMIUM =
               PM-BASE-ANNUAL-PREMIUM +
               PM-RIDER-ANNUAL-TOTAL +
               PM-ANNUAL-POLICY-FEE
      * TAX
           COMPUTE PM-TAX-AMOUNT =
               PM-GROSS-ANNUAL-PREMIUM * PM-TAX-RATE
           COMPUTE PM-TOTAL-ANNUAL-PREMIUM =
               PM-GROSS-ANNUAL-PREMIUM + PM-TAX-AMOUNT
      * NB-802: MODAL PREMIUM WITH LOADING FACTORS
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

      *---------------------------------------------------------------*
      * 1900 - EVALUATE REFERRALS      (NB-901 THRU NB-902)          *
      *---------------------------------------------------------------*
       1900-EVALUATE-REFERRALS.
      * NB-901: REINSURANCE - SA OVER 45B
           IF PM-SUM-ASSURED > 45000000000000
               MOVE 'Y' TO WS-REINSURANCE-REFERRAL
           END-IF
      * NB-902: MANUAL UW TRIGGERS
           IF PM-UW-TABLE-B OR
              PM-HIGH-RISK-AVOCATION = 'Y' OR
              PM-FLAT-EXTRA-RATE > 2.50
               MOVE 'Y' TO WS-UW-REFERRAL
           END-IF.

      *---------------------------------------------------------------*
      * 2000 - ISSUE POLICY            (NB-1001)                     *
      *---------------------------------------------------------------*
       2000-ISSUE-POLICY.
           IF WS-REFERRED OR WS-MANUAL-UW
               MOVE 'PE' TO PM-CONTRACT-STATUS
               MOVE  02  TO PM-RETURN-CODE
               MOVE 'POLICY REFERRED FOR REVIEW' TO PM-RETURN-MESSAGE
           ELSE
               MOVE PM-PROCESS-DATE TO PM-ISSUE-DATE
               MOVE PM-PROCESS-DATE TO PM-EFFECTIVE-DATE
               MOVE PM-PROCESS-DATE TO PM-PAID-TO-DATE
      *Y2K-REVIEWED 1998-11-14 - EXPIRY = PROCESS DATE + TERM*365
               COMPUTE PM-EXPIRY-DATE =
                   PM-PROCESS-DATE + (PM-TERM-YEARS * 365)
               MOVE 'AC' TO PM-CONTRACT-STATUS
               MOVE  00  TO PM-RETURN-CODE
               MOVE 'POLICY ISSUED SUCCESSFULLY' TO PM-RETURN-MESSAGE
           END-IF.

      *---------------------------------------------------------------*
      * 9000 - RETURN ERROR                                           *
      *---------------------------------------------------------------*
       9000-RETURN-ERROR.
           MOVE WS-RESULT-CODE TO PM-RETURN-CODE
           MOVE WS-RESULT-MESSAGE TO PM-RETURN-MESSAGE
           MOVE 'RJ' TO PM-CONTRACT-STATUS.
