select c.*
from {{ ref('stg_claims') }} c
left join {{ ref('policy_360') }} p using (policy_id)
where p.policy_id is null
