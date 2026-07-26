with base as (
    select * from {{ ref('stg_policies') }}
),
earned as (
    select
        *,
        greatest(0, date_diff('day', inception_date, cast('{{ var("as_of_date") }}' as date))) as elapsed_days,
        greatest(1, coalesce(date_diff('day', inception_date, expiry_date), 365)) as term_days
    from base
)
select
    policy_id,
    legacy_policy_no,
    party_id,
    product_code,
    inception_date,
    expiry_date,
    status,
    cast(annual_premium_gbp as decimal(15,2)) as annual_premium_gbp,
    cast(
        annual_premium_gbp
        * least(elapsed_days, term_days)
        / term_days
        as decimal(15,2)
    ) as earned_premium_gbp,
    postcode,
    postcode_dq_status,
    broker_id,
    source_system
from earned
