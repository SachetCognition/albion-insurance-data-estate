{#-
  Port of teradata/bteq/06_stg_earned_premium.bteq — monthly earned / unearned
  premium by policy for the Finance close, with the quota-share reinsurance
  cession retained (raw_reinsurance_treaties seed, legacy REINSURANCE_DB.TREATY).

  Converged rules:
    * earned / unearned premium come from the canonical earned_premium() /
      unearned_premium() macros with the default 'twelfths' method, i.e. the
      Finance straight-line 1/12ths figure the BTEQ produced. The actuarial
      365ths (SAS 06_reserving_triangles) and billing 1/24ths (Informatica
      wf_BILLING_PREMIUM_RECON) variants stay behind the macro's `method`
      argument and are NOT used here.
    * The macro adds the GREATEST(0, ...) floor, so policies incepting after
      the as-at date earn 0 instead of a negative amount as the raw BTEQ
      arithmetic allowed.
    * POLICY_STATUS filter keeps the legacy UW definition of "active"
      (IF, RN) — deliberately different from the Finance definition used by
      stg_policy_360.active_policy_flag; both remain observable side by side.

  CURRENT_DATE is replaced by the `bteq_policy_as_at_dt` var (shared with
  stg_policy_360) so the figures are reproducible against the frozen baseline.
-#}

{%- set as_at = "cast('" ~ var('bteq_policy_as_at_dt', '2026-12-31') ~ "' as date)" -%}

select
    p.policy_no,
    p.uw_year,
    p.product_cd,
    p.annual_premium_gbp as gwp,
    p.annual_premium_gbp * p.ipt_rate as ipt_amt,
    {{ earned_premium(
        'cast(p.annual_premium_gbp as decimal(12, 2))', 'p.inception_dt', as_at
    ) }} as earned_premium,
    {{ unearned_premium(
        'cast(p.annual_premium_gbp as decimal(12, 2))', 'p.inception_dt', as_at
    ) }} as unearned_premium,
    t.treaty_id,
    t.cession_pct,
    cast(
        p.annual_premium_gbp * coalesce(t.cession_pct, 0) / 100.0 as decimal(12, 2)
    ) as ceded_premium,
    {{ as_at }} as as_at_dt
from {{ ref('raw_policies') }} as p
left join {{ ref('raw_reinsurance_treaties') }} as t
    on
        p.product_cd = t.line_of_business
        and p.uw_year = t.uw_year
        and t.treaty_type = 'QUOTA_SHARE'
where p.policy_status in ('IF', 'RN')   -- UW definition of active
