-- Domain: canonical CLAIM dimension.
-- LOSS_DT resolved once with the UK DD/MM/YYYY interpretation in staging, so
-- ACCIDENT_YEAR here is single-valued (replaces the ~40% disagreement between
-- the Informatica MM/DD/YYYY path, INC0067812, and the BTEQ DD/MM/YYYY path).
-- FRAUD_FLAG uses the ONE canonical 'S'->'Y' mapping from staging.
-- CLAIMANT_PARTY_ID is linked to the canonical party surrogate key.
with claim as (
    select * from {{ ref('stg_claim') }}
),

party as (
    select party_key, polaris_party_id from {{ ref('dim_party') }}
    where polaris_party_id is not null
)

select
    c.claim_no,
    c.policy_no,
    c.claimant_party_id,
    p.party_key                                       as claimant_party_key,
    c.loss_dt,
    c.notification_dt,
    year(c.loss_dt)                                   as accident_year,
    c.cause_cd,
    c.claim_status,
    c.incurred_amt,
    c.paid_amt,
    c.outstanding_reserve,
    c.fraud_flag,
    c.fraud_flag_raw,
    (c.fraud_flag = 'Y')                              as is_fraud_flagged,
    c.handler_id,
    c.source_system
from claim c
left join party p on p.polaris_party_id = c.claimant_party_id
