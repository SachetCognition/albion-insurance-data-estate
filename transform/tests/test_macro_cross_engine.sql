-- Unit test: cross-engine helpers render equivalent semantics on both
-- duckdb (local/CI) and snowflake (live) targets.
with cases as (
    select
        cast('2024-01-01' as date) as d1,
        cast('2025-01-01' as date) as d2
)

select *
from cases
where
    -- full-match semantics: partial matches must NOT pass
    not {{ regexp_full_match("'ABC'", '[A-Z]{3}') }}
    or {{ regexp_full_match("'ABCD'", '[A-Z]{3}') }}
    or {{ regexp_full_match("'abc'", '[A-Z]{3}') }}
    -- day arithmetic: 2024 is a leap year, so a full year spans 366 days
    or {{ days_between('d1', 'd2') }} <> 366
    or {{ days_between('d2', 'd1') }} <> -366
    or {{ days_between('d1', 'd1') }} <> 0
