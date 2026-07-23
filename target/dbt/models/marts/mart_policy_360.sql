-- Mart: policy-360. Denormalised policy + canonical party + broker + premium
-- aggregates + the four explicit active-policy variant flags and the single
-- canonical ACTIVE_POLICY_FLAG. Replaces the drifted ETL_STAGING_DB.STG_POLICY_360
-- (teradata/bteq/04_stg_policy_360.bteq), which baked in only the Finance
-- "active" definition and a local postcode/email DQ variant.
-- This is the store the modern API reads from (fresh, not the 26h-stale ODS).
with policy as (
    select * from {{ ref('dim_policy') }}
),

party as (
    select * from {{ ref('dim_party') }}
),

broker as (
    select * from {{ ref('stg_broker') }}
),

collections as (
    select
        policy_no,
        sum(gross_amt_gbp)  as total_collected_gbp,
        max(txn_dt)         as last_collection_dt,
        count(*)            as txn_count
    from {{ ref('stg_premium_transactions') }}
    where txn_type <> 'CN_REFUND'
    group by policy_no
),

earned as (
    select policy_no, earned_premium, earned_premium_1_12, earned_premium_1_24
    from {{ ref('mart_earned_premium') }}
)

select
    p.policy_no,
    p.policy_domain,
    p.party_key,
    p.polaris_party_id,
    pty.legacy_client_no,
    pty.apf_customer_id,
    pty.life_policy_id,
    pty.first_name,
    pty.last_name,
    pty.email,
    pty.postcode,
    pty.nino_masked,
    p.product_cd,
    p.product_name,
    p.broker_id,
    b.broker_name,
    b.commission_pct,
    p.channel,
    p.inception_dt,
    p.expiry_dt,
    p.policy_status,
    p.annual_premium_gbp,
    p.ipt_rate,
    p.payment_plan,
    p.uw_year,
    p.source_system,
    -- explicit, labelled active variants + single canonical flag
    p.active_uw,
    p.active_finance,
    p.active_claims,
    p.active_life,
    p.active_policy_flag,
    coalesce(c.total_collected_gbp, 0) as total_collected_gbp,
    c.last_collection_dt,
    coalesce(c.txn_count, 0)           as premium_txn_count,
    e.earned_premium,
    e.earned_premium_1_12,
    e.earned_premium_1_24
from policy p
left join party pty on pty.party_key = p.party_key
left join broker b on b.broker_id = p.broker_id
left join collections c on c.policy_no = p.policy_no
left join earned e on e.policy_no = p.policy_no
