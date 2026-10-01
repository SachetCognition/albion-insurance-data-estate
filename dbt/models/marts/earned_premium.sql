select
    policy_id,
    annual_premium_gbp,
    earned_premium_gbp,
    cast(annual_premium_gbp - earned_premium_gbp as decimal(15,2)) as unearned_premium_gbp,
    cast('{{ var("as_of_date") }}' as date) as as_of_date
from {{ ref('policy_360') }}
where status = 'ACTIVE'
