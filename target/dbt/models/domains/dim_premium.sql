-- Domain: canonical PREMIUM transaction dimension (BILLING_DB.PREMIUM_TRANSACTIONS).
-- IPT is recomputed from POLICY.IPT_RATE, NOT the hardcoded 0.12 in Informatica
-- wf_BILLING_PREMIUM_RECON EXP_IPT_RECALC (which breaks whenever IPT changes).
with prem as (
    select * from {{ ref('stg_premium_transactions') }}
),

policy as (
    select policy_no, party_id, product_cd, uw_year, ipt_rate
    from {{ ref('stg_policy') }}
)

select
    pr.premium_txn_id,
    pr.policy_no,
    p.party_id                                        as polaris_party_id,
    md5(p.party_id)                                   as party_key,
    p.product_cd,
    p.uw_year,
    pr.txn_type,
    pr.txn_dt,
    pr.gross_amt_gbp,
    pr.ipt_amt_gbp                                    as ipt_amt_gbp_source,
    round(pr.gross_amt_gbp * coalesce(p.ipt_rate, 0), 2) as ipt_amt_gbp,
    pr.commission_amt_gbp,
    pr.collection_method,
    pr.apf_account_id
from prem pr
left join policy p on p.policy_no = pr.policy_no
