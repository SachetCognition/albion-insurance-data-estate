-- LIFE_DB: landing for FD-010 (LIFE400 POLMSTEX via DataStage LIFE_POLICY_LOAD)
-- NOTE dates land as INTEGER YYMMDD exactly as received; the "century fix"
-- view V_LIFE_POLICY applies pivot 40 (differs from every other pivot in use).
CREATE TABLE LIFE_DB.LIFE_POLICY (
    LIFE_POLICY_ID   CHAR(12)  NOT NULL,   -- 'PM' prefixed; no FK anywhere
    APPLICATION_ID   CHAR(12),
    PROCESS_DT_YYMMDD INTEGER,
    PLAN_CD          CHAR(5),
    CONTRACT_STATUS  CHAR(2),              -- PE/AC/GR/LA/RS/CL/TE/RJ
    INSURED_NAME     VARCHAR(40),          -- no party key; fuzzy-matched downstream
    INSURED_DOB_YYMMDD INTEGER,
    GENDER           CHAR(1),
    SUM_ASSURED      DECIMAL(15,2),
    MODAL_PREMIUM    DECIMAL(15,2),
    PAY_FREQ         BYTEINT,              -- payments per annum
    MATCHED_PARTY_ID CHAR(10),             -- populated by name+DOB fuzzy match, ~unknown precision
    LOAD_TS          TIMESTAMP(0)
) PRIMARY INDEX (LIFE_POLICY_ID);

REPLACE VIEW LIFE_DB.V_LIFE_POLICY AS
SELECT L.*,
  CASE WHEN INSURED_DOB_YYMMDD / 10000 >= 40           -- pivot 40 (!!)
       THEN 19000000 + INSURED_DOB_YYMMDD
       ELSE 20000000 + INSURED_DOB_YYMMDD END AS INSURED_DOB_CCYYMMDD,
  MODAL_PREMIUM * PAY_FREQ AS ANNUALISED_PREMIUM_IN_FORCE   -- Life's "premium" (4th earned-premium-adjacent measure)
FROM LIFE_DB.LIFE_POLICY L;
