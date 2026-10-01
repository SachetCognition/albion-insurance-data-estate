with parsed as (
    select
        case when cast(left('490420', 2) as integer) <= 39
            then make_date(2000 + cast(left('490420', 2) as integer), 4, 20)
            else make_date(1900 + cast(left('490420', 2) as integer), 4, 20)
        end as dob
)
select *
from parsed
where dob <> date '1949-04-20'
