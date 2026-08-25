{{ config(materialized='table') }}

-- Port of the ultimates/exposure step of
-- sas/actuarial/06_reserving_triangles.sas (ACTUARIAL_DB.RESERVE_ULTIMATES).
--
-- EARNED PREMIUM: the SAS program hard-codes the actuarial 365ths daily
-- pro-rata convention (`EARNED_PREMIUM_365 = ANNUAL_PREMIUM_GBP * days / 365`).
-- This model therefore calls the canonical shared macro with the explicitly
-- LABELLED non-default variant `method='day_365ths'` instead of re-implementing
-- the arithmetic. Finance (BTEQ 06) uses the canonical 'twelfths' and the
-- Informatica recon uses 'twenty_fourths'; the three figures differ by design
-- and the column name carries the convention.

{% set as_at_date = var('reserving_as_at_date', '2026-06-30') %}

with exposure as (

    select
        product_cd,
        cast(extract(year from inception_dt) as integer) as accident_year,
        count(*) as policy_count,
        cast(sum(annual_premium_gbp) as decimal(18, 2)) as written_premium_gbp,
        cast(
            sum(
                {{ earned_premium(
                    'annual_premium_gbp',
                    'inception_dt',
                    "date '" ~ as_at_date ~ "'",
                    method='day_365ths'
                ) }}
            ) as decimal(18, 2)
        ) as earned_premium_365ths_gbp
    from {{ ref('raw_policies') }}
    where inception_dt <= date '{{ as_at_date }}'
    group by product_cd, cast(extract(year from inception_dt) as integer)

),

latest_diagonal as (

    select
        product_cd,
        accident_year,
        max(dev_year) as latest_dev_year
    from {{ ref('sas_reserving_triangles') }}
    group by product_cd, accident_year

),

latest_cumulative as (

    select
        t.product_cd,
        t.accident_year,
        t.dev_year as latest_dev_year,
        t.incurred_cumulative as incurred_to_date
    from {{ ref('sas_reserving_triangles') }} as t
    inner join latest_diagonal as d
        on
            t.product_cd = d.product_cd
            and t.accident_year = d.accident_year
            and t.dev_year = d.latest_dev_year

),

-- Cumulative development factor to ultimate = product of the LDFs from this
-- development period onwards, computed as exp(sum(ln(ldf))).
cdf as (

    select
        product_cd,
        dev_year,
        exp(
            sum(ln(ldf)) over (
                partition by product_cd
                order by dev_year desc
                rows between unbounded preceding and current row
            )
        ) as cdf_to_ultimate
    from {{ ref('sas_reserving_ldf') }}
    where ldf > 0

)

select
    c.product_cd,
    c.accident_year,
    c.latest_dev_year,
    c.incurred_to_date,
    cast(coalesce(f.cdf_to_ultimate, 1) as decimal(12, 6)) as cdf_to_ultimate,
    cast(c.incurred_to_date * coalesce(f.cdf_to_ultimate, 1) as decimal(18, 2))
        as ultimate_incurred,
    cast(
        c.incurred_to_date * coalesce(f.cdf_to_ultimate, 1) - c.incurred_to_date
        as decimal(18, 2)
    ) as ibnr,
    e.policy_count,
    e.written_premium_gbp,
    e.earned_premium_365ths_gbp,
    case
        when e.earned_premium_365ths_gbp > 0
            then cast(
                c.incurred_to_date
                * coalesce(f.cdf_to_ultimate, 1)
                / e.earned_premium_365ths_gbp as decimal(12, 6)
            )
    end as ultimate_loss_ratio,
    date '{{ as_at_date }}' as as_at_date
from latest_cumulative as c
left join cdf as f
    on
        c.product_cd = f.product_cd
        and c.latest_dev_year = f.dev_year
left join exposure as e
    on
        c.product_cd = e.product_cd
        and c.accident_year = e.accident_year
