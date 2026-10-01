-- DQR-033 — Loss date not in future (LOSS_DT <= run date).
-- Singular test. Re-instates the rule that was COMMENTED OUT in
-- teradata/bteq/05_stg_claims_summary.bteq in 2022 (after MOT telematics false
-- positives) and left with no active implementation. Returns claims that FAIL.
select
    claim_no,
    loss_dt
from {{ ref('dim_claim') }}
where loss_dt is not null
  and loss_dt > current_date()
