      ******************************************************************
      * PLCYMSTR - POLICY MASTER RECORD (LEGACY_PAS NIGHTLY EXTRACT)   *
      * OWNER: GROUP IT MAINFRAME SERVICES (EX-PROVIDENT MUTUAL EST.)  *
      * LRECL: 80  RECFM: FB                                           *
      * NOTE: CLIENT-NO IS *NOT* THE SAME AS POLARIS PARTY_ID. THE     *
      * CROSSWALK IS MAINTAINED MANUALLY IN XREF_CLIENT_PARTY (DB2)    *
      * LAST CHANGED 14/03/2011 - G.HARGREAVES (RETIRED)               *
      ******************************************************************
       01  PLCY-MASTER-REC.
           05  PLCY-POLICY-NO           PIC X(18).
           05  PLCY-CLIENT-NO           PIC 9(10).
           05  PLCY-PRODUCT-CD          PIC X(04).
      *        VALID VALUES: MOT HOM PET TRV CPM CLB (SEE UW MANUAL)
           05  PLCY-INCEPT-DT-JUL       PIC 9(05).
      *        JULIAN DATE YYDDD - Y2K WINDOWING: 00-49 = 20XX
           05  PLCY-ANNL-PREM           PIC 9(09)V99.
      *        STORED IN PENCE, IMPLIED DECIMAL
           05  PLCY-STATUS              PIC X(02).
               88  PLCY-INFORCE         VALUE 'IF'.
               88  PLCY-RENEWED         VALUE 'RN'.
               88  PLCY-LAPSED          VALUE 'LP'.
               88  PLCY-CANCELLED       VALUE 'CN'.
               88  PLCY-EXPIRED         VALUE 'EX'.
               88  PLCY-ACTIVE          VALUE 'IF' 'RN'.
      *        NB: UNDERWRITING TREAT 'IF','RN' AS ACTIVE.
      *        FINANCE ONLY COUNT 'IF' WITH PAID-TO >= TODAY (SEE
      *        FINREC02 BATCH) - DO NOT RECONCILE THESE TWO NUMBERS
           05  PLCY-POSTCODE            PIC X(08).
               88  PLCY-POSTCODE-VALID  VALUE 'A' THRU 'Z'.
      *        WEAK CHECK - FIRST CHAR ALPHA ONLY. KNOWN DEFECT PR4471
           05  PLCY-SURNAME             PIC X(20).
