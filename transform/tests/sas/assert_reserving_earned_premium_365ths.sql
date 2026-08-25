-- Guards the labelled non-default earned-premium convention: the actuarial
-- ultimates must equal the canonical shared macro called with
-- method='day_365ths' (never a locally re-implemented formula), and the book
-- total on that convention must differ from the canonical 'twelfths' Finance
-- figure — proving the labelled variant is actually in force rather than
-- silently falling back to the default.

{% set as_at_date = var('reserving_as_at_date', '2026-06-30') %}

with expected as (

    select
        product_cd,
        cast(extract(year from inception_dt) as integer) as accident_year,
        cast(
            sum(
                {{ earned_premium(
                    'annual_premium_gbp',
                    'inception_dt',
                    "date '" ~ as_at_date ~ "'",
                    method='day_365ths'
                ) }}
            ) as decimal(18, 2)
        ) as earned_365ths,
        cast(
            sum(
                {{ earned_premium(
                    'annual_premium_gbp',
                    'inception_dt',
                    "date '" ~ as_at_date ~ "'"
                ) }}
            ) as decimal(18, 2)
        ) as earned_twelfths
    from {{ ref('raw_policies') }}
    where inception_dt <= date '{{ as_at_date }}'
    group by product_cd, cast(extract(year from inception_dt) as integer)

),

per_group_breach as (

    select
        u.product_cd,
        u.accident_year,
        'ultimates_earned_premium_not_from_day_365ths_macro' as failure
    from {{ ref('sas_reserving_ultimates') }} as u
    inner join expected as e
        on
            u.product_cd = e.product_cd
            and u.accident_year = e.accident_year
    where abs(u.earned_premium_365ths_gbp - e.earned_365ths) > 0.01

),

convention_breach as (

    select
        cast(null as varchar) as product_cd,
        cast(null as integer) as accident_year,
        'day_365ths_total_matches_twelfths_convention' as failure
    from expected
    having abs(sum(earned_365ths) - sum(earned_twelfths)) <= 0.01

)

select * from per_group_breach
union all
select * from convention_breach
