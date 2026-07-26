with policy as (
    select
        count(*) filter (where status = 'ACTIVE') as active_policy_count,
        sum(earned_premium_gbp) as total_earned_premium_gbp
    from {{ ref('policy_360') }}
),
claim as (
    select
        count(*) filter (where status = 'OPEN') as open_claims_count,
        sum(incurred_gbp) as total_incurred_gbp
    from {{ ref('claims_summary') }}
)
select
    cast('{{ var("as_of_date") }}' as date) as as_of_date,
    active_policy_count,
    cast(total_earned_premium_gbp as decimal(15,2)) as total_earned_premium_gbp,
    open_claims_count,
    cast(total_incurred_gbp as decimal(15,2)) as total_incurred_gbp
from policy cross join claim
