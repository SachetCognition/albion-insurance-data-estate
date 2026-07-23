# Feed FD-010 — LIFE400 Policy Master Extract (POLMSTEX)
Source: Provident Mutual LIFE400 (AS/400, ILE COBOL/DDS) · Nightly 23:30 via LIFEXTR
Consumer: DataStage `LIFE_POLICY_LOAD` → Teradata `LIFE_DB.LIFE_POLICY`

Fixed-width, no delimiter. **All dates YYMMDD (6-digit)** — truncated from the
8-digit YYYYMMDD fields in POLMST during 2016 integration (see LIFEXTR header).
Pivot year **40** (LIFE400 convention) vs 49 (Informatica) vs 50 (SAS macro).

| Pos | Len | Field | Notes |
|---|---|---|---|
| 1 | 12 | POLID | Life policy id, e.g. `PM0000123456` — **5th identifier scheme** in the group |
| 13 | 12 | APPID | |
| 25 | 6 | PRCDATE | YYMMDD |
| 31 | 5 | PLANCD | TL10/TL20/WL01... |
| 36 | 2 | CNTRSTS | PE/AC/GR/LA/RS/CL/TE/RJ (does not align to P&C status domain) |
| 38 | 40 | INSNAME | Single field; no forename/surname split, no party key |
| 78 | 6 | INSDOB | YYMMDD — pivot 40: `390101`→2039?! known ambiguity, unresolved |
| 84 | 1 | GENDER | |
| 85 | 13.2 | SUMASSURED | implied 2dp |
| 100 | 13.2 | MODALPREM | implied 2dp |
| 115 | 2 | PAYFREQ | 01/04/12 payments p.a. |

No customer/party identifier exists on this feed. Life policyholders are matched
to group PARTY records by **name + DOB fuzzy match** inside the DataStage job
(match rate unknown; no suspect queue).
