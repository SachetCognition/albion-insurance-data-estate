      *===============================================================*
      * COPYBOOK:  POLDATA                                            *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE              *
      * AUTHOR:    R. KOWALSKI                                        *
      * DATE:      1997-09-12                                         *
      * VERSION:   1.4                                                *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW                *
      *            1998-03-05 - ADDED SERVICING DETAILS SECTION      *
      *            1997-11-02 - ADDED CLAIM DETAILS SECTION          *
      *---------------------------------------------------------------*
      * POLICY MASTER RECORD - SHARED ACROSS ALL LIFE400 MODULES     *
      * USED BY: NBUWB, CLMADJB, SVCBILB, NBUWMNT, CLMMNT, SVCMNT  *
      *===============================================================*
       01  WS-POLICY-MASTER-REC.
      *--- CONTROL AREA -------------------------------------------*
           05  PM-CONTROL-AREA.
               10  PM-POLICY-ID             PIC X(12).
               10  PM-APPLICATION-ID        PIC X(12).
      *Y2K-REVIEWED 1998-11-14 - STORED AS YYYYMMDD (8-DIGIT)
               10  PM-PROCESS-DATE          PIC 9(08).
               10  PM-PLAN-CODE             PIC X(05).
               10  PM-CONTRACT-STATUS       PIC X(02).
                   88  PM-STATUS-PENDING    VALUE 'PE'.
                   88  PM-STATUS-ACTIVE     VALUE 'AC'.
                   88  PM-STATUS-GRACE      VALUE 'GR'.
                   88  PM-STATUS-LAPSED     VALUE 'LA'.
                   88  PM-STATUS-REINSTATED VALUE 'RS'.
                   88  PM-STATUS-CLAIMED    VALUE 'CL'.
                   88  PM-STATUS-TERMINATED VALUE 'TE'.
                   88  PM-STATUS-DECLINED   VALUE 'RJ'.
               10  PM-ISSUE-CHANNEL         PIC X(02).
                   88  PM-CHANNEL-BRANCH    VALUE 'BR'.
                   88  PM-CHANNEL-AGENT     VALUE 'AG'.
                   88  PM-CHANNEL-ONLINE    VALUE 'ON'.
               10  PM-CURRENCY-CODE         PIC X(03).
               10  PM-RETURN-CODE           PIC 9(02) VALUE 0.
               10  PM-RETURN-MESSAGE        PIC X(100) VALUE SPACES.
      *--- PLAN PARAMETERS ----------------------------------------*
           05  PM-PLAN-PARAMETERS.
               10  PM-MIN-ISSUE-AGE         PIC 9(03).
               10  PM-MAX-ISSUE-AGE         PIC 9(03).
               10  PM-MIN-SUM-ASSURED       PIC 9(13)V99.
               10  PM-MAX-SUM-ASSURED       PIC 9(13)V99.
               10  PM-TERM-YEARS            PIC 9(03).
               10  PM-MATURITY-AGE          PIC 9(03).
               10  PM-GRACE-DAYS            PIC 9(03).
               10  PM-CONTESTABILITY-YRS    PIC 9(02).
               10  PM-SUICIDE-YRS           PIC 9(02).
               10  PM-REINSTATE-WINDOW      PIC 9(04).
               10  PM-ANNUAL-POLICY-FEE     PIC 9(07)V99.
               10  PM-SERVICE-FEE           PIC 9(07)V99.
               10  PM-TAX-RATE              PIC 9(02)V9999.
      *--- INSURED DETAILS ----------------------------------------*
           05  PM-INSURED-DETAILS.
               10  PM-INSURED-NAME          PIC X(40).
      *Y2K-REVIEWED 1998-11-14 - STORED AS YYYYMMDD (8-DIGIT)
               10  PM-DATE-OF-BIRTH         PIC 9(08).
               10  PM-ISSUE-AGE             PIC 9(03).
               10  PM-ATTAINED-AGE          PIC 9(03).
               10  PM-GENDER                PIC X(01).
                   88  PM-FEMALE            VALUE 'F'.
                   88  PM-MALE              VALUE 'M'.
               10  PM-SMOKER-STATUS         PIC X(01).
                   88  PM-SMOKER            VALUE 'S'.
                   88  PM-NON-SMOKER        VALUE 'N'.
               10  PM-OCCUPATION-CLASS      PIC 9(01).
               10  PM-UW-CLASS              PIC X(02).
                   88  PM-UW-PREFERRED      VALUE 'PR'.
                   88  PM-UW-STANDARD       VALUE 'ST'.
                   88  PM-UW-TABLE-B        VALUE 'TB'.
                   88  PM-UW-DECLINE        VALUE 'DP'.
               10  PM-HIGH-RISK-AVOCATION   PIC X(01) VALUE 'N'.
               10  PM-FLAT-EXTRA-RATE       PIC 9(02)V9999 VALUE 0.
      *--- BENEFIT DETAILS ----------------------------------------*
           05  PM-BENEFIT-DETAILS.
               10  PM-SUM-ASSURED           PIC 9(13)V99.
               10  PM-POLICY-LOAN-BALANCE   PIC 9(13)V99 VALUE 0.
               10  PM-BILLING-MODE          PIC X(01).
                   88  PM-MODE-ANNUAL       VALUE 'A'.
                   88  PM-MODE-SEMI         VALUE 'S'.
                   88  PM-MODE-QUARTERLY    VALUE 'Q'.
                   88  PM-MODE-MONTHLY      VALUE 'M'.
               10  PM-BASE-MORTALITY-RATE   PIC 9(02)V9999.
               10  PM-GENDER-FACTOR         PIC 9(01)V9999.
               10  PM-SMOKER-FACTOR         PIC 9(01)V9999.
               10  PM-OCCUPATION-FACTOR     PIC 9(01)V9999.
               10  PM-UW-FACTOR             PIC 9(01)V9999.
               10  PM-RIDER-TABLE OCCURS 5 TIMES
                              INDEXED BY PM-RIDER-IDX.
                   15  PM-RIDER-CODE        PIC X(05).
                   15  PM-RIDER-SUM-ASSURED PIC 9(13)V99.
                   15  PM-RIDER-RATE        PIC 9(02)V9999.
                   15  PM-RIDER-ANNUAL-PREM PIC 9(13)V99.
                   15  PM-RIDER-STATUS      PIC X(01).
                       88  PM-RIDER-ACTIVE  VALUE 'A'.
                       88  PM-RIDER-REMOVED VALUE 'R'.
      *--- PREMIUM RESULTS ----------------------------------------*
           05  PM-PREMIUM-RESULTS.
               10  PM-BASE-ANNUAL-PREMIUM   PIC 9(13)V99.
               10  PM-RIDER-ANNUAL-TOTAL    PIC 9(13)V99.
               10  PM-GROSS-ANNUAL-PREMIUM  PIC 9(13)V99.
               10  PM-TAX-AMOUNT            PIC 9(13)V99.
               10  PM-TOTAL-ANNUAL-PREMIUM  PIC 9(13)V99.
               10  PM-MODAL-PREMIUM         PIC 9(13)V99.
               10  PM-OUTSTANDING-PREMIUM   PIC 9(13)V99.
               10  PM-PREMIUM-DELTA         PIC S9(13)V99.
      *--- DATE DETAILS -------------------------------------------*
           05  PM-DATE-DETAILS.
      *Y2K-REVIEWED 1998-11-14 - ALL DATES 8-DIGIT YYYYMMDD
               10  PM-ISSUE-DATE            PIC 9(08).
               10  PM-EFFECTIVE-DATE        PIC 9(08).
               10  PM-PAID-TO-DATE          PIC 9(08).
               10  PM-EXPIRY-DATE           PIC 9(08).
               10  PM-LAST-MAINT-DATE       PIC 9(08).
               10  PM-DATE-OF-DEATH         PIC 9(08).
      *--- SERVICING DETAILS --------------------------------------*
           05  PM-SERVICING-DETAILS.
               10  PM-AMENDMENT-TYPE        PIC X(02).
                   88  PM-AMD-PLAN-CHANGE   VALUE 'PL'.
                   88  PM-AMD-SUM-ASSURED   VALUE 'SA'.
                   88  PM-AMD-BILLING-MODE  VALUE 'BM'.
                   88  PM-AMD-ADD-RIDER     VALUE 'AR'.
                   88  PM-AMD-REMOVE-RIDER  VALUE 'RR'.
                   88  PM-AMD-REINSTATE     VALUE 'RI'.
               10  PM-OLD-PLAN-CODE         PIC X(05).
               10  PM-NEW-PLAN-CODE         PIC X(05).
               10  PM-OLD-SUM-ASSURED       PIC 9(13)V99.
               10  PM-NEW-SUM-ASSURED       PIC 9(13)V99.
               10  PM-OLD-BILLING-MODE      PIC X(01).
               10  PM-NEW-BILLING-MODE      PIC X(01).
               10  PM-SERVICE-FEE-CHARGED   PIC 9(07)V99.
               10  PM-UW-REQUIRED           PIC X(01) VALUE 'N'.
               10  PM-AMENDMENT-STATUS      PIC X(02).
                   88  PM-AMD-PENDING       VALUE 'PE'.
                   88  PM-AMD-APPROVED      VALUE 'AP'.
                   88  PM-AMD-REJECTED      VALUE 'RJ'.
      *--- CLAIM DETAILS ------------------------------------------*
           05  PM-CLAIM-DETAILS.
               10  PM-CLAIM-ID              PIC X(12).
               10  PM-CLAIM-TYPE            PIC X(02).
                   88  PM-CLAIM-DEATH       VALUE 'DT'.
               10  PM-CAUSE-OF-DEATH        PIC X(03).
                   88  PM-CAUSE-NATURAL     VALUE 'NAT'.
                   88  PM-CAUSE-ACCIDENT    VALUE 'ACC'.
                   88  PM-CAUSE-SUICIDE     VALUE 'SUI'.
                   88  PM-CAUSE-HOMICIDE    VALUE 'HOM'.
                   88  PM-CAUSE-UNKNOWN     VALUE 'UNK'.
               10  PM-DEATH-CERT-RECD       PIC X(01) VALUE 'N'.
               10  PM-CLAIM-FORM-RECD       PIC X(01) VALUE 'N'.
               10  PM-ID-PROOF-RECD         PIC X(01) VALUE 'N'.
               10  PM-MEDICAL-RECORDS-RECD  PIC X(01) VALUE 'N'.
               10  PM-CLAIM-SUBMIT-DATE     PIC 9(08).
               10  PM-CLAIM-INVEST-DATE     PIC 9(08).
               10  PM-CLAIM-ADJUDIC-DATE    PIC 9(08).
               10  PM-CLAIM-SETTLE-DATE     PIC 9(08).
               10  PM-BENEFICIARY-NAME      PIC X(40).
               10  PM-BENEFICIARY-RELATION  PIC X(20).
               10  PM-CLAIM-PAYMENT-MODE    PIC X(01).
                   88  PM-PAY-CHECK         VALUE 'C'.
                   88  PM-PAY-ACH           VALUE 'A'.
               10  PM-INVESTIGATION-STATUS  PIC X(01).
                   88  PM-INVEST-NOT-REQ    VALUE 'N'.
                   88  PM-INVEST-PENDING    VALUE 'P'.
                   88  PM-INVEST-COMPLETE   VALUE 'C'.
               10  PM-CLAIM-DECISION        PIC X(01).
                   88  PM-DECISION-APPROVED VALUE 'A'.
                   88  PM-DECISION-REJECTED VALUE 'R'.
                   88  PM-DECISION-PENDING  VALUE 'P'.
               10  PM-CLAIM-PAYMENT-AMT     PIC 9(13)V99.
               10  PM-CLAIM-HOLD-REASON     PIC X(50).
      *--- AUDIT DETAILS ------------------------------------------*
           05  PM-AUDIT-DETAILS.
               10  PM-LAST-ACTION-USER      PIC X(10).
      *Y2K-REVIEWED 1998-11-14
               10  PM-LAST-ACTION-DATE      PIC 9(08).
