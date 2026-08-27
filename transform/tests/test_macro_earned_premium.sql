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
    -- as-at before inception clamps to zero earned / fully unearned
    or {{ earned_premium('1200', 'inception_dt', "cast('2023-06-01' as date)") }} <> 0.00
    or {{ unearned_premium('1200', 'inception_dt', "cast('2023-06-01' as date)") }} <> 1200.00
    -- beyond one policy year clamps to fully earned in every method
    or {{ earned_premium('1200', 'inception_dt', "cast('2026-06-01' as date)") }} <> 1200.00
    or {{ earned_premium('365', 'inception_dt', "cast('2026-06-01' as date)", method='day_365ths') }} <> 365.00
    or {{ earned_premium('2400', 'inception_dt', "cast('2026-06-01' as date)", method='twenty_fourths') }} <> 2400.00
    -- earned + unearned must always tie back to the annual premium
    or {{ earned_premium('999.99', 'inception_dt', 'as_at_dt') }}
    + {{ unearned_premium('999.99', 'inception_dt', 'as_at_dt') }} <> 999.99
    -- 1/24ths mid-month assumption: day 0 already earns half a month
    or {{ earned_premium('2400', 'inception_dt', 'inception_dt', method='twenty_fourths') }} <> 100.00
    -- null premium propagates null rather than erroring
    or {{ earned_premium('cast(null as decimal(12,2))', 'inception_dt', 'as_at_dt') }} is not null
