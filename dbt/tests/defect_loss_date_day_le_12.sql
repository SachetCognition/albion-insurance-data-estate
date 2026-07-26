with sample as (
    select try_strptime('09/05/2021', '%d/%m/%Y')::date as loss_date
)
select *
from sample
where loss_date <> date '2021-05-09'
