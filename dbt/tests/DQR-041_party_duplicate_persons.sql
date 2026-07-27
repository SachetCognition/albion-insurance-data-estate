{{ config(severity='warn', error_if='> 0') }}

with natural_keys as (
    select
        upper(trim(first_name)) as first_name,
        upper(trim(last_name)) as last_name,
        birth_dt,
        count(*) as records
    from {{ ref('stg_parties') }}
    group by 1, 2, 3
)
select *
from natural_keys
where records > 1
