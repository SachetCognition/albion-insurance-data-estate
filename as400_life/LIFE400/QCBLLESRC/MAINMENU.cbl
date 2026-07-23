      *===============================================================*
      * PROGRAM:   MAINMENU                                          *
      * SYSTEM:    LIFE400 - PROVIDENT MUTUAL ASSURANCE             *
      * AUTHOR:    R. KOWALSKI                                       *
      * DATE:      1997-09-12                                        *
      * VERSION:   1.2                                               *
      * MODIFIED:  1998-04-20 - ADDED REPORTS MENU OPTION           *
      *---------------------------------------------------------------*
      * INTERACTIVE MAIN MENU                                        *
      * ROUTES USER TO EACH SUBSYSTEM:                               *
      *   1 = NBUWMNT (NEW BUSINESS)                                 *
      *   2 = SVCMNT  (SERVICING)                                    *
      *   3 = CLMMNT  (CLAIMS)                                       *
      *   4 = POLMSTINQ (POLICY INQUIRY)                             *
      *  90 = SIGN OFF                                               *
      *---------------------------------------------------------------*
      * CALLED BY: STRTLIFE (CL)                                     *
      * FILES:     MNUDSPF (WORKSTATION)                             *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAINMENU.
       AUTHOR.     R. KOWALSKI.
       DATE-WRITTEN. 1997-09-12.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-AS400.
       OBJECT-COMPUTER. IBM-AS400.

       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MNUDSPF
               ASSIGN TO WORKSTATION-MNUDSPF
               ORGANIZATION IS TRANSACTION
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-DSP-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MNUDSPF.
       01  DSP-RECORD                PIC X(80).

       WORKING-STORAGE SECTION.
       77  WS-DSP-STATUS             PIC X(02) VALUE SPACES.
       77  WS-SELECTION              PIC X(02) VALUE SPACES.
       77  WS-CONTINUE               PIC X VALUE 'Y'.
       77  WS-CURR-DATE-6            PIC 9(06).
       77  WS-USER-ID                PIC X(10) VALUE SPACES.

       PROCEDURE DIVISION.

       MAIN-PROCESS.
           OPEN I-O MNUDSPF
      *Y2K-REVIEWED 1998-11-14 - 6-DIGIT DATE FOR DISPLAY ONLY (MMDDYY)
           ACCEPT WS-CURR-DATE-6 FROM DATE
           MOVE WS-CURR-DATE-6 TO MNUDATE
           ACCEPT WS-USER-ID FROM USER
           MOVE WS-USER-ID TO MNUUSER

           PERFORM UNTIL WS-CONTINUE = 'N'
               MOVE SPACES TO MNUSEL
               MOVE SPACES TO MNUMSGD
               WRITE DSP-RECORD FORMAT IS 'MAINSCR'
               READ MNUDSPF FORMAT IS 'MAINSCR'
               IF *IN03 = '1'
                   MOVE 'N' TO WS-CONTINUE
               ELSE IF *IN12 = '1'
                   MOVE 'N' TO WS-CONTINUE
               ELSE
                   MOVE MNUSEL TO WS-SELECTION
                   EVALUATE WS-SELECTION
                       WHEN '1 '
                           CALL 'NBUWMNT'
                       WHEN '2 '
                           CALL 'SVCMNT'
                       WHEN '3 '
                           CALL 'CLMMNT'
                       WHEN '4 '
                           CALL 'POLMSTINQ'
                       WHEN '5 '
                           MOVE 'REPORTS MENU - NOT YET IMPLEMENTED'
                               TO MNUMSGD
                           WRITE DSP-RECORD FORMAT IS 'MNUMSG'
                       WHEN '90'
                           MOVE 'N' TO WS-CONTINUE
                       WHEN OTHER
                           MOVE 'INVALID SELECTION - PLEASE TRY AGAIN'
                               TO MNUMSGD
                           WRITE DSP-RECORD FORMAT IS 'MNUMSG'
                   END-EVALUATE
               END-IF
           END-PERFORM

           CLOSE MNUDSPF
           GOBACK.
