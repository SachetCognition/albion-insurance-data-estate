{{ config(materialized='table') }}

-- Port of sas/actuarial/06_reserving_triangles.sas (triangle build step).
--
-- Legacy: reads the SEPARATE actuarial mainframe copy (ALB.ACT.PLCYMSTR.COPY,
-- CR-2014-311) plus CLAIMS_DB.CLAIM, and buckets incurred amounts by
-- PRODUCT_CD x ACCIDENT_YEAR x DEV_YEAR.
--
-- Two deliberate changes, both documented in _sas_marts.yml:
--   1. DEV_YEAR is derived from the claim notification year, not from
--      intck('year', LOSS_DATE, today()) as the SAS code does. The legacy
--      expression collapses every accident year onto a single development
--      period, which makes the downstream chain-ladder self-join return zero
--      rows. `legacy_dev_year_as_at` preserves the legacy value for audit.
--   2. The as-at date is the `reserving_as_at_date` var (default 2026-06-30)
--      instead of today(), so the triangle is reproducible on both engines.

{% set as_at_date = var('reserving_as_at_date', '2026-06-30') %}

with claims as (

    select
        claim_no,
        substr(policy_no, 5, 3) as product_cd,
        {% if target.type == 'snowflake' -%}
            to_date(loss_dt, 'DD/MM/YYYY') as loss_date,
        {%- else -%}
            cast(strptime(loss_dt, '%d/%m/%Y') as date) as loss_date,
        {%- endif %}
        cast(notification_dt as date) as notification_date,
        incurred_amt
    from {{ ref('raw_claims') }}
    where claim_status != 'DECLINED'

),

observed as (

    select
        product_cd,
        cast(extract(year from loss_date) as integer) as accident_year,
        cast(
            extract(year from notification_date) - extract(year from loss_date) as integer
        ) as dev_year,
        incurred_amt
    from claims
    where loss_date <= date '{{ as_at_date }}'

),

incremental as (

    select
        product_cd,
        accident_year,
        dev_year,
        cast(sum(incurred_amt) as decimal(18, 2)) as incurred_incremental,
        count(*) as claim_count
    from observed
    group by product_cd, accident_year, dev_year

),

origin_periods as (

    select distinct
        product_cd,
        accident_year
    from incremental

),

-- Development spine taken from the observed lags (0..n). Avoids engine-specific
-- generate_series / row-generator syntax.
dev_spine as (

    select distinct dev_year
    from incremental

),

rectangle as (

    select
        o.product_cd,
        o.accident_year,
        s.dev_year
    from origin_periods as o
    cross join dev_spine as s
    -- only cells at or above the latest diagonal are observable as at the run date
    where s.dev_year <= cast(extract(year from date '{{ as_at_date }}') as integer) - o.accident_year

),

filled as (

    select
        r.product_cd,
        r.accident_year,
        r.dev_year,
        coalesce(i.incurred_incremental, 0) as incurred_incremental,
        coalesce(i.claim_count, 0) as claim_count
    from rectangle as r
    left join incremental as i
        on
            r.product_cd = i.product_cd
            and r.accident_year = i.accident_year
            and r.dev_year = i.dev_year

)

select
    product_cd,
    accident_year,
    dev_year,
    -- legacy SAS value: intck('year', LOSS_DATE, today()) -- kept for audit only
    cast(extract(year from date '{{ as_at_date }}') as integer) - accident_year
        as legacy_dev_year_as_at,
    incurred_incremental,
    claim_count,
    cast(
        sum(incurred_incremental) over (
            partition by product_cd, accident_year
            order by dev_year
            rows between unbounded preceding and current row
        ) as decimal(18, 2)
    ) as incurred_cumulative,
    date '{{ as_at_date }}' as as_at_date
from filled
