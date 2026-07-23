-- Ad-hoc DQ pack run manually before month-end by Claims MI (not scheduled).
-- Several checks re-implement registry rules with local thresholds.

-- DQR-033 equivalent (the "official" one is suspended)
SELECT COUNT(*) AS future_loss_dates
FROM CLAIMS_DB.CLAIM
WHERE CAST(SUBSTR(LOSS_DT,7,4)||'-'||SUBSTR(LOSS_DT,4,2)||'-'||SUBSTR(LOSS_DT,1,2) AS DATE)
      > CURRENT_DATE;

-- Orphan claims (policy missing) - typically bordereaux re-keying failures
SELECT c.SOURCE_SYSTEM, COUNT(*) AS orphan_claims
FROM CLAIMS_DB.CLAIM c
LEFT JOIN POLICY_ADMIN_DB.POLICY p ON p.POLICY_NO = c.POLICY_NO
WHERE p.POLICY_NO IS NULL
GROUP BY 1;

-- Fraud flag disagreement between operational store and staging
SELECT COUNT(*) AS fraud_flag_mismatches
FROM CLAIMS_DB.CLAIM c
JOIN ETL_STAGING_DB.STG_CLAIMS_SUMMARY s ON s.CLAIM_NO = c.CLAIM_NO
WHERE (c.FRAUD_FLAG = 'S' AND s.FRAUD_FLAG_NORM = 'Y')   -- BTEQ says Y
   OR (c.FRAUD_FLAG = 'N' AND s.FRAUD_FLAG_NORM = 'Y');

-- Earned premium tri-reconciliation (never ties; tolerance raised twice)
SELECT ABS(SUM(f.EARNED_PREMIUM) - SUM(f.GWP)*0.5) AS placeholder_check
FROM ETL_STAGING_DB.STG_EARNED_PREMIUM f;  -- TODO(J.Mercer 2023): finish this
