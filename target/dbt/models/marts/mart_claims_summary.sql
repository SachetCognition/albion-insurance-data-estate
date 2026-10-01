-- Mart: claims summary by policy + accident year.
-- Uses the canonical single-valued ACCIDENT_YEAR (UK loss-date parse) and the
-- ONE canonical fraud-flag mapping, so fraud counts no longer differ between the
-- operational and analytical stores (README finding #3; Informatica vs BTEQ 'S').
-- Replaces the ad-hoc claims aggregation in teradata/bteq/05_stg_claims_summary.bteq
-- and feeds the SIU triage previously in sas/claims_fraud/05_claims_fraud_scoring.sas
-- (which is also where the AR-118 raw-NINO join lived — closed via masked party).
with claim as (
    select * from {{ ref('dim_claim') }}
),

policy as (
    select policy_no, product_cd, uw_year from {{ ref('stg_policy') }}
)

select
    c.policy_no,
    p.product_cd,
    c.accident_year,
    count(*)                                          as claim_count,
    count_if(c.claim_status in ('OPEN', 'REOPENED'))  as open_claim_count,
    count_if(c.claim_status = 'CLOSED')               as closed_claim_count,
    count_if(c.claim_status = 'DECLINED')             as declined_claim_count,
    count_if(c.is_fraud_flagged)                      as fraud_flagged_count,
    sum(c.incurred_amt)                               as total_incurred,
    sum(c.paid_amt)                                   as total_paid,
    sum(c.outstanding_reserve)                        as total_outstanding_reserve,
    max(c.loss_dt)                                    as latest_loss_dt
from claim c
left join policy p on p.policy_no = c.policy_no
group by c.policy_no, p.product_cd, c.accident_year
