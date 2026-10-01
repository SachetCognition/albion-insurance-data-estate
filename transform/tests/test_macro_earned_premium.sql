-- Unit test: canonical earned_premium macro — all three methods.
-- Canonical 'twelfths' replicates BTEQ 06_stg_earned_premium arithmetic.
with cases as (
    select
        cast('2024-01-01' as date) as inception_dt,
        cast('2025-01-01' as date) as as_at_dt
)

select *
from cases
where
    {{ earned_premium('1200', 'inception_dt', 'as_at_dt') }} <> 1200.00
    or {{ earned_premium('1200', 'inception_dt', "cast('2024-07-01' as date)") }} <> 600.00
    or {{ earned_premium('1200', 'inception_dt', "cast('2024-01-15' as date)") }} <> 0.00
    or {{ earned_premium('365', 'inception_dt', "cast('2024-01-11' as date)", method='day_365ths') }} <> 10.00
    or {{ earned_premium('2400', 'inception_dt', "cast('2024-01-15' as date)", method='twenty_fourths') }} <> 100.00
    or {{ unearned_premium('1200', 'inception_dt', "cast('2024-07-01' as date)") }} <> 600.00
