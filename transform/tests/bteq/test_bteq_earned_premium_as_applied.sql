{% set as_at = "cast('" ~ var('bteq_policy_as_at_dt', '2026-12-31') ~ "' as date)" %}
-- Unit test: canonical earned_premium / unearned_premium AS APPLIED in the
-- BTEQ ports.
-- 1. fixed 1/12ths expectations, including the GREATEST(0, ...) floor the raw
--    BTEQ arithmetic lacked (a not-yet-incepted policy earns 0, never a
--    negative amount);
-- 2. stg_earned_premium and stg_policy_360 agree with the macro row by row,
--    and earned + unearned tie out to GWP exactly.
with cases as (
    select * from (
        values
        (1200.00, cast('2025-01-01' as date), cast('2026-12-31' as date), 1200.00),
        (1200.00, cast('2026-07-01' as date), cast('2026-12-31' as date), 600.00),
        (1200.00, cast('2026-12-20' as date), cast('2026-12-31' as date), 0.00),
        (1200.00, cast('2027-06-01' as date), cast('2026-12-31' as date), 0.00)
    ) as t (annual_premium, inception_dt, as_at_dt, expected_earned)
),

case_failures as (
    select cast(inception_dt as varchar) as failing_key
    from cases
    where
        {{ earned_premium('annual_premium', 'inception_dt', 'as_at_dt') }}
        <> expected_earned
        or {{ unearned_premium('annual_premium', 'inception_dt', 'as_at_dt') }}
        <> annual_premium - expected_earned
),

earned_model_failures as (
    select ep.policy_no as failing_key
    from {{ ref('stg_earned_premium') }} as ep
    inner join {{ ref('raw_policies') }} as p
        on ep.policy_no = p.policy_no
    where
        ep.earned_premium
        <> {{ earned_premium(
            'cast(p.annual_premium_gbp as decimal(12, 2))', 'p.inception_dt', as_at
        ) }}
        or ep.earned_premium + ep.unearned_premium <> ep.gwp
),

policy_model_failures as (
    select pol.policy_no as failing_key
    from {{ ref('stg_policy_360') }} as pol
    inner join {{ ref('raw_policies') }} as p
        on pol.policy_no = p.policy_no
    where
        pol.earned_premium_mth
        <> {{ earned_premium(
            'cast(p.annual_premium_gbp as decimal(12, 2))', 'p.inception_dt', as_at
        ) }}
)

select failing_key from case_failures
union all
select failing_key from earned_model_failures
union all
select failing_key from policy_model_failures
