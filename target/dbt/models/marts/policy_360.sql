-- policy_360 — canonical Policy-360 mart. Replaces ETL_STAGING_DB.STG_POLICY_360
-- (teradata/bteq/04_stg_policy_360.bteq) and the earned-premium figures from
-- teradata/bteq/06_stg_earned_premium.bteq. Column set == the shared Policy
-- JSON contract served by the Policy Inquiry API (target/api).
--
-- Governed definitions (collapsing legacy drift):
--   * active_policy_flag: policy_status in ('IF','RN') — the group definition.
--     Supersedes the four legacy variants (Finance: IF + premium in 45 days;
--     Underwriting: IF/RN; Claims MI: open claim; PL/SQL: Finance passthrough).
--   * earned_premium_gbp: straight-line monthly 1/12ths — the group method.
--     Supersedes 1/24ths (Informatica) and 365ths (SAS actuarial).
--   * postcode_dq_status / email_dq_status: single implementations of DQR-014
--     and DQR-007 via macros in macros/dq_rules.sql (also enforced as dbt tests).

with policies as (
    select * from {{ ref('stg_policies') }}
),

parties as (
    select * from {{ ref('stg_parties') }}
),

brokers as (
    select * from {{ ref('stg_brokers') }}
)

select
    p.policy_no,
    p.party_id,
    pt.legacy_customer_id,
    p.product_cd,
    p.channel,
    p.inception_dt,
    p.expiry_dt,
    p.policy_status,

    case when p.policy_status in ('IF', 'RN') then 'Y' else 'N' end
        as active_policy_flag,

    p.annual_premium_gbp,

    cast(
        p.annual_premium_gbp
        * least(12, greatest(0, datediff('month', p.inception_dt, current_date)))
        / 12.0
        as decimal(12, 2)
    ) as earned_premium_gbp,

    pt.postcode,

    case when {{ dqr_014_is_valid_uk_postcode('pt.postcode') }}
         then 'VALID' else 'INVALID' end as postcode_dq_status,

    case when {{ dqr_007_is_valid_email('pt.email_addr') }}
         then 'VALID' else 'INVALID' end as email_dq_status,

    b.broker_name
from policies p
left join parties pt on pt.party_id = p.party_id
left join brokers b on b.broker_id = p.broker_id
