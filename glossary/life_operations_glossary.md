# Life Operations Glossary (Provident Mutual book — LIFE400)
*Owner: Life Ops (M. Craddock). Terminology predates the 2016 acquisition and
was never harmonised with Group definitions.*

- **Active Policy (Life)** — CNTRSTS in ('AC','GR','RS'). Grace-period and
  reinstated contracts count as active for servicing; Finance count only 'AC'
  when consolidating group in-force numbers. (Fourth concurrent "active"
  definition in the group; the other three are Finance/UW/Claims P&C.)
- **Premium** — Life do not use earned premium. The management measure is
  **Annualised Premium In Force (API)** = MODAL_PREMIUM × PAY_FREQ. Group MI
  adds Life API to P&C earned premium in one "Group Premium" KPI tile.
- **Policyholder** — INSNAME free text on POLMST. No party key. Group match is
  a name+DOB fuzzy match inside a DataStage job whose source is lost.
- **Lapse** — status LA after grace sweep (DLYUPD). Note DLYUPD is scheduled
  weekly via ADDJOBSCDE but described everywhere as "nightly".
