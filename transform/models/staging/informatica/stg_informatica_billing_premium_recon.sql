-- Port of informatica/XML/wf_BILLING_PREMIUM_RECON.xml (mapping
-- m_BILLING_PREMIUM_RECON). One CTE per PowerCenter transformation instance:
--   AGG (source qualifier + aggregator)  written / collected premium per policy
--   LKP_APF_ACCOUNTS                     APF_ACCOUNT_ID -> CORE_BANKING ACCOUNTS
--   EXP_IPT_RECALC                       IPT at the hardcoded legacy 12% rate
--   EXP_EARNED_24THS                     earned premium on 1/24ths
--
-- Earned premium comes from the shared earned_premium macro. The legacy figure
-- is reproduced with method='twenty_fourths' (LABELLED as the non-canonical
-- legacy DWH-recon method) and the canonical 1/12ths figure is emitted
-- alongside it, so the 1/24ths drift is a measured column rather than a hidden
-- reconciliation difference.
--
-- SYSDATE in the legacy expression is replaced by a deterministic as-at date so
-- the model is reproducible; override with
--   --vars '{informatica_recon_as_at_dt: 2026-03-31}'
{% set as_at = "cast('" ~ var('informatica_recon_as_at_dt', '2026-06-30') ~ "' as date)" %}

with premium_txn as (
    select
        policy_no,
        txn_type,
        gross_amt_gbp,
        ipt_amt_gbp,
        commission_amt_gbp,
        apf_account_id
    from {{ ref('raw_premium_transactions') }}
    where txn_dt <= {{ as_at }}
),

lkp_apf_accounts as (
    select distinct account_id
    from {{ ref('raw_accounts') }}
),

agg_policy_premium as (
    select
        t.policy_no,
        count(*) as premium_txn_cnt,
        cast(sum(t.gross_amt_gbp) as decimal(14, 2)) as written_premium_gbp,
        cast(sum(t.ipt_amt_gbp) as decimal(14, 2)) as ipt_actual_gbp,
        cast(sum(t.commission_amt_gbp) as decimal(14, 2)) as commission_gbp,
        cast(
            sum(case when t.txn_type = 'CN_REFUND' then -t.gross_amt_gbp else t.gross_amt_gbp end)
            as decimal(14, 2)
        ) as net_written_premium_gbp,
        cast(
            sum(case when a.account_id is not null then t.gross_amt_gbp else 0 end) as decimal(14, 2)
        ) as apf_collected_premium_gbp,
        sum(case when t.apf_account_id is not null and a.account_id is null then 1 else 0 end)
            as apf_orphan_txn_cnt
    from premium_txn as t
    left join lkp_apf_accounts as a
        on t.apf_account_id = a.account_id
    group by t.policy_no
),

policy as (
    select
        policy_no,
        product_cd,
        inception_dt,
        policy_status,
        ipt_rate,
        cast(annual_premium_gbp as decimal(12, 2)) as annual_premium_gbp
    from {{ ref('raw_policies') }}
),

recon as (
    select
        p.policy_no,
        p.product_cd,
        p.policy_status,
        p.inception_dt,
        p.annual_premium_gbp,
        {{ as_at }} as as_at_dt,
        coalesce(a.premium_txn_cnt, 0) as premium_txn_cnt,
        coalesce(a.written_premium_gbp, 0) as written_premium_gbp,
        coalesce(a.net_written_premium_gbp, 0) as net_written_premium_gbp,
        coalesce(a.apf_collected_premium_gbp, 0) as apf_collected_premium_gbp,
        coalesce(a.ipt_actual_gbp, 0) as ipt_actual_gbp,
        coalesce(a.commission_gbp, 0) as commission_gbp,
        coalesce(a.apf_orphan_txn_cnt, 0) as apf_orphan_txn_cnt,
        -- EXP_IPT_RECALC: legacy hardcoded 12%
        cast(round(coalesce(a.written_premium_gbp, 0) * 0.12, 2) as decimal(14, 2))
            as ipt_expected_legacy_gbp,
        -- converged alternative using POLICY.IPT_RATE (unused by the legacy mapping)
        cast(round(coalesce(a.written_premium_gbp, 0) * p.ipt_rate, 2) as decimal(14, 2))
            as ipt_expected_policy_rate_gbp,
        -- EXP_EARNED_24THS: legacy DWH-recon method (NON-CANONICAL, labelled)
        {{ earned_premium('p.annual_premium_gbp', 'p.inception_dt', as_at, 'twenty_fourths') | trim }}
            as earned_premium_24ths_legacy_gbp,
        -- canonical group method (straight-line 1/12ths)
        {{ earned_premium('p.annual_premium_gbp', 'p.inception_dt', as_at) | trim }}
            as earned_premium_canonical_gbp,
        {{ unearned_premium('p.annual_premium_gbp', 'p.inception_dt', as_at) | trim }}
            as unearned_premium_canonical_gbp
    from policy as p
    left join agg_policy_premium as a
        on p.policy_no = a.policy_no
)

select
    r.*,
    cast(
        r.earned_premium_24ths_legacy_gbp - r.earned_premium_canonical_gbp as decimal(14, 2)
    ) as earned_premium_method_drift_gbp,
    cast(r.written_premium_gbp - r.apf_collected_premium_gbp as decimal(14, 2))
        as uncollected_premium_gbp,
    cast(r.ipt_actual_gbp - r.ipt_expected_legacy_gbp as decimal(14, 2)) as ipt_variance_legacy_gbp,
    case when r.apf_orphan_txn_cnt > 0 then 'Y' else 'N' end as apf_match_exception_flag,
    'EARNED_24THS_LEGACY_DWH_RECON' as earned_premium_method_label,
    current_timestamp as load_ts
from recon as r
