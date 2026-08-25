-- Unit test: DQR-052 canonical julian_to_date (single group pivot = 50).
-- Fails if any known YYDDD input does not convert to the expected date.
with cases as (
    select
        '25100' as yyddd,
        cast('2025-04-10' as date) as expected
    union all
    select
        '75100' as yyddd,
        cast('1975-04-10' as date) as expected
    union all
    select
        '50001' as yyddd,
        cast('2050-01-01' as date) as expected
    union all
    select
        '51001' as yyddd,
        cast('1951-01-01' as date) as expected
    union all
    select
        '00366' as yyddd,
        cast('2000-12-31' as date) as expected
)

select
    yyddd,
    expected,
    {{ julian_to_date('yyddd') }} as actual
from cases
where {{ julian_to_date('yyddd') }} <> expected
