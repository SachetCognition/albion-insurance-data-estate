-- Validation approach for the reserving triangle: no GOLDEN baseline seed
-- exists for the actuarial data products, so the port is validated against
-- actuarial/structural invariants instead of golden_parity.
--
--   1. cumulative incurred is non-decreasing across development periods;
--   2. the triangle total equals the source total of non-declined claims
--      incurred up to the as-at date (reconciliation to raw_claims);
--   3. no cell sits beyond the latest observable diagonal.

{% set as_at_date = var('reserving_as_at_date', '2026-06-30') %}

with monotonic_breach as (

    select
        product_cd,
        accident_year,
        dev_year,
        'cumulative_decreased' as failure
    from (
        select
            product_cd,
            accident_year,
            dev_year,
            incurred_cumulative,
            lag(incurred_cumulative) over (
                partition by product_cd, accident_year order by dev_year
            ) as prev_cumulative
        from {{ ref('sas_reserving_triangles') }}
    ) as t
    where prev_cumulative is not null and incurred_cumulative < prev_cumulative

),

future_cells as (

    select
        product_cd,
        accident_year,
        dev_year,
        'cell_beyond_latest_diagonal' as failure
    from {{ ref('sas_reserving_triangles') }}
    where dev_year > legacy_dev_year_as_at

),

source_total as (

    select cast(sum(incurred_amt) as decimal(18, 2)) as total_incurred
    from {{ ref('raw_claims') }}
    where
        claim_status != 'DECLINED'
        and {% if target.type == 'snowflake' -%}
            to_date(loss_dt, 'DD/MM/YYYY')
        {%- else -%}
            cast(strptime(loss_dt, '%d/%m/%Y') as date)
        {%- endif %} <= date '{{ as_at_date }}'

),

triangle_total as (

    select cast(sum(incurred_incremental) as decimal(18, 2)) as total_incurred
    from {{ ref('sas_reserving_triangles') }}

),

reconciliation_breach as (

    select
        cast(null as varchar) as product_cd,
        cast(null as integer) as accident_year,
        cast(null as integer) as dev_year,
        'triangle_total_does_not_reconcile_to_raw_claims' as failure
    from triangle_total as t
    cross join source_total as s
    where abs(t.total_incurred - s.total_incurred) > 0.01

)

select * from monotonic_breach
union all
select * from future_cells
union all
select * from reconciliation_breach
