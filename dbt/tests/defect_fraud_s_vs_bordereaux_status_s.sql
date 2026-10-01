with mapped as (
    select
        case 'S' when 'S' then 'SUSPECTED' else 'N' end as fraud_s,
        case 'S' when 'S' then 'CLOSED' else 'OPEN' end as status_s
)
select *
from mapped
where fraud_s <> 'SUSPECTED'
   or status_s <> 'CLOSED'
