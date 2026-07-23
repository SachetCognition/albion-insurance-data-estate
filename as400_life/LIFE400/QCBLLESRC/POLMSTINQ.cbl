      *===============================================================*
      * PROGRAM:   POLMSTINQ                                         *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    T. WALSH                                          *
      * DATE:      1998-01-20                                        *
      * VERSION:   1.0                                               *
      * MODIFIED:  1998-11-14 - Y2K DATE FIELD REVIEW               *
      *---------------------------------------------------------------*
      * INTERACTIVE POLICY MASTER INQUIRY (READ-ONLY)               *
      * SCREEN FLOW:                                                  *
      *   SVCHDR (ENTER POLICY ID) -> SVCPOL (DISPLAY RECORD)       *
      *   -> F3=EXIT OR F12=BACK                                      *
      *                                                               *
      * NOTE: USES SVCDSPF WITH INDICATOR 90 SET TO SUPPRESS        *
      *       AMENDMENT FIELDS AND SHOW INQUIRY-MODE FUNCTION KEYS   *
      *---------------------------------------------------------------*
      * CALLED BY: MAINMENU                                           *
      * FILES:     SVCDSPF (WORKSTATION), POLMST (INDEXED INPUT)     *
      * COPYBOOK:  POLDATA (QCPYSRC)                                 *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. POLMSTINQ.
       AUTHOR.     T. WALSH.
       DATE-WRITTEN. 1998-01-20.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-AS400.
       OBJECT-COMPUTER. IBM-AS400.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SVCDSPF
               ASSIGN TO WORKSTATION-SVCDSPF
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
       FD  SVCDSPF.
       01  INQ-DSP-RECORD            PIC X(80).
       FD  POLMST.
       COPY POLDATA.

       WORKING-STORAGE SECTION.
       77  WS-DSP-STATUS             PIC X(02) VALUE SPACES.
       77  WS-POLMST-STATUS          PIC X(02) VALUE SPACES.
       77  WS-CONTINUE               PIC X VALUE 'Y'.
       77  WS-NOT-FOUND-MSG          PIC X(40)
               VALUE 'POLICY NOT FOUND - PLEASE TRY AGAIN'.

       PROCEDURE DIVISION.

       MAIN-PROCESS.
           OPEN I-O SVCDSPF
           OPEN INPUT POLMST

           PERFORM UNTIL WS-CONTINUE = 'N'
               PERFORM 1000-GET-POLICY-ID
               IF *IN03 = '1' OR *IN12 = '1'
                   MOVE 'N' TO WS-CONTINUE
               ELSE
                   PERFORM 2000-LOOKUP-POLICY
                   IF WS-POLMST-STATUS = '00'
                       PERFORM 3000-DISPLAY-POLICY
                   ELSE
                       MOVE WS-NOT-FOUND-MSG TO SVCMSG
                       WRITE INQ-DSP-RECORD FORMAT IS 'SVCRESULT'
                       READ SVCDSPF FORMAT IS 'SVCRESULT'
                   END-IF
               END-IF
           END-PERFORM

           CLOSE SVCDSPF POLMST
           GOBACK.

      *---------------------------------------------------------------*
      * 1000 - DISPLAY HEADER AND GET POLICY ID                       *
      *---------------------------------------------------------------*
       1000-GET-POLICY-ID.
           MOVE SPACES TO SVCPOLID
      *Y2K-REVIEWED 1998-11-14
           ACCEPT SVCPRCDT FROM DATE YYYYMMDD
      * SET INDICATOR 90 = INQUIRY MODE (HIDES AMENDMENT FIELDS)
           MOVE '1' TO *IN90
           WRITE INQ-DSP-RECORD FORMAT IS 'SVCHDR'
           READ SVCDSPF FORMAT IS 'SVCHDR'
           MOVE SVCPOLID TO PM-POLICY-ID
           MOVE SVCPRCDT TO PM-PROCESS-DATE.

      *---------------------------------------------------------------*
      * 2000 - LOOK UP POLICY                                         *
      *---------------------------------------------------------------*
       2000-LOOKUP-POLICY.
           READ POLMST KEY IS PM-POLICY-ID
               INVALID KEY
                   CONTINUE
               NOT INVALID KEY
                   CONTINUE
           END-READ.

      *---------------------------------------------------------------*
      * 3000 - DISPLAY POLICY (READ-ONLY)                             *
      *---------------------------------------------------------------*
       3000-DISPLAY-POLICY.
           MOVE PM-PLAN-CODE TO SVCPLANC
           MOVE PM-CONTRACT-STATUS TO SVCCNTRST
           MOVE PM-BILLING-MODE TO SVCBILMD
           MOVE PM-SUM-ASSURED TO SVCSUMASR
           MOVE PM-MODAL-PREMIUM TO SVCMODPRM
           MOVE PM-INSURED-NAME TO SVCINSNAM
           MOVE PM-ISSUE-AGE TO SVCISSAGE
           MOVE PM-ATTAINED-AGE TO SVCATTNAG
           MOVE PM-ISSUE-DATE TO SVCISSDT
           MOVE PM-EXPIRY-DATE TO SVCEXPDT
           MOVE PM-PAID-TO-DATE TO SVCPAIDTO
           MOVE SPACES TO SVCMSG
           WRITE INQ-DSP-RECORD FORMAT IS 'SVCPOL'
           WRITE INQ-DSP-RECORD FORMAT IS 'SVCFKEYS'
           READ SVCDSPF FORMAT IS 'SVCPOL'
      * F3 OR F12 RETURN TO MENU - LOOP CONTINUES FOR NEXT INQUIRY
           IF *IN03 = '1' OR *IN12 = '1'
               MOVE 'N' TO WS-CONTINUE
           END-IF.
