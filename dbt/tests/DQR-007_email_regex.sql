with parties as (
    select * from {{ ref('stg_parties') }}
)
select *
from parties
where EMAIL_ADDR is not null
  and not regexp_matches(lower(EMAIL_ADDR), '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
