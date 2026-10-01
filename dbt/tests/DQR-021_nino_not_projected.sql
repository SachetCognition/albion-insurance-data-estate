with policy_projection as (
    select count(*) as rows_present from {{ ref('policy_360') }}
),
claim_projection as (
    select count(*) as rows_present from {{ ref('claims_summary') }}
)
select c.*
from information_schema.columns c
cross join policy_projection
cross join claim_projection
where c.table_schema = 'main'
  and c.table_name in ('policy_360', 'claims_summary')
  and lower(c.column_name) in ('nino', 'nino_hash')
