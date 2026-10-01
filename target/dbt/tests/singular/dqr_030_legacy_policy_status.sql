-- DQR-030 — Policy status domain. Flags the retired/out-of-domain P&C status
-- codes that LEGACY_PAS silently emitted and the old SQ filters dropped without
-- trace (e.g. CAR, HSE product-as-status, and 'PD' paid-up from the life legacy).
-- Complements the accepted_values(IF,RN,LP,CN,EX) test on stg_policy. Returns
-- any P&C policy row whose status is outside the canonical domain.
select
    policy_no,
    policy_status
from {{ ref('stg_plcymstr') }}
where policy_status is not null
  and policy_status not in ('IF', 'RN', 'LP', 'CN', 'EX')
