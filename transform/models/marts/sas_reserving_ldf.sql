{{ config(materialized='table') }}

-- Port of the volume-weighted chain-ladder step in
-- sas/actuarial/06_reserving_triangles.sas (ACTUARIAL_DB.RESERVE_LDF).
--
--     LDF(product, dev) = sum(cumulative at dev + 1) / sum(cumulative at dev)
--
-- restricted to accident years observable at both development periods, which is
-- the standard volume-weighted average the SAS self-join intended to compute.

with tri as (

    select * from {{ ref('sas_reserving_triangles') }}

),

pairs as (

    select
        curr.product_cd,
        curr.dev_year,
        count(*) as accident_years_used,
        sum(curr.incurred_cumulative) as cumulative_at_dev,
        sum(nxt.incurred_cumulative) as cumulative_at_next_dev
    from tri as curr
    inner join tri as nxt
        on
            curr.product_cd = nxt.product_cd
            and curr.accident_year = nxt.accident_year
            and nxt.dev_year = curr.dev_year + 1
    group by curr.product_cd, curr.dev_year

)

select
    product_cd,
    dev_year,
    accident_years_used,
    cumulative_at_dev,
    cumulative_at_next_dev,
    case
        when cumulative_at_dev > 0
            then cast(cumulative_at_next_dev / cumulative_at_dev as decimal(12, 6))
        else cast(1 as decimal(12, 6))
    end as ldf
from pairs
