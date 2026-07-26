select *
from {{ ref('stg_policies') }}
where (postcode_dq_status = 'VALID'
       and (postcode is null or not regexp_matches(postcode, '^[A-Z]{1,2}[0-9][A-Z0-9]? [0-9][A-Z]{2}$')))
   or (postcode_dq_status = 'MISSING' and postcode is not null)
