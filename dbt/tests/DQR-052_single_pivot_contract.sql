select *
from {{ ref('policy_360') }}
where inception_date is null
   or inception_date < date '1900-01-01'
