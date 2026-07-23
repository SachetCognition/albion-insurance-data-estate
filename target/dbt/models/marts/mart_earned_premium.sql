-- Mart: earned premium by policy.
-- Computes ONE canonical earned premium — the actuarial 365ths daily pro-rata,
-- authoritative per glossary/actuarial_definitions.md — replacing the THREE
-- drifting implementations:
--   * teradata/bteq/06_stg_earned_premium.bteq        (monthly 1/12ths, Finance)
--   * informatica wf_BILLING_PREMIUM_RECON EXP_EARNED_24THS (1/24ths)
--   * sas/actuarial/06_reserving_triangles.sas         (365ths, authoritative)
-- The 1/12ths and 1/24ths figures are retained as clearly-LABELLED variant
-- columns for reconciliation only (they differ by up to ~1.8% at year end).
-- IPT uses POLICY.IPT_RATE (not the hardcoded 0.12). Ceded premium uses the
-- quota-share treaty. SII LoB from the single canonical seed.
with policy as (
    select * from {{ ref('stg_policy') }}
),

treaty as (
    select product_cd, uw_year, cession_pct
    from (
        select
            line_of_business as product_cd,
            uw_year,
            cession_pct,
            row_number() over (
                partition by line_of_business, uw_year order by cession_pct desc
            ) as rn
        from {{ ref('stg_treaty') }}
        where treaty_type = 'QUOTA_SHARE'
    )
    where rn = 1
),

lob as (
    select * from {{ ref('sii_lob_map') }}
),

base as (
    select
        p.policy_no,
        p.uw_year,
        p.product_cd,
        m.sii_line_of_business,
        p.inception_dt,
        p.annual_premium_gbp                          as gwp,
        round(p.annual_premium_gbp * coalesce(p.ipt_rate, 0), 2) as ipt_amt,
        greatest(0, datediff('day', p.inception_dt, current_date())) as days_on_risk_raw,
        datediff('month', p.inception_dt, current_date()) as months_on_risk,
        t.cession_pct
    from policy p
    left join treaty t on t.product_cd = p.product_cd and t.uw_year = p.uw_year
    left join lob m on upper(m.product_cd) = p.product_cd
    where p.policy_status in ('IF', 'RN')
)

select
    policy_no,
    uw_year,
    product_cd,
    sii_line_of_business,
    inception_dt,
    gwp,
    ipt_amt,
    -- CANONICAL: 365ths daily pro-rata (actuarial, authoritative).
    round(gwp * least(365, days_on_risk_raw) / 365.0, 2)          as earned_premium,
    -- Variant (Finance 1/12ths) — reconciliation only.
    round(gwp * least(12, greatest(0, days_on_risk_raw / 30)) / 12.0, 2) as earned_premium_1_12,
    -- Variant (Informatica 1/24ths) — reconciliation only.
    round(gwp * least(24, greatest(0, months_on_risk * 2 + 1)) / 24.0, 2) as earned_premium_1_24,
    round(gwp - (gwp * least(365, days_on_risk_raw) / 365.0), 2)  as unearned_premium,
    round(gwp * coalesce(cession_pct, 0) / 100.0, 2)              as ceded_premium,
    current_date()                                               as as_at_dt
from base
