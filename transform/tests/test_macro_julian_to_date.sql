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
    union all
    select
        -- short numeric input is left-padded to 5 chars: 5100 -> 05100
        '5100' as yyddd,
        cast('2005-04-10' as date) as expected
    union all
    select
        '99365' as yyddd,
        cast('1999-12-31' as date) as expected
    union all
    select
        '24001' as yyddd,
        cast('2024-01-01' as date) as expected
)

select
    yyddd,
    expected,
    {{ julian_to_date('yyddd') }} as actual
from cases
where {{ julian_to_date('yyddd') }} <> expected
-- null input must yield null, not an error or epoch date
or {{ julian_to_date('cast(null as varchar)') }} is not null
-- non-default pivot honoured: 45xxx is 1945 under the legacy LIFE400 pivot 40
or {{ julian_to_date("'45001'", pivot=40) }} <> cast('1945-01-01' as date)
or {{ julian_to_date("'45001'") }} <> cast('2045-01-01' as date)
