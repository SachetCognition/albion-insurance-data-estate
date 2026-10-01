-- Broker bordereaux keys such as AL/PET-0001559 must land as the canonical ALB-PET-0001559,
-- so no claim references a policy that does not exist.
select c.claim_id, c.policy_id
from {{ ref('claims_summary') }} c
left join {{ ref('policy_360') }} p on p.policy_id = c.policy_id
where p.policy_id is null
