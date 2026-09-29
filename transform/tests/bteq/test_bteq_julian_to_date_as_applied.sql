-- Unit test: DQR-052 julian_to_date AS APPLIED in stg_policy_360.
-- 1. pivot-50 boundary cases (00-50 -> 20xx, 51-99 -> 19xx) — 50365 is the
--    row that moves from 1950 (Informatica pivot 49 / LIFE400 pivot 40) to
--    2050 under the canonical pivot;
-- 2. inception_dt_dqr052 round-trips every model row's inception date, proving
--    no baseline date shifts for the current data (all years 1951..2050).
with cases as (
    select * from (
        values
        ('18213', cast('2018-08-01' as date)),
        ('26001', cast('2026-01-01' as date)),
        ('50365', cast('2050-12-31' as date)),
        ('51001', cast('1951-01-01' as date)),
        ('99365', cast('1999-12-31' as date))
    ) as t (yyddd, expected_dt)
),

case_failures as (
    select yyddd as failing_key
    from cases
    where {{ julian_to_date('yyddd') }} <> expected_dt
),

model_failures as (
    select policy_no as failing_key
    from {{ ref('stg_policy_360') }}
    where inception_dt_dqr052 <> inception_dt
)

select failing_key from case_failures
union all
select failing_key from model_failures
