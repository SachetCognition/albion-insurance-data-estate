-- Translated from teradata/bteq/04_stg_policy_360.bteq (POLICY_ADMIN_DB.POLICY)
with source as (
    select * from {{ ref('policies') }}
)

select
    policy_no,
    party_id,
    product_cd,
    product_name,
    broker_id,
    channel,
    inception_dt,
    expiry_dt,
    policy_status,
    annual_premium_gbp,
    ipt_rate,
    payment_plan,
    uw_year,
    source_system
from source
qualify row_number() over (partition by policy_no order by inception_dt desc) = 1
