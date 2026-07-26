select *
from {{ ref('stg_policies') }}
where status not in ('ACTIVE', 'LAPSED', 'CANCELLED', 'EXPIRED')
